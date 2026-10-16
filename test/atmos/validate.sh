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

expected="kb-gkedpv2-uc1-test my-aws-uw2-test my-az-ue1-test my-gke-gce-uc1-test"
actual=$(atmos list stacks | sort | xargs)
[ "$actual" = "$expected" ] || { echo "stack names: got '$actual', want '$expected'" >&2; exit 1; }
echo "stacks: $actual"

for wf in stacks/workflows/*.yaml; do
  echo "==> atmos workflow validate-all -f $(basename "$wf")"
  atmos workflow validate-all -f "$(basename "$wf")"
done
