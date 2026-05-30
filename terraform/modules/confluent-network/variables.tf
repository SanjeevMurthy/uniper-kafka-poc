variable "environment_name" {
  type        = string
  description = "Display name of the Confluent Environment (e.g. \"uniper-poc\")."

  validation {
    condition     = length(var.environment_name) > 0 && length(var.environment_name) <= 60
    error_message = "environment_name must be 1-60 characters."
  }
}

variable "confluent_region" {
  type        = string
  description = "Confluent Cloud region. MUST match the Azure region used for the VNet and Private Endpoint (Private Link is region-local)."

  validation {
    condition     = length(var.confluent_region) > 0
    error_message = "confluent_region must not be empty."
  }
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID to register for Private Link Access. Private Endpoints created in this subscription will auto-approve against this Confluent network."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.azure_subscription_id))
    error_message = "azure_subscription_id must be a valid GUID."
  }
}

variable "stream_governance_package" {
  type        = string
  default     = "ESSENTIALS"
  description = "Stream Governance package on the environment. ESSENTIALS is sufficient for the POC."

  validation {
    condition     = contains(["ESSENTIALS", "ADVANCED"], var.stream_governance_package)
    error_message = "stream_governance_package must be ESSENTIALS or ADVANCED."
  }
}

variable "zones" {
  type        = list(string)
  default     = []
  description = "Optional explicit list of Availability Zones for the Confluent network. Leave empty to let Confluent pick. Use the region-specific AZ names (e.g. [\"1\",\"2\",\"3\"] for Azure)."
}
