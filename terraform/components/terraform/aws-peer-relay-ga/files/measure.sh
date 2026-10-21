#!/bin/sh
# Usage: measure.sh <atmos-stack> <label> <out-dir> [ga|public]
# Runs from a machine on the same tailnet, over Tailscale SSH as root.
# The optional path argument needs relay_mode=both: it blocks the other path's
# relay addresses on both clients, so each client's bind can only succeed on
# the path under test (clients bind to the first relay address that answers).
set -eu

stack=$1
label=$2
out=$3/$label
path=${4:-}
component=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$out"

outputs=$(TF_WORKSPACE=$stack terraform -chdir="$component" output -json)
get() { printf '%s' "$outputs" | jq -r ".clients.value.$1.$2"; }
on() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    "root@$(get "$1" hostname)" "$2"
}

public_ep=$(printf '%s' "$outputs" | jq -r '.relay_public_endpoint.value')
ga_eps=$(printf '%s' "$outputs" | jq -r '.ga_endpoints.value[]')
case $path in
  "") block="" expect="" ;;
  ga) block=$public_ep expect=$ga_eps ;;
  public) block=$ga_eps expect=$public_ep ;;
  *) echo "path must be ga or public" >&2; exit 2 ;;
esac
if [ -n "$path" ] && { [ -z "$public_ep" ] || [ -z "$ga_eps" ]; }; then
  echo "path $path needs relay_mode=both (relay public endpoint and GA endpoints)" >&2
  exit 2
fi

rule() { printf 'iptables %s OUTPUT -p udp -d %s --dport %s -m comment --comment pr-ga-block -j DROP' "$1" "${2%:*}" "${2##*:}"; }
unblock=""
for ep in $public_ep $ga_eps; do
  unblock="$unblock while $(rule -D "$ep") 2>/dev/null; do :; done;"
done

for c in a b; do
  i=0
  until on "$c" 'test -x /usr/bin/iperf3 && cloud-init status | grep -q done' 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -lt 60 ] || { echo "client $c not ready" >&2; exit 1; }
    sleep 10
  done
done

a_host=$(get a hostname)
b_host=$(get b hostname)
b_ip=$(on b 'tailscale ip -4' | tr -d '\r')

if [ -n "$path" ]; then
  trap 'for c in a b; do on "$c" "$unblock true" || true; done' EXIT
  rules=""
  for ep in $block; do
    rules="$rules $(rule -I "$ep");"
  done
  for c in a b; do
    on "$c" "$unblock $rules systemctl restart tailscaled"
  done
fi

peer_relay() { on "$1" 'tailscale status --json' | jq -r --arg h "$2" '.Peer[] | select(.HostName == $h) | .PeerRelay'; }
if [ -n "$path" ]; then
  i=0
  while :; do
    on a "tailscale ping --until-direct=false -c 3 $b_host" >/dev/null 2>&1 || true
    ra=$(peer_relay a "$b_host")
    rb=$(peer_relay b "$a_host")
    ok=0
    for ep in $expect; do
      case $ra in "$ep":*) ok=$((ok + 1)) ;; esac
      case $rb in "$ep":*) ok=$((ok + 1)) ;; esac
    done
    [ "$ok" -eq 2 ] && break
    i=$((i + 1))
    [ "$i" -lt 30 ] || { echo "path $path not established: a=$ra b=$rb" >&2; exit 1; }
    sleep 10
  done
fi

on b 'pkill iperf3; iperf3 -s -D' || true
on a "tailscale ping --until-direct=false -c 10 $b_host" >"$out/warmup.txt" || true
on a "tailscale ping --until-direct=false -c 200 $b_host" >"$out/ping.txt" || true
for c in a b; do
  [ "$c" = a ] && peer=$b_host || peer=$a_host
  on "$c" 'tailscale status --json' | jq --arg h "$peer" '.Peer[] | select(.HostName == $h) | {CurAddr, Relay, PeerRelay}' >"$out/path-$c.json"
done
on a "iperf3 -c $b_ip -t 30 -P 8 -J" >"$out/iperf3-tcp.json"
on a "iperf3 -c $b_ip -t 30 -P 8 -R -J" >"$out/iperf3-tcp-reverse.json"
on a "iperf3 -c $b_ip -t 30 -u -b 50M -J" >"$out/iperf3-udp.json"

awk '/pong from/ { for (i = 1; i <= NF; i++) if ($i == "via") via = $(i + 1); ms = $NF; sub("ms", "", ms); print via, ms }' "$out/ping.txt" |
  sort -k2 -n | awk '{ via[NR] = $1; v[NR] = $2 } END {
    if (NR) printf "ping path=%s pongs=%d/200 min=%sms p50=%sms p95=%sms p99=%sms max=%sms\n", via[1], NR, v[1], v[int((NR + 1) * 0.50)], v[int((NR + 1) * 0.95)], v[int((NR + 1) * 0.99)], v[NR]
    else print "ping: no pongs" }' | tee "$out/summary.txt"
printf 'path a %s\npath b %s\n' "$(jq -c . "$out/path-a.json")" "$(jq -c . "$out/path-b.json")" | tee -a "$out/summary.txt"
printf 'iperf3 tcp x8 a->b %.1f Mbit/s, b->a %.1f Mbit/s\n' \
  "$(jq '.end.sum_received.bits_per_second / 1e6' "$out/iperf3-tcp.json")" \
  "$(jq '.end.sum_received.bits_per_second / 1e6' "$out/iperf3-tcp-reverse.json")" | tee -a "$out/summary.txt"
printf 'iperf3 udp 50M a->b loss %.2f%%, jitter %.2f ms\n' \
  "$(jq '.end.sum.lost_percent' "$out/iperf3-udp.json")" \
  "$(jq '.end.sum.jitter_ms' "$out/iperf3-udp.json")" | tee -a "$out/summary.txt"
