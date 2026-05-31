terraform {
  required_version = ">= 1.6.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.11"
    }
  }
}

# ---------------------------------------------------------------------------
# Confluent Environment
#
# Logical container for everything else (network, cluster, topics, SAs).
# Stream Governance is set to ESSENTIALS (lowest tier — POC scope).
# ---------------------------------------------------------------------------
resource "confluent_environment" "main" {
  display_name = var.environment_name

  stream_governance {
    package = var.stream_governance_package
  }
}

# ---------------------------------------------------------------------------
# Confluent Network — Private Link
#
# Provisioning takes 5-15 minutes. Once created, this resource is rarely
# touched — Kafka clusters are added/removed within it but the network
# itself is durable.
#
# `dns_config { resolution = "PRIVATE" }` is required so the cluster's
# bootstrap endpoint resolves to private IPs from within the linked VNet.
# ---------------------------------------------------------------------------
resource "confluent_network" "private_link" {
  display_name     = "${var.environment_name}-network"
  cloud            = "AZURE"
  region           = var.confluent_region
  connection_types = ["PRIVATELINK"]
  zones            = length(var.zones) > 0 ? var.zones : null

  environment {
    id = confluent_environment.main.id
  }

  dns_config {
    resolution = "PRIVATE"
  }
}

# ---------------------------------------------------------------------------
# Private Link Access — registers the Azure subscription as an allowed
# consumer. Without this, Private Endpoints created in the Azure subscription
# will sit in "Pending" approval forever.
# ---------------------------------------------------------------------------
resource "confluent_private_link_access" "azure" {
  display_name = "${var.environment_name}-pl-access"

  azure {
    subscription = var.azure_subscription_id
  }

  environment {
    id = confluent_environment.main.id
  }

  network {
    id = confluent_network.private_link.id
  }
}
