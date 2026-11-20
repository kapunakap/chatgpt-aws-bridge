#!/usr/bin/env bash
set -euo pipefail

root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

# Conservative patterns for common credential leaks. This is not a replacement
# for a dedicated scanner such as gitleaks/trufflehog.
patterns=(
  'AKIA[0-9A-Z]{16}'
  'ASIA[0-9A-Z]{16}'
  'AWS_SECRET_ACCESS_KEY[[:space:]]*=[[:space:]]*[^[:space:]]+'
  'AWS_SESSION_TOKEN[[:space:]]*=[[:space:]]*[^[:space:]]+'
  '-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----|-----BEGIN PRIVATE KEY-----'
  'xox[baprs]-[A-Za-z0-9-]+'
  'gh[pousr]_[A-Za-z0-9_]+'
)

failed=0
for pattern in "${patterns[@]}"; do
  if grep -RInE \
      --exclude-dir=.git \
      --exclude='secret-scan.sh' \
      -- "$pattern" "$root" >/dev/null; then
    echo "potential secret matched a configured pattern" >&2
    failed=1
  else
    status=$?
    if [[ "$status" -gt 1 ]]; then
      echo "secret scan could not complete" >&2
      exit "$status"
    fi
  fi
done

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

echo "secret scan: no known credential patterns found"
