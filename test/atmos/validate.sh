#!/usr/bin/env bash
# Validate the Atmos configuration with the example stacks materialized, and
# run every workflow's validate-all (terraform init + validate through Atmos).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/atmos-validate.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

(cd "$ROOT" && git ls-files -z --cached --others --exclude-standard terraform clusters |
  while IFS= read -r -d '' f; do [ ! -e "$f" ] || cp --parents "$f" "$WORK"; done)
find "$WORK/terraform/stacks" -name '*.yaml.example' -exec sh -c 'mv "$1" "${1%.example}"' _ {} \;
cd "$WORK/terraform"

atmos validate config
atmos validate stacks

deploys=$(find stacks/deploy -name '*.yaml' | wc -l | xargs)
actual=$(atmos list stacks | sort)
count=$(printf '%s\n' "$actual" | grep -c .)
names=$(printf '%s\n' "$actual" | xargs)
[ "$count" = "$deploys" ] || { echo "stacks: got $count, want one per deploy file ($deploys): $names" >&2; exit 1; }
if printf '%s\n' "$actual" | grep -q 'no value'; then echo "stack name template unresolved: $names" >&2; exit 1; fi
echo "stacks: $names"

for wf in stacks/workflows/*.yaml; do
  echo "==> atmos workflow validate-all -f $(basename "$wf")"
  atmos workflow validate-all -f "$(basename "$wf")"
done
