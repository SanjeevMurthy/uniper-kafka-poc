# Stack: `environments/poc`

The actual POC environment. Composes the four modules under `terraform/modules/`:

```
module.confluent_network ──┐
                           ├─▶ module.confluent_cluster
                           │
                           ▼
                module.azure_network ──▶ module.azure_aks
```

This stack is triggered **manually** via the `plan`, `apply`, `destroy`, and
`drift` workflows in `.github/workflows/`. State lives in the storage
account created by the `bootstrap` stack.

## Inputs

All inputs have sensible defaults except:

| Required input | Where it comes from in CI |
|----------------|---------------------------|
| `confluent_cloud_api_key` | `TF_VAR_confluent_cloud_api_key` ← `secrets.CONFLUENT_CLOUD_API_KEY` (environment-scoped) |
| `confluent_cloud_api_secret` | `TF_VAR_confluent_cloud_api_secret` ← `secrets.CONFLUENT_CLOUD_API_SECRET` |
| `azure_subscription_id` | `TF_VAR_azure_subscription_id` ← `vars.AZURE_SUBSCRIPTION_ID` |

The complete variable list (with defaults) is in `variables.tf`.

## Outputs

Run `terraform output -json` after apply. Highlights:

- `kafka_bootstrap_endpoint` — pass to clients as `bootstrap.servers`
- `app_api_key_id` / `app_api_key_secret` — SASL/PLAIN username + password (sensitive)
- `aks_cluster_name` — use with `az aks get-credentials`
- `private_endpoint_ips` — verify Private DNS resolution with these

## Local plan / apply (rare — CI is the normal path)

```bash
# 1. Authenticate
az login --tenant <tenant>
az account set --subscription <sub>

# 2. Initialise the backend (you need the SA name from the bootstrap output)
STATE_SA=$(terraform -chdir=../../bootstrap output -raw state_storage_account_name)
terraform init \
  -backend-config="resource_group_name=tfstate-rg" \
  -backend-config="storage_account_name=$STATE_SA" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=poc.tfstate" \
  -backend-config="use_azuread_auth=true"

# 3. Plan / apply
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with Confluent + Azure values
terraform plan -out=tfplan
terraform apply tfplan
```

## Provisioning timeline

| Phase | Duration |
|-------|----------|
| confluent_network (env + network + PL access) | 5-15 min |
| azure_network (RG + VNet + PE + DNS) | 2-5 min (parallel with cluster once network ready) |
| confluent_cluster (Dedicated, 1 CKU, topics, ACLs) | 15-30 min |
| azure_aks | 7-12 min (parallel with cluster) |
| **Total** | ~30-50 min |

Set workflow `timeout-minutes: 90` to allow margin.

## Gotchas

- **`azure_region` must equal `confluent_region`.** They are bound together by
  `var.azure_region` being passed to both modules; do not override only one.
- **Topic config is uniform.** All topics get the same partitions / retention.
  If a topic needs a different config, add a second module instance or extend
  `confluent-cluster` with per-topic config.
- **Sensitive outputs.** `app_api_key_*` are `sensitive = true`. CI workflows
  print outputs through `jq 'select(.value.sensitive == false)'`.
- **`terraform_data.region_assertion`** is a no-op resource whose
  precondition fails the plan if `azure_region` is empty. Side effect: it
  creates one extra entry in state — harmless.

> Full operational doc: [`../../../SETUP.md`](../../../SETUP.md).
