#!/bin/sh
# Usage: measure.sh <atmos-stack> <label> <out-dir> [ga|public]
# Runs from a machine on the same tailnet, over Tailscale SSH as root.
# With a path argument, waits until both clients' PeerRelay is an address of
# that path (GA endpoints for ga, the relay public endpoint for public) and
# fails the round otherwise. Apply the matching relay_mode first.
# Every remote command and its output is appended to <out-dir>/<label>/transcript.txt.
set -eu

stack=$1
label=$2
out=$3/$label
path=${4:-}
component=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$out"
tr=$out/transcript.txt
: >"$tr"

outputs=$(TF_WORKSPACE=$stack terraform -chdir="$component" output -json)
a_host=$(printf '%s' "$outputs" | jq -r '.clients.value.a.hostname')
b_host=$(printf '%s' "$outputs" | jq -r '.clients.value.b.hostname')
relay_host=""
name() { case $1 in a) echo "$a_host" ;; b) echo "$b_host" ;; relay) echo "$relay_host" ;; esac; }
on() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    -o ConnectTimeout=20 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 \
    "root@$(name "$1")" "$2"
}
run() {
  printf '\n$ ssh root@%s %s\n' "$(name "$1")" "$2" >>"$tr"
  r=$(on "$1" "$2" 2>&1) || true
  printf '%s\n' "$r" >>"$tr"
  printf '%s\n' "$r"
}
note() { printf '\n# %s\n' "$*" >>"$tr"; }

public_ep=$(printf '%s' "$outputs" | jq -r '.relay_public_endpoint.value')
ga_eps=$(printf '%s' "$outputs" | jq -r '.ga_endpoints.value[]')
case $path in
  "") expect="" ;;
  ga) expect=$ga_eps ;;
  public) expect=$public_ep ;;
  *) echo "path must be ga or public" >&2; exit 2 ;;
esac
if [ -n "$path" ] && [ -z "$expect" ]; then
  echo "path $path has no relay endpoints in this stack; apply relay_mode=$path first" >&2
  exit 2
fi
note "label=$label path=${path:-unset} relay_public_endpoint=${public_ep:-none} ga_endpoints=$(printf '%s' "$ga_eps" | xargs) date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

for c in a b; do
  i=0
  until on "$c" 'test -x /usr/bin/iperf3 && test -x /usr/bin/mtr && cloud-init status | grep -q done' 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -lt 60 ] || { echo "client $c not ready" >&2; exit 1; }
    sleep 10
  done
done

i=0
while :; do
  relay_host=$(on a 'tailscale status --json' | jq -r '[.Peer[] | select(.Online and ((.Tags // []) | index("tag:pr-relay")))][0].DNSName // "" | split(".")[0]')
  [ -n "$relay_host" ] && on relay true 2>/dev/null && break
  i=$((i + 1))
  [ "$i" -lt 60 ] || { echo "no reachable online tag:pr-relay peer seen from client a" >&2; exit 1; }
  sleep 10
done
b_ip=$(on b 'tailscale ip -4' | tr -d '\r')

if [ -n "$path" ]; then
  peer_relay() { on "$1" 'tailscale status --json' | jq -r --arg h "$2" '.Peer[] | select(.HostName == $h) | .PeerRelay'; }
  i=0
  while :; do
    on a "tailscale ping --until-direct=false -c 3 $b_host" >/dev/null 2>&1 || true
    on b "tailscale ping --until-direct=false -c 3 $a_host" >/dev/null 2>&1 || true
    ra=$(peer_relay a "$b_host")
    rb=$(peer_relay b "$a_host")
    ok=0
    for ep in $expect; do
      case $ra in "$ep":*) ok=$((ok + 1)) ;; esac
      case $rb in "$ep":*) ok=$((ok + 1)) ;; esac
    done
    [ "$ok" -eq 2 ] && break
    i=$((i + 1))
    [ "$i" -lt 30 ] || { note "path $path not established: a=$ra b=$rb"; echo "path $path not established: a=$ra b=$rb" >&2; exit 1; }
    sleep 10
  done
  note "path $path established on both clients after $i retries"
