# Module: `confluent-network`

Creates the Confluent Cloud environment, a Private Link network, and the
Private Link Access record for an Azure subscription.

## Resources

- `confluent_environment.main`
- `confluent_network.private_link` — PRIVATELINK on AZURE, `dns_config = PRIVATE`
- `confluent_private_link_access.azure` — allows Private Endpoints from the
  registered Azure subscription to auto-approve

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `environment_name` | string | — | Display name (1-60 chars) |
| `confluent_region` | string | — | Must equal the Azure region |
| `azure_subscription_id` | string | — | GUID of the subscription with the PEs |
| `stream_governance_package` | string | `"ESSENTIALS"` | `ESSENTIALS` or `ADVANCED` |
| `zones` | list(string) | `[]` | Explicit AZ list; empty = Confluent chooses |

## Outputs

| Name | Description |
|------|-------------|
| `environment_id` | Pass to `confluent-cluster` |
| `network_id` | Pass to `confluent-cluster` |
| `dns_domain` | Pass to `azure-network` (becomes Private DNS Zone name) |
| `private_link_service_aliases` | Pass to `azure-network` (one PE per alias) |
| `zonal_subdomains` | Convenience: keys of the aliases map |

## Example

```hcl
module "confluent_network" {
  source = "../../modules/confluent-network"

  environment_name      = "uniper-poc"
  confluent_region      = "westeurope"
  azure_subscription_id = var.azure_subscription_id
}
```

## Gotchas

- **Network creation is slow** (5-15 min). Use `-target=module.confluent_network`
  during initial dev iteration to avoid waiting on later resources.
- **Region must match** the Azure region of the PE subnet — Private Link is
  region-local.
- The `dns_domain` output is only known after apply. The first plan against an
  empty environment will show `(known after apply)` on the consuming `azure-network`
  module; this is expected.
- **Cannot be destroyed while a cluster is attached.** Destroy `confluent-cluster`
  first (Terraform handles this via the DAG).
