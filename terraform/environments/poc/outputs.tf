# =============================================================================
# Confluent outputs
# =============================================================================

output "confluent_environment_id" {
  value       = module.confluent_network.environment_id
  description = "Confluent Environment ID."
}

output "confluent_network_id" {
  value       = module.confluent_network.network_id
  description = "Confluent Network ID."
}

output "confluent_dns_domain" {
  value       = module.confluent_network.dns_domain
  description = "Private DNS domain assigned by Confluent."
}

output "kafka_cluster_id" {
  value       = module.confluent_cluster.cluster_id
  description = "Confluent Kafka cluster ID (lkc-xxxxxx)."
}

output "kafka_bootstrap_endpoint" {
  value       = module.confluent_cluster.bootstrap_endpoint
  description = "Kafka bootstrap endpoint. Use with SASL_SSL + PLAIN."
}

output "kafka_rest_endpoint" {
  value       = module.confluent_cluster.rest_endpoint
  description = "Kafka REST endpoint."
}

output "topic_names" {
  value       = module.confluent_cluster.topic_names
  description = "Topics created in the cluster."
}

output "app_service_account_id" {
  value       = module.confluent_cluster.app_service_account_id
  description = "Application service account ID (User:<id> in ACLs)."
}

output "app_api_key_id" {
  value       = module.confluent_cluster.app_api_key_id
  description = "Application API key ID (SASL username)."
  sensitive   = true
}

output "app_api_key_secret" {
  value       = module.confluent_cluster.app_api_key_secret
  description = "Application API key secret (SASL password)."
  sensitive   = true
}

# =============================================================================
# Azure outputs
# =============================================================================

output "resource_group_name" {
  value       = module.azure_network.resource_group_name
  description = "Azure resource group hosting POC resources."
}

output "vnet_id" {
  value       = module.azure_network.vnet_id
  description = "VNet resource ID."
}

output "aks_subnet_id" {
  value       = module.azure_network.aks_subnet_id
  description = "AKS subnet ID."
}

output "private_endpoint_ips" {
  value       = module.azure_network.private_endpoint_ips
  description = "Map of zone subdomain → Private Endpoint private IP."
}

output "aks_cluster_name" {
  value       = module.azure_aks.cluster_name
  description = "AKS cluster name. Use with `az aks get-credentials`."
}

output "aks_cluster_id" {
  value       = module.azure_aks.cluster_id
  description = "AKS resource ID."
}
