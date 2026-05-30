#!/usr/bin/env bash
#
# kafka-smoke-test.sh — end-to-end smoke test that proves:
#   1. DNS for the Kafka bootstrap resolves to a PRIVATE IP from inside AKS
#   2. SASL/PLAIN auth works
#   3. WRITE ACL works (produce)
#   4. READ + GROUP READ ACL works (consume)
#   5. (Optional) negative test: from local laptop, the bootstrap is NOT reachable
#
# Assumes you've run `terraform apply` and are in the repo root.

set -euo pipefail

STACK_DIR="${STACK_DIR:-terraform/environments/poc}"
POD_NAME="${POD_NAME:-kafka-client}"
TOPIC="${TOPIC:-orders}"
GROUP="${GROUP:-poc-smoke}"
MESSAGE="${MESSAGE:-hello-private-kafka-$(date +%s)}"

log() { printf '\033[1;34m[smoke]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[smoke:FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

command -v terraform >/dev/null  || die "terraform not on PATH"
command -v kubectl   >/dev/null  || die "kubectl not on PATH"
command -v az        >/dev/null  || die "az not on PATH"
command -v jq        >/dev/null  || die "jq not on PATH"

cd "$(dirname "$0")/.." # repo root

log "Reading Terraform outputs from $STACK_DIR"
BOOTSTRAP=$(terraform -chdir="$STACK_DIR" output -raw kafka_bootstrap_endpoint)
API_KEY=$(terraform -chdir="$STACK_DIR" output -raw app_api_key_id)
API_SECRET=$(terraform -chdir="$STACK_DIR" output -raw app_api_key_secret)
RG=$(terraform -chdir="$STACK_DIR" output -raw resource_group_name)
AKS=$(terraform -chdir="$STACK_DIR" output -raw aks_cluster_name)

log "Bootstrap endpoint: $BOOTSTRAP"
log "AKS cluster: $AKS (RG=$RG)"

log "Fetching AKS credentials"
az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing >/dev/null

log "Applying kafka-client pod manifest"
kubectl apply -f scripts/kafka-client-pod.yaml
kubectl wait --for=condition=Ready "pod/$POD_NAME" --timeout=120s

# ----- 1. DNS check --------------------------------------------------------
log "[1/4] Resolving $BOOTSTRAP from inside the cluster..."
host=${BOOTSTRAP%:*}
resolved=$(kubectl exec "$POD_NAME" -- getent hosts "$host" | awk '{print $1}' || true)
log "Resolved to: $resolved"
case "$resolved" in
  10.*) log "OK: private IP" ;;
  *)    die "Expected 10.x.x.x; got '$resolved' — Private DNS Zone or link is wrong" ;;
esac

# ----- 2-4. Produce + consume ---------------------------------------------
log "[2/4] Writing client.properties to pod"
kubectl exec "$POD_NAME" -- bash -c "cat > /tmp/client.properties <<EOF
bootstrap.servers=${BOOTSTRAP}
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username='${API_KEY}' password='${API_SECRET}';
EOF"

log "[3/4] Producing message: $MESSAGE"
kubectl exec "$POD_NAME" -- bash -c \
  "echo '${MESSAGE}' | kafka-console-producer \
      --bootstrap-server ${BOOTSTRAP} \
      --topic ${TOPIC} \
      --producer.config /tmp/client.properties"

log "[4/4] Consuming one message from $TOPIC (group $GROUP)"
out=$(kubectl exec "$POD_NAME" -- bash -c \
  "timeout 30 kafka-console-consumer \
      --bootstrap-server ${BOOTSTRAP} \
      --topic ${TOPIC} \
      --consumer.config /tmp/client.properties \
      --from-beginning \
      --max-messages 1 \
      --group ${GROUP}")

log "Consumer output:"
echo "$out"

if echo "$out" | grep -qx "$MESSAGE"; then
  log "OK: round-trip succeeded — Private Link + ACLs verified"
else
  die "Did not see the produced message in consumer output"
fi

# ----- 5. Negative test ----------------------------------------------------
if [[ "${SKIP_NEGATIVE_TEST:-0}" != "1" ]]; then
  log "[bonus] Checking that $BOOTSTRAP is NOT reachable from this host (expect timeout)"
  if timeout 10 bash -c "</dev/tcp/${host}/9092" 2>/dev/null; then
    die "Bootstrap is reachable from outside the VNet — Private Link is bypassed!"
  fi
  log "OK: connection refused / timeout from outside the VNet"
fi

log "All checks passed ✅"
