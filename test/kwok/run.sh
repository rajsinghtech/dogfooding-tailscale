#!/usr/bin/env bash
# Reconcile one cluster's Flux tree end to end on a KWOK control plane.
#
#   test/kwok/run.sh <cluster>        e.g. test/kwok/run.sh cluster2
#
# KWOK runs a real kube-apiserver/etcd/scheduler/controller-manager as host
# processes and simulates nodes and pods, so no Docker, root or cloud
# credentials are needed. Flux Operator and the Flux controllers also run as
# host processes against it. The harness reproduces what Terraform's
# *-k8s-setup roots do (flux-operator chart, bootstrap Secrets, FluxInstance)
# and syncs a snapshot of the working tree from a local Git server.
#
# Environment:
#   KWOK_BOOTSTRAP terraform (default): apply modules/flux-bootstrap, as the
#                  *-k8s-setup roots do; make: run clusters/<cluster> make targets
#   KWOK_TIMEOUT   seconds to wait for every Flux object to be Ready (default 900)
#   KWOK_KEEP=1    leave the cluster and controllers running after the test
#   KWOK_CACHE     binary cache directory (default .cache/kwok)
# Assertions are single-quoted strings that check() evaluates later.
# shellcheck disable=SC2016
set -euo pipefail

# Parse the whole script before running it, so editing it mid-run is safe.
{

CLUSTER=${1:?usage: test/kwok/run.sh <cluster>}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LIB=$ROOT/test/kwok/lib
TIMEOUT=${KWOK_TIMEOUT:-900}
BOOTSTRAP=${KWOK_BOOTSTRAP:-terraform}
CACHE=${KWOK_CACHE:-$ROOT/.cache/kwok}
NAME=dt-${CLUSTER//[^a-z0-9]/-}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/kwok-$CLUSTER.XXXXXX")
DUMMY_TOKEN=kwok-webhook-token
PIDS=()

[ -d "$ROOT/clusters/$CLUSTER/flux" ] || { echo "unknown cluster: $CLUSTER" >&2; exit 2; }
case $BOOTSTRAP in terraform|make) ;; *) echo "KWOK_BOOTSTRAP must be terraform or make" >&2; exit 2 ;; esac
for tool in kwokctl kubectl helm flux sops gpg git jq python3 make $([ "$BOOTSTRAP" = terraform ] && echo terraform); do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 2; }
done
# shellcheck source=/dev/null
. "$ROOT/clusters/common/bootstrap/versions.env"

log() { printf '\n==> %s\n' "$*"; }
port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }

# shellcheck disable=SC2317,SC2329 # invoked by the EXIT trap
cleanup() {
  status=$?
  if [ "${KWOK_KEEP:-0}" = 1 ]; then
    echo "KWOK_KEEP=1: leaving cluster $NAME running; KUBECONFIG=$WORK/kubeconfig, logs in $WORK/logs"
    exit "$status"
  fi
  for pid in "${PIDS[@]}"; do pkill -P "$pid" 2>/dev/null || true; kill "$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
  kwokctl delete cluster --name "$NAME" --kubeconfig "$WORK/kubeconfig" >/dev/null 2>&1 || true
  rm -rf "$WORK"
  exit "$status"
}
trap cleanup EXIT

# Keep kwokctl and every tool below off the caller's kubeconfig, and stop the
# controllers from treating the host as in-cluster when the harness itself runs
# in a pod.
export KUBECONFIG=$WORK/kubeconfig
unset KUBERNETES_SERVICE_HOST KUBERNETES_SERVICE_PORT
mkdir -p "$WORK/logs" "$CACHE/bin"

