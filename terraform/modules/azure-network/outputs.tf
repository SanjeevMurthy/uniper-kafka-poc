output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Name of the resource group. Consumed by azure-aks."
}

output "resource_group_location" {
  value       = azurerm_resource_group.main.location
  description = "Region of the resource group. Consumed by azure-aks."
}

output "vnet_id" {
  value       = azurerm_virtual_network.main.id
  description = "VNet resource ID."
}

output "vnet_name" {
  value       = azurerm_virtual_network.main.name
  description = "VNet name (convenience for diagnostics)."
}

output "aks_subnet_id" {
  value       = azurerm_subnet.aks.id
  description = "Subnet ID for AKS nodes. Consumed by azure-aks."
}

output "pe_subnet_id" {
  value       = azurerm_subnet.private_endpoints.id
  description = "Subnet ID hosting the Private Endpoints (for future PEs to other PaaS services)."
}

output "private_dns_zone_name" {
  value       = azurerm_private_dns_zone.confluent.name
  description = "Name of the Private DNS Zone (== Confluent DNS domain)."
}

output "private_endpoint_ips" {
  value       = { for k, pe in azurerm_private_endpoint.confluent : k => pe.private_service_connection[0].private_ip_address }
  description = "Map of zone subdomain → PE private IP. Useful for nslookup-style verification."
}
