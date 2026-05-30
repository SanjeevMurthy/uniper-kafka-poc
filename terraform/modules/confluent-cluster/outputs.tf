output "cluster_id" {
  value       = confluent_kafka_cluster.main.id
  description = "Kafka cluster ID (e.g. lkc-xxxxxx)."
}

output "cluster_rbac_crn" {
  value       = confluent_kafka_cluster.main.rbac_crn
  description = "RBAC CRN pattern for the cluster. Useful for ad-hoc role bindings."
}

output "bootstrap_endpoint" {
  value       = confluent_kafka_cluster.main.bootstrap_endpoint
  description = "Kafka bootstrap endpoint (host:port). Pass to clients via SASL_SSL."
}

output "rest_endpoint" {
  value       = confluent_kafka_cluster.main.rest_endpoint
  description = "Kafka REST endpoint. Used by the cluster-admin API key for topic/ACL operations."
}

output "topic_names" {
  value       = [for t in confluent_kafka_topic.this : t.topic_name]
  description = "Names of the topics created by this module."
}

output "app_service_account_id" {
  value       = confluent_service_account.app.id
  description = "Application service account ID (User:<id> in ACLs)."
}

output "app_api_key_id" {
  value       = confluent_api_key.app.id
  description = "Application API key ID (the \"username\" for SASL/PLAIN)."
  sensitive   = true
}

output "app_api_key_secret" {
  value       = confluent_api_key.app.secret
  description = "Application API key secret (the \"password\" for SASL/PLAIN)."
  sensitive   = true
}