log "Fetching Flux $FLUX_VERSION and Flux Operator $FLUX_OPERATOR_VERSION controller binaries"
declare -A BIN
while read -r name image; do
  case $name in source-controller|kustomize-controller|helm-controller|notification-controller) ;; *) continue ;; esac
  BIN[$name]=$CACHE/bin/$name-${image##*:}
  [ -x "${BIN[$name]}" ] || python3 "$LIB/image_binary.py" "$image" "${BIN[$name]}"
done < <(python3 "$LIB/flux_images.py" "$FLUX_VERSION")
# The operator image also vendors the Flux distribution manifests under /data.
BIN[flux-operator]=$CACHE/bin/flux-operator-v$FLUX_OPERATOR_VERSION
OPERATOR_DATA=$CACHE/flux-operator-data-v$FLUX_OPERATOR_VERSION
if [ ! -x "${BIN[flux-operator]}" ] || [ ! -d "$OPERATOR_DATA" ]; then
  python3 "$LIB/image_binary.py" "ghcr.io/controlplaneio-fluxcd/flux-operator:v$FLUX_OPERATOR_VERSION" \
    "${BIN[flux-operator]}" --dir /data "$OPERATOR_DATA"
fi

log "Creating KWOK cluster $NAME"
kwokctl create cluster --name "$NAME" --runtime binary --kubeconfig "$KUBECONFIG" --wait 5m
kwokctl scale node --name "$NAME" --replicas 3 >/dev/null
kubectl get nodes

log "Snapshotting the working tree with throwaway SOPS keys"
SRC=$WORK/src
mkdir -p "$SRC"
(cd "$ROOT" && git ls-files -z --cached --others --exclude-standard |
  while IFS= read -r -d '' f; do [ ! -e "$f" ] || cp --parents "$f" "$SRC"; done)
export GNUPGHOME=$WORK/gnupg
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --passphrase '' --quick-generate-key "kwok-ci@dogfooding-tailscale" rsa3072 encrypt never
FPR=$(gpg --list-keys --with-colons kwok-ci@dogfooding-tailscale | awk -F: '/^fpr/ {print $10; exit}')
cat > "$SRC/clusters/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: $FPR
EOF
for f in "$SRC"/clusters/*/flux/vars/cluster-secrets.sops.yaml; do
  printf -- '---\napiVersion: v1\nkind: Secret\nmetadata:\n  name: cluster-secrets\n  namespace: flux-system\nstringData:\n  FLUX_WEBHOOK_TOKEN: %s\n' "$DUMMY_TOKEN" > "$f"
  (cd "$SRC/clusters" && sops --encrypt --in-place "${f#"$SRC"/clusters/}")
done
git -C "$SRC" init -q -b main
git -C "$SRC" -c user.name=kwok -c user.email=kwok@localhost add -A
git -C "$SRC" -c user.name=kwok -c user.email=kwok@localhost commit -q -m "kwok snapshot"
mkdir -p "$WORK/git"
git clone -q --bare "$SRC" "$WORK/git/repo.git"
GIT_PORT=$(port)
python3 "$LIB/git_http_server.py" "$WORK/git" "$GIT_PORT" >"$WORK/logs/git.log" 2>&1 &
PIDS+=($!)

log "Starting Flux Operator and Flux controllers as host processes"
EVENTS_PORT=$(port)
STORAGE_PORT=$(port)
export RUNTIME_NAMESPACE=flux-system
mkdir -p "$WORK/data/source"
cp -r "$OPERATOR_DATA" "$WORK/data/flux-operator"
mkdir -m 700 "$WORK/kustomize-gnupg"
# Restart on exit like the kubelet would: controllers exit until their CRDs exist.
start() {
  local name=$1; shift
  local args=(--enable-leader-election=false --metrics-addr="127.0.0.1:$(port)" --health-addr="127.0.0.1:$(port)" "$@")
  (set +e; while :; do "${BIN[$name]}" "${args[@]}"; echo "--- $name exited ($?), restarting"; sleep 3; done) \
    >"$WORK/logs/$name.log" 2>&1 &
  PIDS+=($!)
}
start flux-operator --storage-path="$WORK/data/flux-operator" --web-server-port=0
start source-controller --storage-path="$WORK/data/source" --storage-addr="127.0.0.1:$STORAGE_PORT" \
  --storage-adv-addr="127.0.0.1:$STORAGE_PORT" --events-addr="http://127.0.0.1:$EVENTS_PORT/"
GNUPGHOME=$WORK/kustomize-gnupg start kustomize-controller --events-addr="http://127.0.0.1:$EVENTS_PORT/"
start helm-controller --events-addr="http://127.0.0.1:$EVENTS_PORT/"
start notification-controller --events-addr="127.0.0.1:$EVENTS_PORT" --receiverAddr="127.0.0.1:$(port)"
"$LIB/fake_tailscale_status.sh" >"$WORK/logs/fake-tailscale.log" 2>&1 &
PIDS+=($!)

gpg --batch --armor --export-secret-keys "$FPR" > "$WORK/sops.asc"
GIT_URL="http://127.0.0.1:$GIT_PORT/repo.git"
if [ "$BOOTSTRAP" = terraform ]; then
  log "Bootstrapping with terraform/components/terraform/modules/flux-bootstrap"
  export TF_DATA_DIR=$WORK/tfdata TF_IN_AUTOMATION=1 TF_PLUGIN_CACHE_DIR=$CACHE/terraform-plugins
  mkdir -p "$TF_PLUGIN_CACHE_DIR"
  tf() { terraform -chdir="$ROOT/test/kwok/terraform" "$@"; }
  tf init -input=false -lockfile=readonly -backend-config="path=$WORK/terraform.tfstate" >/dev/null
  tf apply -input=false -auto-approve \
    -var "kubeconfig=$KUBECONFIG" -var "cluster_path=clusters/$CLUSTER/flux" \
    -var "git_url=$GIT_URL" -var "sops_gpg_private_key_file=$WORK/sops.asc"
else
  log "Bootstrapping with make -C clusters/$CLUSTER bootstrap"
  CLIENT_ID=kwok-client-id CLIENT_SECRET=kwok-client-secret \
    make -C "$ROOT/clusters/$CLUSTER" bootstrap GIT_URL="$GIT_URL" SOPS_GPG_KEY_FILE="$WORK/sops.asc"
fi

log "Waiting up to ${TIMEOUT}s for the FluxInstance and every Kustomization and HelmRelease to be Ready"
not_ready() {
  { kubectl get fluxinstances,kustomizations,helmreleases,gitrepositories,helmrepositories,helmcharts -A -o json 2>/dev/null ||
    echo '{"items":[{"kind":"CustomResourceDefinitions","metadata":{"namespace":"-","name":"flux"}}]}'; } |
    jq -r '.items[] | select(([.status.conditions[]? | select(.type == "Ready" and .status == "True")] | length) == 0)
      | "\(.kind)/\(.metadata.namespace)/\(.metadata.name): \([.status.conditions[]? | select(.type == "Ready") | .message] | first // "pending")"'
}
deadline=$((SECONDS + TIMEOUT))
seen=0
while :; do
  pending=$(not_ready)
  total=$({ kubectl get kustomizations,helmreleases -A --no-headers 2>/dev/null || true; } | wc -l)
  if [ -z "$pending" ] && [ "$total" -gt 0 ] && [ "$total" -eq "$seen" ]; then break; fi
  seen=$total
  if [ $SECONDS -ge $deadline ]; then
    echo "Timed out. Not Ready:"; echo "$pending"
    flux get all -A || true
    kubectl get events -A --sort-by=.lastTimestamp | tail -40 || true
    for f in "$WORK"/logs/*.log; do echo "--- $(basename "$f") (errors)"; grep -iE '"level":"error"|error' "$f" | tail -15 || true; done
    exit 1
  fi
  sleep 10
done
flux get kustomizations -A
flux get helmreleases -A

log "Assertions"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "SOPS-decrypted cluster-secrets applied" \
  '[ "$(kubectl -n flux-system get secret cluster-secrets -o jsonpath={.data.FLUX_WEBHOOK_TOKEN} | base64 -d)" = "$DUMMY_TOKEN" ]'
check "postBuild substitution from cluster-secrets" \
  '[ "$(kubectl -n flux-system get secret webhook-token -o jsonpath={.data.token} | base64 -d)" = "$DUMMY_TOKEN" ]'
check "Tailscale operator Deployment rendered with cluster OPERATOR_HOSTNAME" \
  '[ "$(kubectl -n tailscale get deploy operator -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name==\"OPERATOR_HOSTNAME\")].value}")" = "$(kubectl -n flux-system get cm cluster-settings -o jsonpath={.data.OPERATOR_HOSTNAME})" ]'
check "Connector and ProxyClass applied" 'kubectl get connectors.tailscale.com,proxyclasses.tailscale.com -A --no-headers | grep -q .'
check "kube-prometheus-stack Grafana running" 'kubectl -n monitoring rollout status deploy/kube-prometheus-stack-grafana --timeout=60s >/dev/null'
check "goldpinger DaemonSet scheduled" '[ "$(kubectl -n default get ds goldpinger -o jsonpath={.status.numberReady})" -ge 1 ]'
check "no Flux object reports a failure" '[ -z "$(not_ready)" ]'
case $CLUSTER in
  cluster1) check "iperf ProxyGroup applied" 'kubectl get proxygroup cluster1-egress-proxy >/dev/null' ;;
  cluster2) check "PeerRelay applied" 'kubectl get peerrelays.tailscale.com kb-cluster2-aws-uw2-peer-relay >/dev/null' ;;
esac
exit $fail
}
