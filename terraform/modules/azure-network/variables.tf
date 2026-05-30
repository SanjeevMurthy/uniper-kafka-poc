variable "project_name" {
  type        = string
  description = "Naming prefix for all resources in this module."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.project_name))
    error_message = "project_name must be 3-40 lowercase chars, digits, or hyphens."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Azure resource group to create."
}

variable "azure_region" {
  type        = string
  description = "Azure region. MUST match the Confluent network region."
}

variable "vnet_address_space" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR for the VNet."

  validation {
    condition     = can(cidrnetmask(var.vnet_address_space))
    error_message = "vnet_address_space must be a valid CIDR."
  }
}

variable "aks_subnet_prefix" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR for the AKS node subnet. Must be inside vnet_address_space."

  validation {
    condition     = can(cidrnetmask(var.aks_subnet_prefix))
    error_message = "aks_subnet_prefix must be a valid CIDR."
  }
}

variable "pe_subnet_prefix" {
  type        = string
  default     = "10.0.2.0/24"
  description = "CIDR for the Private Endpoint subnet. Must be inside vnet_address_space."

  validation {
    condition     = can(cidrnetmask(var.pe_subnet_prefix))
    error_message = "pe_subnet_prefix must be a valid CIDR."
  }
}

variable "private_link_service_aliases" {
  type        = map(string)
  description = "Map of AZ subdomain key → Confluent Private Link service alias. Sourced from the confluent-network module output."
}

variable "confluent_dns_domain" {
  type        = string
  description = "Confluent-assigned DNS domain for the network (becomes the Private DNS Zone name). Sourced from the confluent-network module."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to every Azure resource in this module."
}
