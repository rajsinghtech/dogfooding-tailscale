#!/usr/bin/env bash
# Render every literal helm_release chart. Proves the pinned version exists
# and templates. Does not install it and does not talk to a cluster.
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
set -a
# shellcheck disable=SC1091
. clusters/common/bootstrap/versions.env
set +a

mapfile -t releases < <(python3 - <<'PY'
import os, re
from pathlib import Path
flux = os.environ.get("FLUX_OPERATOR_VERSION", "")
for path in Path("terraform").rglob("*.tf"):
    if ".terraform" in path.parts:
        continue
    text = path.read_text()
    for block in re.finditer(r'resource\s+"helm_release"\s+"[^"]+"\s*\{', text):
        depth = 1
        i = block.end()
        while i < len(text) and depth:
            depth += (text[i] == "{") - (text[i] == "}")
            i += 1
        body = text[block.end():i]
        def field(key):
            match = re.search(rf'^\s*{key}\s*=\s*"([^"]+)"', body, re.M)
            return match.group(1) if match else ""
        version = field("version")
        if not version and re.search(r'^\s*version\s*=\s*var\.flux_operator_version\s*$', body, re.M):
            version = flux
        chart, repo = field("chart"), field("repository")
        name = field("name") or chart
        if "${" in name:
            name = chart
        if chart and repo and version:
            print("\t".join((name, repo, chart, version)))
PY
)

for row in "${releases[@]}"; do
  IFS=$'\t' read -r name repo chart version <<<"$row"
  echo "==> $name $chart $version"
  args=(template "$name" --version "$version" --namespace kube-system)
  case "$chart" in
    aws-load-balancer-controller)
      args+=(--set clusterName=ci --set region=us-west-2 --set vpcId=vpc-ci)
      ;;
    karpenter)
      args+=(--set settings.clusterName=ci)
      ;;
  esac
  if [[ "$repo" == oci://* ]]; then
    helm "${args[@]}" "$repo/$chart" >/dev/null
  else
    helm "${args[@]}" "$chart" --repo "$repo" >/dev/null
  fi
done
