#!/bin/sh
# Usage: measure.sh <atmos-stack> <label> <out-dir>
# Runs from a machine on the same tailnet, over Tailscale SSH as root.
set -eu

stack=$1
label=$2
out=$3/$label
component=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$out"

clients=$(TF_WORKSPACE=$stack terraform -chdir="$component" output -json clients)
get() { printf '%s' "$clients" | jq -r ".$1.$2"; }
on() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    "root@$(get "$1" hostname)" "$2"
}

for c in a b; do
  i=0
  until on "$c" 'test -x /usr/bin/iperf3 && cloud-init status | grep -q done' 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -lt 60 ] || { echo "client $c not ready" >&2; exit 1; }
    sleep 10
  done
done

b_host=$(get b hostname)
b_ip=$(on b 'tailscale ip -4' | tr -d '\r')

on b 'sudo pkill iperf3; iperf3 -s -D' || true
on a "sudo tailscale ping --until-direct=false -c 10 $b_host" >"$out/warmup.txt" || true
on a "sudo tailscale ping --until-direct=false -c 50 $b_host" >"$out/ping.txt" || true
on a 'sudo tailscale status --json' | jq --arg h "$b_host" '.Peer[] | select(.HostName == $h) | {CurAddr, Relay, PeerRelay}' >"$out/path.json"
on a "iperf3 -c $b_ip -t 20 -J" >"$out/iperf3.json"
on a "iperf3 -c $b_ip -t 20 -R -J" >"$out/iperf3-reverse.json"

awk '/pong from/ { for (i = 1; i <= NF; i++) if ($i == "via") via = $(i + 1); ms = $NF; sub("ms", "", ms); print via, ms }' "$out/ping.txt" |
  sort -k2 -n | awk '{ via[NR] = $1; v[NR] = $2 } END { if (NR) printf "ping path=%s n=%d min=%sms p50=%sms max=%sms\n", via[1], NR, v[1], v[int((NR + 1) / 2)], v[NR] }' | tee "$out/summary.txt"
printf 'path %s\n' "$(jq -c . "$out/path.json")" | tee -a "$out/summary.txt"
printf 'iperf3 a->b %.1f Mbit/s, b->a %.1f Mbit/s\n' \
  "$(jq '.end.sum_received.bits_per_second / 1e6' "$out/iperf3.json")" \
  "$(jq '.end.sum_received.bits_per_second / 1e6' "$out/iperf3-reverse.json")" | tee -a "$out/summary.txt"