fi

for c in a b; do
  run "$c" 'tailscale version' >/dev/null
  run "$c" 'tailscale netcheck' >/dev/null
  run "$c" 'tailscale debug peer-relay-servers' >/dev/null
done
for ep in $public_ep $ga_eps; do
  for c in a b; do
    run "$c" "mtr -r -n -c 10 ${ep%:*}" >/dev/null
  done
done

on b 'pkill iperf3; iperf3 -s -D' || true
run a "tailscale ping --until-direct=false -c 10 $b_host" >/dev/null
ping=$(run a "tailscale ping --until-direct=false -c 200 $b_host")
run b "tailscale ping --until-direct=false -c 20 $a_host" >/dev/null
for c in a b; do
  [ "$c" = a ] && peer=$b_host || peer=$a_host
  run "$c" 'tailscale status' >/dev/null
  printf '\n$ ssh root@%s tailscale status --json | jq ".Peer[] | select(.HostName == \\"%s\\") | {CurAddr, Relay, PeerRelay}"\n' "$(name "$c")" "$peer" >>"$tr"
  on "$c" 'tailscale status --json' | jq --arg h "$peer" '.Peer[] | select(.HostName == $h) | {CurAddr, Relay, PeerRelay}' | tee "$out/path-$c.json" >>"$tr"
done
run relay 'tailscale debug peer-relay-sessions' >/dev/null
tcp=$(run a "iperf3 -c $b_ip -t 30 -P 8")
tcpr=$(run a "iperf3 -c $b_ip -t 30 -P 8 -R")
udp=$(run a "iperf3 -c $b_ip -t 30 -u -b 50M")
run relay 'tailscale debug peer-relay-sessions' >/dev/null
run relay 'tailscale metrics print | grep peer_relay' >/dev/null

rate() { printf '%s\n' "$1" | awk '/\[SUM\].*receiver/ { for (i = 1; i <= NF; i++) if ($i ~ /bits\/sec$/) r = $(i - 1) " " $i } /^iperf3: error/ { e = $0 } END { print (r != "" ? r : (e != "" ? "failed (" e ")" : "n/a")) }'; }
{
  printf '%s\n' "$ping" | awk '/pong from/ { for (i = 1; i <= NF; i++) if ($i == "via") via = $(i + 1); ms = $NF; if (ms ~ /ms$/) sub("ms", "", ms); else if (ms ~ /s$/) { sub("s", "", ms); ms = ms * 1000 } print via, ms }' |
    sort -k2 -n | awk '{ via[NR] = $1; v[NR] = $2 } END {
      if (NR) printf "ping path=%s pongs=%d/200 min=%sms p50=%sms p95=%sms p99=%sms max=%sms\n", via[1], NR, v[1], v[int((NR + 1) * 0.50)], v[int((NR + 1) * 0.95)], v[int((NR + 1) * 0.99)], v[NR]
      else print "ping: no pongs" }'
  printf 'path a %s\npath b %s\n' "$(jq -c . "$out/path-a.json")" "$(jq -c . "$out/path-b.json")"
  printf 'iperf3 tcp x8 a->b %s, b->a %s\n' "$(rate "$tcp")" "$(rate "$tcpr")"
  printf '%s\n' "$udp" | awk '/receiver/ { for (i = 1; i <= NF; i++) { if ($i == "ms") j = $(i - 1); if ($i ~ /^[0-9]+\/[0-9]+$/) { split($i, n, "/"); l = sprintf("%.2f%% (%s)", 100 * n[1] / n[2], $i) } } } /^iperf3: error/ { e = $0 }
    END { if (j == "") printf "iperf3 udp 50M a->b %s\n", (e != "" ? "failed (" e ")" : "n/a"); else printf "iperf3 udp 50M a->b jitter %s ms, loss %s\n", j, l }'
} | tee "$out/summary.txt"
