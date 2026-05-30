# Module: `confluent-cluster`

Creates the Dedicated Kafka cluster, topics, two service accounts
(cluster-admin + application), API keys, and ACLs.

## Resources

- `confluent_kafka_cluster.main` — Dedicated, configurable CKU + availability
- `confluent_service_account.cluster_admin` + `confluent_role_binding` + `confluent_api_key`
  — admin identity used by Terraform itself for topic / ACL management
- `confluent_kafka_topic.this` — `for_each` over `topic_names`
- `confluent_service_account.app` + `confluent_api_key.app` — application identity
- `confluent_kafka_acl.app_topic_write` / `_read` — per-topic produce/consume
- `confluent_kafka_acl.app_group_read` — consumer-group prefix READ

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `cluster_name` | string | — | Display name |
| `confluent_region` | string | — | Must equal Azure region |
| `environment_id` | string | — | From `confluent-network` |
| `network_id` | string | — | From `confluent-network` |
| `availability` | string | `"SINGLE_ZONE"` | `SINGLE_ZONE` or `MULTI_ZONE` |
| `cku` | number | `1` | Confluent Kafka Units |
| `app_service_account_name` | string | `"poc-app-sa"` | App SA display name |
| `topic_names` | list(string) | `["orders","payments"]` | Topics to create |
| `topic_partitions` | number | `6` | Per topic |
| `topic_retention_ms` | number | `604800000` (7d) | Per topic |
| `consumer_group_prefix` | string | `"poc-"` | Prefix matched by GROUP READ ACL |

## Outputs

| Name | Sensitive | Description |
|------|-----------|-------------|
| `cluster_id` | no | `lkc-xxxxxx` |
| `cluster_rbac_crn` | no | For ad-hoc role bindings |
| `bootstrap_endpoint` | no | `host:9092` |
| `rest_endpoint` | no | For tools |
| `topic_names` | no | List |
| `app_service_account_id` | no | For external ACL changes |
| `app_api_key_id` | **yes** | SASL/PLAIN username |
| `app_api_key_secret` | **yes** | SASL/PLAIN password |

## Example

```hcl
module "confluent_cluster" {
  source = "../../modules/confluent-cluster"

  cluster_name     = "uniper-poc-kafka"
  confluent_region = "westeurope"
  environment_id   = module.confluent_network.environment_id
  network_id       = module.confluent_network.network_id
}
```

## Gotchas

- **Cluster provisioning takes 15-30 minutes.** Plan CI timeouts accordingly
  (`timeout-minutes: 90` is the suggested value for `apply.yml`).
- **`topic_partitions` can be increased, not decreased.** Reducing it forces
  topic replacement (data loss).
- **`availability` and `cku` cannot be changed in-place after creation** in
  many cases — read the provider release notes before adjusting.
- The **GROUP READ ACL with `PREFIXED` pattern** is required for consumers
  to join consumer groups. Forgetting it produces `GroupAuthorizationException`
  errors with no other symptoms.
- The **cluster-admin API key is the credential Terraform uses to manage
  topics and ACLs.** It is created and consumed within this module; do not
  export it to applications.
- The **app API key outputs are `sensitive = true`** — they show as
  `<sensitive>` in plans. Workflows that print outputs must filter on
  `.value.sensitive == false`.
