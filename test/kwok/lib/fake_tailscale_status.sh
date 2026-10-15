#!/usr/bin/env bash
# Stand-in for the Tailscale operator's status writes. KWOK runs no containers,
# so nothing assigns addresses to tailscale-class LoadBalancer Services and
# Ingresses, and Flux health checks would wait on them forever.
set -uo pipefail

while true; do
  kubectl get svc -A -o json 2>/dev/null | jq -r '.items[]
    | select(.spec.type == "LoadBalancer" and (.status.loadBalancer.ingress // []) == [])
    | "\(.metadata.namespace) \(.metadata.name)"' |
    while read -r ns name; do
      kubectl -n "$ns" patch svc "$name" --subresource=status --type=merge \
        -p "{\"status\":{\"loadBalancer\":{\"ingress\":[{\"hostname\":\"$name.kwok.ts.net\",\"ip\":\"100.64.0.1\"}]}}}" >/dev/null 2>&1
    done
  kubectl get ingress -A -o json 2>/dev/null | jq -r '.items[]
    | select(.spec.ingressClassName == "tailscale" and (.status.loadBalancer.ingress // []) == [])
    | "\(.metadata.namespace) \(.metadata.name)"' |
    while read -r ns name; do
      kubectl -n "$ns" patch ingress "$name" --subresource=status --type=merge \
        -p "{\"status\":{\"loadBalancer\":{\"ingress\":[{\"hostname\":\"$name.kwok.ts.net\"}]}}}" >/dev/null 2>&1
    done
  sleep 3
done
