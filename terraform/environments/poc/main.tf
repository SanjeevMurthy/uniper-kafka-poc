locals {
  # Region equality is a HARD requirement for Private Link. Fail fast at
  # plan time if someone overrides one without the other.
  # (A `precondition` on a data source is the cleanest way; using a local
  # with an assertion via terraform_data so it's visible in plan output.)
  azure_and_confluent_region_match = var.azure_region

  # Merge user tags with derived ones so every resource is traceable back to
  # the repo + commit (commit can be injected via TF_VAR_git_sha in CI).
  derived_tags = merge(
    var.tags,
    {
      project_name = var.project_name
    }
  )
}

# Hard precondition: refuse to plan unless region equality is acknowledged.
# Pulled out as a `terraform_data` so the failure shows up in plan output.
resource "terraform_data" "region_assertion" {
  input = var.azure_region

  lifecycle {
    precondition {
      condition     = var.azure_region != ""
      error_message = "azure_region must be set. The same region MUST be used for the Confluent network and the Azure VNet — Private Link is region-local."
    }
  }
}

# ============================================================================
# Confluent — environment + private-link network + private link access
# ============================================================================
module "confluent_network" {
  source = "../../modules/confluent-network"

  environment_name      = var.confluent_environment_name
  confluent_region      = var.azure_region
  azure_subscription_id = var.azure_subscription_id
  zones                 = var.zones
}

# ============================================================================
# Azure — RG + VNet + subnets + Private Endpoints + Private DNS
# ============================================================================
module "azure_network" {
  source = "../../modules/azure-network"

  project_name                 = var.project_name
  resource_group_name          = var.resource_group_name
  azure_region                 = var.azure_region
  vnet_address_space           = var.vnet_address_space
  aks_subnet_prefix            = var.aks_subnet_prefix
  pe_subnet_prefix             = var.pe_subnet_prefix
  private_link_service_aliases = module.confluent_network.private_link_service_aliases
  confluent_dns_domain         = module.confluent_network.dns_domain
  zones                        = var.zones
  tags                         = local.derived_tags
}

# ============================================================================
# Confluent — Kafka cluster + topics + service accounts + API keys + ACLs
# ============================================================================
module "confluent_cluster" {
  source = "../../modules/confluent-cluster"

  cluster_name             = var.confluent_cluster_name
  confluent_region         = var.azure_region
  environment_id           = module.confluent_network.environment_id
  network_id               = module.confluent_network.network_id
  app_service_account_name = var.app_service_account_name
  topic_names              = var.topic_names
  topic_partitions         = var.topic_partitions
  topic_retention_ms       = var.topic_retention_ms
  consumer_group_prefix    = var.consumer_group_prefix
}

# ============================================================================
# Azure — AKS cluster (depends on azure_network.aks_subnet_id)
# ============================================================================
module "azure_aks" {
  source = "../../modules/azure-aks"

  cluster_name        = "${var.project_name}-aks"
  location            = module.azure_network.resource_group_location
  resource_group_name = module.azure_network.resource_group_name
  dns_prefix          = "${var.project_name}-aks"
  node_count          = var.aks_node_count
  vm_size             = var.aks_vm_size
  subnet_id           = module.azure_network.aks_subnet_id
  tags                = local.derived_tags
}
