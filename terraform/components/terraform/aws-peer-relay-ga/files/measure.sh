#!/bin/sh
# Usage: measure.sh <atmos-stack> <label> <out-dir> [ga|public]
# Runs from a machine on the same tailnet, over Tailscale SSH as root.
# The optional path argument needs relay_mode=both: it blocks the other path's
# relay addresses on both clients, so each client's bind can only succeed on
# the path under test (clients bind to the first relay address that answers).
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
  "") block="" expect="" ;;
  ga) block=$public_ep expect=$ga_eps ;;
  public) block=$ga_eps expect=$public_ep ;;
  *) echo "path must be ga or public" >&2; exit 2 ;;
esac
if [ -n "$path" ] && { [ -z "$public_ep" ] || [ -z "$ga_eps" ]; }; then
  echo "path $path needs relay_mode=both (relay public endpoint and GA endpoints)" >&2
  exit 2
fi
note "label=$label path=${path:-unset} relay_public_endpoint=${public_ep:-none} ga_endpoints=$(printf '%s' "$ga_eps" | xargs) date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

rule() { printf 'iptables %s OUTPUT -p udp -d %s --dport %s -m comment --comment pr-ga-block -j DROP' "$1" "${2%:*}" "${2##*:}"; }
unblock=""
for ep in $public_ep $ga_eps; do
  unblock="$unblock while $(rule -D "$ep") 2>/dev/null; do :; done;"
done

for c in a b; do
  i=0
  until on "$c" 'test -x /usr/bin/iperf3 && test -x /usr/bin/mtr && cloud-init status | grep -q done' 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -lt 60 ] || { echo "client $c not ready" >&2; exit 1; }
    sleep 10
  done
done

relay_host=$(on a 'tailscale status --json' | jq -r '[.Peer[] | select(.Online and ((.Tags // []) | index("tag:pr-relay")))][0].DNSName // "" | split(".")[0]')
[ -n "$relay_host" ] || { echo "no online tag:pr-relay peer seen from client a" >&2; exit 1; }
b_ip=$(on b 'tailscale ip -4' | tr -d '\r')

if [ -n "$path" ]; then
  trap 'for c in a b; do on "$c" "$unblock true" || true; done' EXIT
  rules=""
  for ep in $block; do
    rules="$rules $(rule -I "$ep");"
  done
  for c in a b; do
    note "client $c: block the relay addresses not under test, then restart tailscaled so it binds again"
    run "$c" "$unblock $rules systemctl restart tailscaled" >/dev/null
    run "$c" 'iptables -S OUTPUT | grep pr-ga-block' >/dev/null
  done

  peer_relay() { on "$1" 'tailscale status --json' | jq -r --arg h "$2" '.Peer[] | select(.HostName == $h) | .PeerRelay'; }
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

rate() { printf '%s\n' "$1" | awk '/\[SUM\].*receiver/ { for (i = 1; i <= NF; i++) if ($i ~ /bits\/sec$/) r = $(i - 1) " " $i } END { print (r == "" ? "n/a" : r) }'; }
{
  printf '%s\n' "$ping" | awk '/pong from/ { for (i = 1; i <= NF; i++) if ($i == "via") via = $(i + 1); ms = $NF; sub("ms", "", ms); print via, ms }' |
    sort -k2 -n | awk '{ via[NR] = $1; v[NR] = $2 } END {
      if (NR) printf "ping path=%s pongs=%d/200 min=%sms p50=%sms p95=%sms p99=%sms max=%sms\n", via[1], NR, v[1], v[int((NR + 1) * 0.50)], v[int((NR + 1) * 0.95)], v[int((NR + 1) * 0.99)], v[NR]
      else print "ping: no pongs" }'
  printf 'path a %s\npath b %s\n' "$(jq -c . "$out/path-a.json")" "$(jq -c . "$out/path-b.json")"
  printf 'iperf3 tcp x8 a->b %s, b->a %s\n' "$(rate "$tcp")" "$(rate "$tcpr")"
  printf '%s\n' "$udp" | awk '/receiver/ { for (i = 1; i <= NF; i++) { if ($i == "ms") j = $(i - 1); if ($i ~ /^\(.*%\)$/) l = $i } } END { printf "iperf3 udp 50M a->b jitter %s ms, loss %s\n", (j == "" ? "n/a" : j), (l == "" ? "n/a" : l) }'
} | tee "$out/summary.txt"
