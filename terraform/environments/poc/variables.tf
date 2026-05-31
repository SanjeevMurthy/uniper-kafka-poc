# =============================================================================
# Confluent Cloud
# =============================================================================

variable "confluent_cloud_api_key" {
  type        = string
  sensitive   = true
  description = "Confluent Cloud Cloud-resource-management API key (org-scoped). Sourced from TF_VAR_confluent_cloud_api_key in CI."
}

variable "confluent_cloud_api_secret" {
  type        = string
  sensitive   = true
  description = "Confluent Cloud API secret. Sourced from TF_VAR_confluent_cloud_api_secret in CI."
}

variable "confluent_environment_name" {
  type        = string
  default     = "uniper-kafka-poc"
  description = "Display name of the Confluent Environment."
}

variable "confluent_cluster_name" {
  type        = string
  default     = "uniper-kafka-poc-kafka"
  description = "Display name of the Confluent Kafka cluster."
}

variable "topic_names" {
  type        = list(string)
  default     = ["orders", "payments"]
  description = "Topics to create in the cluster."
}

variable "topic_partitions" {
  type        = number
  default     = 6
  description = "Partitions per topic."
}

variable "topic_retention_ms" {
  type        = number
  default     = 604800000 # 7 days
  description = "Retention period per topic in milliseconds."
}

variable "app_service_account_name" {
  type        = string
  default     = "poc-app-sa"
  description = "Display name of the application service account."
}

variable "consumer_group_prefix" {
  type        = string
  default     = "poc-"
  description = "Prefix matched by the GROUP READ ACL."
}

# =============================================================================
# Azure
# =============================================================================

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.azure_subscription_id))
    error_message = "azure_subscription_id must be a valid GUID."
  }
}

variable "azure_region" {
  type        = string
  default     = "westeurope"
  description = "Azure region. MUST equal the Confluent region (Private Link is region-local)."
}

variable "resource_group_name" {
  type        = string
  default     = "uniper-kafka-poc-rg"
  description = "Resource group for all POC Azure resources. Distinct from the tfstate RG so destroy is safe."
}

variable "vnet_address_space" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VNet CIDR."
}

variable "aks_subnet_prefix" {
  type        = string
  default     = "10.0.1.0/24"
  description = "AKS subnet CIDR."
}

variable "pe_subnet_prefix" {
  type        = string
  default     = "10.0.2.0/24"
  description = "Private Endpoint subnet CIDR."
}

variable "aks_node_count" {
  type        = number
  default     = 1
  description = "Initial AKS node count."
}

variable "aks_vm_size" {
  type        = string
  default     = "standard_dc2as_v5"
  description = "VM size for AKS nodes."
}

# =============================================================================
# Cross-cutting
# =============================================================================

variable "project_name" {
  type        = string
  default     = "uniper-kafka-poc"
  description = "Naming prefix shared across resources."
}

variable "tags" {
  type = map(string)
  default = {
    project     = "uniper-kafka-poc"
    environment = "poc"
    managed_by  = "terraform"
  }
  description = "Tags applied to every Azure resource."
}

variable "zones" {
  type        = list(string)
  default     = ["1", "2", "3"]
  description = "Availability zones for Confluent Private Link endpoints."
}

