terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# AzureRM — first apply uses a human's `az login`; subsequent applies use
# OIDC from GitHub Actions (ARM_USE_OIDC=true + ARM_CLIENT_ID etc.).
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  subscription_id = var.azure_subscription_id
}

provider "azuread" {
  # Inherits tenant from the same login as azurerm.
}

provider "random" {}
