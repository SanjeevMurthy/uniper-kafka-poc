# Module: `azure-network`

Provisions the Azure networking layer for the POC: resource group, VNet, two
subnets (AKS + Private Endpoints), Private Endpoints to Confluent, and the
Private DNS Zone wired up to the VNet.

## Resources

- `azurerm_resource_group.main`
- `azurerm_virtual_network.main`
- `azurerm_subnet.aks` (for AKS nodes)
- `azurerm_subnet.private_endpoints` (with `private_endpoint_network_policies = "Disabled"`)
- `azurerm_private_endpoint.confluent` — one per Confluent zone alias (via `for_each`)
- `azurerm_private_dns_zone.confluent` — named after the Confluent DNS domain
- `azurerm_private_dns_zone_virtual_network_link.confluent`
- `azurerm_private_dns_a_record.confluent` — wildcard A per zone subdomain

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_name` | string | — | Naming prefix |
| `resource_group_name` | string | — | RG to create |
| `azure_region` | string | — | Must equal Confluent region |
| `vnet_address_space` | string | `"10.0.0.0/16"` | VNet CIDR |
| `aks_subnet_prefix` | string | `"10.0.1.0/24"` | AKS subnet CIDR |
| `pe_subnet_prefix` | string | `"10.0.2.0/24"` | PE subnet CIDR |
| `private_link_service_aliases` | map(string) | — | From `confluent-network` |
| `confluent_dns_domain` | string | — | From `confluent-network` |
| `tags` | map(string) | `{}` | Applied to every resource |

## Outputs

| Name | Description |
|------|-------------|
| `resource_group_name` | For `azure-aks` |
| `resource_group_location` | For `azure-aks` |
| `vnet_id` / `vnet_name` | For diagnostics |
| `aks_subnet_id` | For `azure-aks` |
| `pe_subnet_id` | For future PEs |
| `private_dns_zone_name` | For diagnostics |
| `private_endpoint_ips` | Map of zone → private IP (verification) |

## Example

```hcl
module "azure_network" {
  source = "../../modules/azure-network"

  project_name                = "uniper-poc"
  resource_group_name         = "uniper-poc-rg"
  azure_region                = "westeurope"
  private_link_service_aliases = module.confluent_network.private_link_service_aliases
  confluent_dns_domain        = module.confluent_network.dns_domain
  tags                        = { project = "uniper-poc", environment = "poc" }
}
```

## Gotchas

- **PE subnet `network_policies` must be Disabled** — explicit in this module
  (default in azurerm v4, but pinned here for safety).
- **DNS zone link is critical.** A misconfigured / missing link silently falls
  back to public DNS resolution → traffic goes to a public IP → connection
  fails or (worse) succeeds via the wrong path. Verify with `nslookup` from an
  AKS pod (see `scripts/kafka-smoke-test.sh`).
- **Wildcard A record per zone**, not a single root A record — Confluent
  publishes zone-prefixed FQDNs (e.g. `e-az1.lkc-xxx....`).
- The `confluent_dns_domain` input is `(known after apply)` on the first plan.
  Expect a multi-phase apply: `confluent_network` first, then this module.
