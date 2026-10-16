#!/usr/bin/env bash
# Select the newest provider version each constraint allows and write hashes
# for every platform CI and developers use. No cloud credentials.
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
platforms=(linux_amd64 linux_arm64 darwin_amd64 darwin_arm64)

mapfile -t dirs < <(find terraform/components/terraform test/kwok/terraform \
  -name versions.tf -not -path '*/modules/*' -printf '%h\n' | sort -u)

for dir in "${dirs[@]}"; do
  echo "==> $dir"
  terraform -chdir="$dir" init -backend=false -input=false -upgrade >/dev/null
  # shellcheck disable=SC2046
  terraform -chdir="$dir" providers lock $(printf -- '-platform=%s ' "${platforms[@]}")
done
