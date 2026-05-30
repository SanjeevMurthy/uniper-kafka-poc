variable "cluster_name" {
  type        = string
  description = "Display name of the Kafka cluster."

  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 60
    error_message = "cluster_name must be 1-60 characters."
  }
}

variable "confluent_region" {
  type        = string
  description = "Confluent region. MUST equal the Azure region."
}

variable "environment_id" {
  type        = string
  description = "Confluent Environment ID (from confluent-network module)."
}

variable "network_id" {
  type        = string
  description = "Confluent Network ID (from confluent-network module). Cluster is attached to this network."
}

variable "availability" {
  type        = string
  default     = "SINGLE_ZONE"
  description = "Cluster availability. SINGLE_ZONE (POC) or MULTI_ZONE (prod). Cannot be changed after creation."

  validation {
    condition     = contains(["SINGLE_ZONE", "MULTI_ZONE"], var.availability)
    error_message = "availability must be SINGLE_ZONE or MULTI_ZONE."
  }
}

variable "cku" {
  type        = number
  default     = 1
  description = "Confluent Kafka Units. 1 is the minimum for Dedicated. Can be increased; cannot be decreased."

  validation {
    condition     = var.cku >= 1
    error_message = "cku must be >= 1."
  }
}

variable "app_service_account_name" {
  type        = string
  default     = "poc-app-sa"
  description = "Display name for the application service account."
}

variable "topic_names" {
  type        = list(string)
  default     = ["orders", "payments"]
  description = "Topics to create. Each gets the same partition / retention config."

  validation {
    condition     = length(var.topic_names) > 0
    error_message = "topic_names must contain at least one topic."
  }
}

variable "topic_partitions" {
  type        = number
  default     = 6
  description = "Partitions per topic. Can be INCREASED only; reducing forces topic replacement (data loss)."

  validation {
    condition     = var.topic_partitions >= 1 && var.topic_partitions <= 1000
    error_message = "topic_partitions must be between 1 and 1000."
  }
}

variable "topic_retention_ms" {
  type        = number
  default     = 604800000 # 7 days
  description = "Retention period per topic in milliseconds. Default 7 days."
}

variable "consumer_group_prefix" {
  type        = string
  default     = "poc-"
  description = "Prefix matched by the GROUP READ ACL. Consumers using groups outside this prefix will be denied."
}
