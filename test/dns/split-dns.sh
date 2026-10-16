#!/usr/bin/env bash
# Functional test for modules/split-dns-coredns: run its rendered Corefile in
# front of a fake kube-dns and check that tailnet-style names resolve.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
VERSION=${COREDNS_VERSION:-1.14.7}
CACHE=${KWOK_CACHE:-$ROOT/.cache/kwok}
BIN=$CACHE/bin/coredns-$VERSION
WORK=$(mktemp -d "${TMPDIR:-/tmp}/split-dns.XXXXXX")
PIDS=()
# shellcheck disable=SC2317,SC2329 # invoked by the EXIT trap
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$WORK"; }
trap cleanup EXIT

if [ ! -x "$BIN" ]; then
  mkdir -p "$(dirname "$BIN")"
  curl -fsSL "https://github.com/coredns/coredns/releases/download/v$VERSION/coredns_${VERSION}_linux_amd64.tgz" |
    python3 -c 'import sys,tarfile; t=tarfile.open(fileobj=sys.stdin.buffer, mode="r|gz"); [open(sys.argv[1],"wb").write(t.extractfile(m).read()) for m in t if m.name.endswith("coredns")]' "$BIN"
  chmod +x "$BIN"
fi
port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }
UP=$(port) DNS=$(port) HEALTH=$(port) READY=$(port)

cat > "$WORK/upstream" <<CONF
cluster.local:$UP {
    bind 127.0.0.1
    hosts {
        10.31.0.42 goldpinger-cluster4.default.svc.cluster.local
    }
}
CONF
python3 - "$ROOT/terraform/components/terraform/modules/split-dns-coredns/Corefile.tftpl" "$WORK/Corefile" "$UP" "$HEALTH" "$READY" <<'PY'
import string, sys
src, dst, up, health, ready = sys.argv[1:]
s = string.Template(open(src).read()).substitute(environment="gkedpv2-uc1", upstream=f"127.0.0.1:{up}")
# Same config, local ports: bind loopback and move the probes off 8080/8181.
s = s.replace("    health\n", f"    bind 127.0.0.1\n    health 127.0.0.1:{health}\n").replace("    ready\n", f"    ready 127.0.0.1:{ready}\n")
open(dst, "w").write(s)
PY
"$BIN" -conf "$WORK/upstream" >"$WORK/upstream.log" 2>&1 & PIDS+=($!)
"$BIN" -conf "$WORK/Corefile" -dns.port "$DNS" >"$WORK/split.log" 2>&1 & PIDS+=($!)
for _ in $(seq 50); do curl -fs "http://127.0.0.1:$READY/ready" >/dev/null 2>&1 && break; sleep 0.2; done

fail=0
for proto in udp tcp; do
  got=$(python3 "$ROOT/test/dns/query.py" 127.0.0.1 "$DNS" goldpinger-cluster4.default.gkedpv2-uc1.svc.cluster.local "$proto" || true)
  want="goldpinger-cluster4.default.gkedpv2-uc1.svc.cluster.local 10.31.0.42"
  if [ "$got" = "$want" ]; then echo "ok   $proto: $got"; else echo "FAIL $proto: got '$got', want '$want'"; fail=1; fi
done
if [ $fail = 1 ]; then echo "--- split CoreDNS log"; cat "$WORK/split.log"; fi
exit $fail
