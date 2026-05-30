terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# ---------------------------------------------------------------------------
# AKS cluster — minimal POC sizing.
#
# - One small system node pool. Add user node pools later if workloads grow.
# - SystemAssigned identity (no need to pre-create a UAMI for the POC).
# - Azure CNI so pod IPs come from the AKS subnet (resolvers, NSGs all work
#   without extra translation).
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  default_node_pool {
    name           = "system"
    node_count     = var.node_count
    vm_size        = var.vm_size
    vnet_subnet_id = var.subnet_id

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  # AKS adds Azure-side default node labels/annotations on every reconcile.
  # Ignoring node_count changes lets the cluster autoscaler (if added later)
  # adjust without forcing Terraform diffs.
  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
    ]
  }
}
