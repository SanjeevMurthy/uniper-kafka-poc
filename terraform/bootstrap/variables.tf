variable "github_org" {
  type        = string
  description = "GitHub organisation (or username) that owns the repo. Used in OIDC subject claims."

  validation {
    condition     = length(var.github_org) > 0
    error_message = "github_org must not be empty."
  }
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (without the org). Used in OIDC subject claims."

  validation {
    condition     = length(var.github_repo) > 0
    error_message = "github_repo must not be empty."
  }
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID. RBAC for the OIDC SP is scoped to this subscription."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.azure_subscription_id))
    error_message = "azure_subscription_id must be a valid GUID."
  }
}

variable "azure_region" {
  type        = string
  description = "Azure region where the state RG + SA are created."
}

variable "project_name" {
  type        = string
  default     = "uniper-poc"
  description = "Naming prefix. Used in the AD app name, state SA name, and POC RG name."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.project_name))
    error_message = "project_name must be 3-40 lowercase letters, digits, or hyphens."
  }
}

variable "state_resource_group_name" {
  type        = string
  default     = "tfstate-rg"
  description = "Resource group that holds the Terraform state storage account."
}

variable "state_container_name" {
  type        = string
  default     = "tfstate"
  description = "Blob container holding all state files (one blob per stack)."
}

variable "poc_resource_group_name" {
  type        = string
  default     = "uniper-poc-rg"
  description = "Name of the POC resource group. Used to pre-create a scoped role assignment so the POC stack can manage role assignments inside its RG."
}

variable "tags" {
  type = map(string)
  default = {
    project    = "uniper-poc"
    purpose    = "tfstate-and-oidc"
    managed_by = "terraform"
  }
  description = "Tags applied to all Azure resources created by the bootstrap stack."
}
