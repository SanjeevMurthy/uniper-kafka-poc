#!/usr/bin/env bash
#
# verify-oidc.sh — sanity-check that the current Azure CLI session is logged
# in via OIDC (the service principal), not via a user UPN.
#
# Use in two places:
#   1. Locally, after a manual `az login --federated-token` test, to confirm
#      the federated credential maps to the expected SP.
#   2. As the first step of any troubleshooting session where you suspect
#      identity issues.
#
# Exits 0 if the session is the expected SP; 1 otherwise.

set -euo pipefail

required_client_id="${EXPECTED_CLIENT_ID:-}"

if ! command -v az >/dev/null; then
  echo "::error::az CLI not on PATH" >&2
  exit 1
fi

# `az account show` returns the principal in `user.name`. For a UPN login this
# is "alice@example.com"; for an SP login it's the AD app's client ID.
account_json=$(az account show -o json)
user_name=$(echo "$account_json" | jq -r '.user.name')
user_type=$(echo "$account_json" | jq -r '.user.type')
tenant_id=$(echo "$account_json" | jq -r '.tenantId')
sub_id=$(echo "$account_json" | jq -r '.id')

echo "Tenant:        $tenant_id"
echo "Subscription:  $sub_id"
echo "user.type:     $user_type"
echo "user.name:     $user_name"

if [[ "$user_type" != "servicePrincipal" ]]; then
  echo "::error::Logged in as $user_type, not servicePrincipal — OIDC is not active" >&2
  exit 1
fi

if [[ -n "$required_client_id" && "$user_name" != "$required_client_id" ]]; then
  echo "::error::SP client ID mismatch — expected $required_client_id, got $user_name" >&2
  exit 1
fi

echo "OK: session is an SP-typed login${required_client_id:+ matching $required_client_id}."
