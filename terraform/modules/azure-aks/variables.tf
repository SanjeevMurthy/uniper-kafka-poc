variable "cluster_name" {
  type        = string
  description = "AKS cluster name."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{1,63}$", var.cluster_name))
    error_message = "cluster_name must be 1-63 alphanumeric or hyphen characters."
  }
}

variable "location" {
  type        = string
  description = "Azure region. Must match the VNet region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group hosting the AKS cluster."
}

variable "dns_prefix" {
  type        = string
  description = "DNS prefix for the AKS API server FQDN."
}

variable "kubernetes_version" {
  type        = string
  default     = null
  description = "Kubernetes version. Null = AKS default (recommended for POC)."
}

variable "node_count" {
  type        = number
  default     = 1
  description = "Initial node count in the system pool. Ignored on subsequent applies so autoscaler can mutate freely."

  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be >= 1."
  }
}

variable "vm_size" {
  type        = string
  default     = "Standard_DS2_v2"
  description = "VM size for the system node pool. Smallest viable for POC."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for AKS nodes (from azure-network.aks_subnet_id)."
}

variable "service_cidr" {
  type        = string
  default     = "10.1.0.0/16"
  description = "Service CIDR for Kubernetes services. MUST NOT overlap with vnet_address_space."

  validation {
    condition     = can(cidrnetmask(var.service_cidr))
    error_message = "service_cidr must be a valid CIDR."
  }
}

variable "dns_service_ip" {
  type        = string
  default     = "10.1.0.10"
  description = "DNS service IP. Must be within service_cidr."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the AKS resource."
}
