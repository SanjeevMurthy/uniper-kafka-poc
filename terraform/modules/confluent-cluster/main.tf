terraform {
  required_version = ">= 1.6.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.11"
    }
  }
}

locals {
  topics = toset(var.topic_names)
}

# ---------------------------------------------------------------------------
# Dedicated Kafka Cluster
#
# Dedicated is the smallest tier that supports Private Link on Azure.
# 1 CKU + SINGLE_ZONE is the minimum viable configuration for the POC.
#
# Provisioning takes 15-30 minutes. CKU count cannot be reduced after creation.
# ---------------------------------------------------------------------------
resource "confluent_kafka_cluster" "main" {
  display_name = var.cluster_name
  availability = var.availability
  cloud        = "AZURE"
  region       = var.confluent_region

  enterprise {}


  environment {
    id = var.environment_id
  }

  network {
    id = var.network_id
  }
}

# ---------------------------------------------------------------------------
# Cluster-admin service account — used by Terraform itself to manage topics
# and ACLs. Separate from the application service account so the app key
# cannot create/delete topics or change ACLs.
# ---------------------------------------------------------------------------
resource "confluent_service_account" "cluster_admin" {
  display_name = "${var.cluster_name}-admin"
  description  = "Service account used by Terraform to manage cluster resources (topics, ACLs)."
}

resource "confluent_role_binding" "cluster_admin" {
  principal   = "User:${confluent_service_account.cluster_admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.main.rbac_crn
}

resource "confluent_api_key" "cluster_admin" {
  display_name = "${var.cluster_name}-admin-key"
  description  = "API key for Terraform cluster management. Do not embed in applications."

  owner {
    id          = confluent_service_account.cluster_admin.id
    api_version = confluent_service_account.cluster_admin.api_version
    kind        = confluent_service_account.cluster_admin.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.main.id
    api_version = confluent_kafka_cluster.main.api_version
    kind        = confluent_kafka_cluster.main.kind

    environment {
      id = var.environment_id
    }
  }

  # The role binding must propagate before the key can be used to manage
  # topics/ACLs. Confluent is eventually consistent here.
  depends_on = [
    confluent_role_binding.cluster_admin
  ]
}

# ---------------------------------------------------------------------------
# Topics — `for_each` over var.topic_names so adding a topic is one line.
# Topic configuration is uniform across topics in this POC.
# ---------------------------------------------------------------------------
resource "confluent_kafka_topic" "this" {
  for_each = local.topics

  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }

  topic_name       = each.value
  partitions_count = var.topic_partitions
  rest_endpoint    = confluent_kafka_cluster.main.rest_endpoint

  config = {
    "retention.ms" = tostring(var.topic_retention_ms)
  }

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

# ---------------------------------------------------------------------------
# Application service account + API key — used by application code in AKS.
# Limited by ACLs (below) to produce/consume on the two topics only.
# ---------------------------------------------------------------------------
resource "confluent_service_account" "app" {
  display_name = var.app_service_account_name
  description  = "Application service account for POC producers/consumers."
}

resource "confluent_api_key" "app" {
  display_name = "${var.app_service_account_name}-key"
  description  = "API key for POC applications. Bound to the app service account."

  owner {
    id          = confluent_service_account.app.id
    api_version = confluent_service_account.app.api_version
    kind        = confluent_service_account.app.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.main.id
    api_version = confluent_kafka_cluster.main.api_version
    kind        = confluent_kafka_cluster.main.kind

    environment {
      id = var.environment_id
    }
  }
}

# ---------------------------------------------------------------------------
# ACLs — WRITE + READ on each topic, plus READ on consumer groups matching
# the configured prefix. The GROUP READ ACL is the most-commonly-missed
# piece: without it consumers fail to join groups even with topic READ.
# ---------------------------------------------------------------------------
resource "confluent_kafka_acl" "app_topic_write" {
  for_each = local.topics

  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }

  resource_type = "TOPIC"
  resource_name = each.value
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.main.rest_endpoint

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

resource "confluent_kafka_acl" "app_topic_read" {
  for_each = local.topics

  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }

  resource_type = "TOPIC"
  resource_name = each.value
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.main.rest_endpoint

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

resource "confluent_kafka_acl" "app_group_read" {
  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }

  resource_type = "GROUP"
  resource_name = var.consumer_group_prefix
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.main.rest_endpoint

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}
