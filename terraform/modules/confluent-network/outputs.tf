output "environment_id" {
  value       = confluent_environment.main.id
  description = "Confluent Environment ID. Pass to confluent-cluster module."
}

output "network_id" {
  value       = confluent_network.private_link.id
  description = "Confluent Network ID. Pass to confluent-cluster module."
}

output "dns_domain" {
  value       = confluent_network.private_link.dns_domain
  description = "DNS domain Confluent assigned to this network (e.g. \"abc123.westeurope.azure.privatelink.confluent.cloud\"). Used as the Private DNS Zone name in Azure."
}

output "private_link_service_aliases" {
  value       = confluent_network.private_link.azure[0].private_link_service_aliases
  description = "Map of availability zone → Private Link service alias. Consumed by the azure-network module to create one Private Endpoint per zone."
}

output "zonal_subdomains" {
  value       = keys(confluent_network.private_link.azure[0].private_link_service_aliases)
  description = "List of zone subdomain identifiers (the keys of private_link_service_aliases). Useful for predictable iteration order."
}
