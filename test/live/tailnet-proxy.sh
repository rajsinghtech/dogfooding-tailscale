#!/usr/bin/env bash
# Join a (dogfood) tailnet from a machine that is not on it, without touching
# the host's own Tailscale: a userspace tailscaled with in-memory state and its
# own socket, exposing local SOCKS5 and HTTP proxies.
#
#   test/live/tailnet-proxy.sh up      # needs TS_OAUTH_CLIENT_ID / TS_OAUTH_CLIENT_SECRET
#   eval "$(test/live/tailnet-proxy.sh env)"
#   test/live/tailnet-proxy.sh status
#   test/live/tailnet-proxy.sh down
#
# The ephemeral node is tagged TS_PROXY_TAG (default tag:infra), which the OAuth
# client must own and the policy must allow to reach the advertised subnets.
set -euo pipefail

DIR=${TS_PROXY_DIR:-${XDG_RUNTIME_DIR:-/tmp}/dogfooding-tailscale-proxy}
SOCK=$DIR/tailscaled.sock
SOCKS_PORT=${TS_PROXY_SOCKS_PORT:-1055}
HTTP_PORT=${TS_PROXY_HTTP_PORT:-1056}
TAG=${TS_PROXY_TAG:-tag:infra}
ts() { tailscale --socket="$SOCK" "$@"; }

case ${1:-} in
  up)
    : "${TS_OAUTH_CLIENT_ID:?set TS_OAUTH_CLIENT_ID}" "${TS_OAUTH_CLIENT_SECRET:?set TS_OAUTH_CLIENT_SECRET}"
    mkdir -p "$DIR" && chmod 700 "$DIR"
    token=$(curl -fsS https://api.tailscale.com/api/v2/oauth/token \
      -d "client_id=$TS_OAUTH_CLIENT_ID" -d "client_secret=$TS_OAUTH_CLIENT_SECRET" | jq -r .access_token)
    key=$(curl -fsS https://api.tailscale.com/api/v2/tailnet/-/keys -H "Authorization: Bearer $token" \
      -H 'Content-Type: application/json' \
      -d "{\"capabilities\":{\"devices\":{\"create\":{\"reusable\":false,\"ephemeral\":true,\"preauthorized\":true,\"tags\":[\"$TAG\"]}}},\"expirySeconds\":3600,\"description\":\"dogfooding-tailscale live test proxy\"}" |
      jq -r .key)
    nohup tailscaled --tun=userspace-networking --state=mem: --statedir="$DIR" --socket="$SOCK" \
      --socks5-server="127.0.0.1:$SOCKS_PORT" --outbound-http-proxy-listen="127.0.0.1:$HTTP_PORT" \
      >"$DIR/tailscaled.log" 2>&1 &
    echo $! > "$DIR/tailscaled.pid"
    for _ in $(seq 50); do [ -S "$SOCK" ] && break; sleep 0.2; done
    ts up --auth-key="$key" --hostname="dogfooding-live-$(hostname | cut -c1-20)" --accept-routes --accept-dns=false
    ts status --self --peers=false
    ;;
  env)
    echo "export HTTPS_PROXY=http://127.0.0.1:$HTTP_PORT HTTP_PROXY=http://127.0.0.1:$HTTP_PORT ALL_PROXY=socks5h://127.0.0.1:$SOCKS_PORT"
    ;;
  status)
    ts status
    ;;
  down)
    ts logout 2>/dev/null || true
    if [ -f "$DIR/tailscaled.pid" ]; then kill "$(cat "$DIR/tailscaled.pid")" 2>/dev/null || true; fi
    rm -rf "$DIR"
    ;;
  *)
    echo "usage: $0 up|env|status|down" >&2; exit 2 ;;
esac
