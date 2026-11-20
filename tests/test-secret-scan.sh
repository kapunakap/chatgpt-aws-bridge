#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
probe="$root/.secret-scan-probe.$$"
trap 'rm -f "$probe"' EXIT

# Keep marker split in source so scanning this test itself does not flag it.
printf '%s%s\n' '-----BEGIN PRIVATE' ' KEY-----' > "$probe"
if bash "$root/scripts/secret-scan.sh" "$root" >/dev/null 2>&1; then
  echo "secret scanner missed a private-key marker" >&2
  exit 1
fi
rm -f "$probe"

missing="$root/.secret-scan-missing.$$"
if bash "$root/scripts/secret-scan.sh" "$missing" >/dev/null 2>&1; then
  echo "secret scanner ignored a scan error" >&2
  exit 1
fi

echo "secret scan regression tests: OK"
