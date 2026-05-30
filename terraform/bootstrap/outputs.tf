output "github_actions_client_id" {
  value       = azuread_application.gh.client_id
  description = "Client ID of the AD app used by GitHub Actions for OIDC. Set as the AZURE_CLIENT_ID repo variable."
}

output "github_actions_sp_object_id" {
  value       = azuread_service_principal.gh.object_id
  description = "Object ID of the service principal. Useful for ad-hoc role assignments later."
}

output "azure_tenant_id" {
  value       = data.azurerm_client_config.current.tenant_id
  description = "Tenant ID. Set as the AZURE_TENANT_ID repo variable."
}

output "azure_subscription_id" {
  value       = data.azurerm_subscription.current.subscription_id
  description = "Subscription ID. Set as the AZURE_SUBSCRIPTION_ID repo variable."
}

output "state_resource_group_name" {
  value       = azurerm_resource_group.state.name
  description = "Resource group holding the state SA. Set as the TF_STATE_RG repo variable."
}

output "state_storage_account_name" {
  value       = azurerm_storage_account.state.name
  description = "Storage account holding state. Set as the TF_STATE_SA repo variable."
}

output "state_container_name" {
  value       = azurerm_storage_container.state.name
  description = "Blob container holding state files. Set as the TF_STATE_CONTAINER repo variable."
}

output "federated_credentials" {
  value       = { for k, c in azuread_application_federated_identity_credential.gh : k => c.subject }
  description = "Map of federated credential name → subject. Useful to verify the OIDC subject claim configuration."
}
