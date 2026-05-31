data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

locals {
  # Storage account names: 3-24 lowercase alphanumeric chars, globally unique.
  # "tfstate" + project (stripped of hyphens) + 6-char random suffix.
  project_stripped     = replace(var.project_name, "-", "")
  state_sa_name_prefix = substr("tfstate${local.project_stripped}", 0, 18)

  github_subject_prefix = "repo:${var.github_org}/${var.github_repo}"

  # Two OIDC subjects, one per workflow class. All workflows in this repo are
  # manually triggered (workflow_dispatch) and gated by a GitHub Environment.
  federated_credentials = {
    bootstrap = {
      subject     = "${local.github_subject_prefix}:environment:bootstrap"
      description = "GitHub Actions OIDC for the bootstrap workflow"
    }
    poc = {
      subject     = "${local.github_subject_prefix}:environment:poc"
      description = "GitHub Actions OIDC for the poc environment (plan/apply/destroy/drift)"
    }
  }

  ad_app_display_name = "gh-actions-${var.project_name}"
}

# ============================================================================
# State backend — RG + Storage Account + Container
# ============================================================================

resource "azurerm_resource_group" "state" {
  name     = var.state_resource_group_name
  location = var.azure_region
  tags     = var.tags
}

resource "random_string" "sa_suffix" {
  length  = 6
  upper   = false
  numeric = true
  lower   = true
  special = false
}

resource "azurerm_storage_account" "state" {
  name                            = "${local.state_sa_name_prefix}${random_string.sa_suffix.result}"
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false # AAD only — no SAS / account keys
  public_network_access_enabled   = true  # POC: permit GH-hosted runners; AAD auth is the real control
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "state" {
  name                  = var.state_container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# ============================================================================
# OIDC — Azure AD application + federated credentials
# ============================================================================

resource "azuread_application" "gh" {
  display_name = local.ad_app_display_name
  description  = "GitHub Actions OIDC identity for ${var.github_org}/${var.github_repo}. No client secret."

  # Tracking tag — useful when listing apps in the tenant.
  tags = ["github-actions", "terraform-managed", var.project_name]
}

resource "azuread_service_principal" "gh" {
  client_id                    = azuread_application.gh.client_id
  app_role_assignment_required = false
  description                  = "Service principal for the GitHub Actions OIDC identity."
}

resource "azuread_application_federated_identity_credential" "gh" {
  for_each = local.federated_credentials

  application_id = azuread_application.gh.id
  display_name   = "gh-${each.key}"
  description    = each.value.description
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = each.value.subject
}

# ============================================================================
# RBAC — grant the service principal the rights it needs
# ============================================================================

# Subscription-scoped Contributor — for creating RGs, VNets, AKS, PEs, etc.
# Scoped to the subscription level because the POC RG name is configurable
# and we don't yet know which RG might be created in the future.
resource "azurerm_role_assignment" "sp_subscription_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.gh.object_id
  description          = "Lets GitHub Actions create POC resources via Terraform."
}

# State SA-scoped — read/write/lock state blobs over AAD auth.
resource "azurerm_role_assignment" "sp_state_blob_owner" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azuread_service_principal.gh.object_id
  description          = "Lets GitHub Actions read/write Terraform state blobs."
}

# POC-RG scoped User Access Administrator — required because the POC stack
# (specifically AKS with managed identity wiring) creates role assignments
# within its own RG.
#
# TODO: Uncomment after the POC resource group ('uniper-poc-rg') has been
# created by the POC Terraform stack. Azure does NOT allow role assignments
# on non-existent resource group scopes (returns 404).
#
# resource "azurerm_role_assignment" "sp_poc_rg_uaa" {
#   scope                = "${data.azurerm_subscription.current.id}/resourceGroups/${var.poc_resource_group_name}"
#   role_definition_name = "User Access Administrator"
#   principal_id         = azuread_service_principal.gh.object_id
#   description          = "Lets the POC stack create role assignments inside its own resource group (e.g. AKS kubelet identity to ACR pull)."
# }

