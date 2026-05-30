output "cluster_name" {
  value       = azurerm_kubernetes_cluster.main.name
  description = "AKS cluster name (use with `az aks get-credentials`)."
}

output "cluster_id" {
  value       = azurerm_kubernetes_cluster.main.id
  description = "AKS resource ID (for diagnostic settings, RBAC, etc.)."
}

output "kubelet_identity_object_id" {
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  description = "Object ID of the auto-created kubelet identity. Useful for granting ACR pull, Key Vault access, etc."
}

output "kube_config" {
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  description = "Raw kubeconfig. Prefer `az aks get-credentials` in CI; this output exists for break-glass scenarios."
  sensitive   = true
}

output "host" {
  value       = azurerm_kubernetes_cluster.main.kube_config[0].host
  description = "API server host (useful for provider \"kubernetes\" / \"helm\" wiring)."
  sensitive   = true
}
