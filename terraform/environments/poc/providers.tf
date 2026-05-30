terraform {
  required_version = ">= 1.6.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.11"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# AzureRM — authenticates via OIDC in CI (ARM_USE_OIDC=true + ARM_CLIENT_ID
# etc.); via `az login` locally.
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  subscription_id = var.azure_subscription_id
}

# Confluent — authenticates via the Cloud-resource-management API key.
# Confluent does not yet support OIDC for the Terraform provider; the key
# is stored as a GitHub Environment secret (`poc` / `bootstrap`).
provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

provider "random" {}
