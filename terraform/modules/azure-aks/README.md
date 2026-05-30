# Module: `azure-aks`

Provisions a small AKS cluster that lives inside the VNet's AKS subnet so
pods can reach the Confluent Cloud cluster via the Private Endpoint.

## Resources

- `azurerm_kubernetes_cluster.main` — system-assigned identity, azure CNI,
  one system node pool

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `cluster_name` | string | — | AKS name |
| `location` | string | — | Must match VNet region |
| `resource_group_name` | string | — | From `azure-network` |
| `dns_prefix` | string | — | DNS prefix for API server FQDN |
| `kubernetes_version` | string | `null` (AKS default) | K8s version |
| `node_count` | number | `1` | Initial; ignored on update |
| `vm_size` | string | `"Standard_DS2_v2"` | Node SKU |
| `subnet_id` | string | — | From `azure-network.aks_subnet_id` |
| `service_cidr` | string | `"10.1.0.0/16"` | Must NOT overlap VNet |
| `dns_service_ip` | string | `"10.1.0.10"` | Inside `service_cidr` |
| `tags` | map(string) | `{}` | |

## Outputs

| Name | Sensitive | Description |
|------|-----------|-------------|
| `cluster_name` | no | For `az aks get-credentials` |
| `cluster_id` | no | For RBAC / diagnostics |
| `kubelet_identity_object_id` | no | For granting ACR pull / Key Vault access |
| `kube_config` | **yes** | Raw kubeconfig (break-glass) |
| `host` | **yes** | API server URL |

## Example

```hcl
module "azure_aks" {
  source = "../../modules/azure-aks"

  cluster_name        = "uniper-poc-aks"
  location            = module.azure_network.resource_group_location
  resource_group_name = module.azure_network.resource_group_name
  dns_prefix          = "uniper-poc-aks"
  subnet_id           = module.azure_network.aks_subnet_id
  tags                = { project = "uniper-poc", environment = "poc" }
}
```

## Gotchas

- **`service_cidr` must not overlap with `vnet_address_space`.** Default
  (`10.1.0.0/16`) is outside the suggested VNet CIDR (`10.0.0.0/16`).
- **`node_count` is in `ignore_changes`** so a future cluster autoscaler can
  mutate the count without forcing Terraform drift. If you need to change
  the initial count, taint the resource or use a workspace var override.
- **`kubernetes_version = null`** asks AKS to pick the default. Pin
  explicitly (e.g. `"1.29"`) once you have a tested version.
- **The kubelet identity** is auto-created by AKS and is the principal to
  grant when wiring up ACR pull, Key Vault, etc. — not the cluster's main
  identity.
