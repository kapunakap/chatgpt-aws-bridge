#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$temp_dir/bin"

cat > "$temp_dir/bin/aws" <<'MOCK_AWS'
#!/usr/bin/env bash
set -euo pipefail
profile=""
account_only=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) profile="$2"; shift 2 ;;
    --query) [[ "$2" == Account ]] && account_only=true; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s\n' "$profile" >> "$MOCK_AWS_CALLS"
if [[ "$profile" == "${MOCK_FAIL_PROFILE:-}" ]]; then
  echo "simulated credential failure" >&2
  exit 1
fi
if [[ "$account_only" == true ]]; then
  case "$profile" in
    readonly|same-account) echo "synthetic-account-one" ;;
    secondary) echo "synthetic-account-two" ;;
    *) echo "synthetic-account-other" ;;
  esac
else
  echo '{"Account":"synthetic-only"}'
fi
MOCK_AWS

cat > "$temp_dir/bin/launchctl" <<'MOCK_LAUNCHCTL'
#!/usr/bin/env bash
[[ "$1" == print ]]
MOCK_LAUNCHCTL

cat > "$temp_dir/bin/curl" <<'MOCK_CURL'
#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    --write-out|--max-time) shift 2 ;;
    --*) shift ;;
    *) url="$1"; shift ;;
  esac
done
if [[ "$url" == */healthz ]]; then
  echo "live" > "$output"
elif [[ "$url" == */readyz ]]; then
  echo "ready" > "$output"
else
  exit 1
fi
printf '200'
MOCK_CURL

chmod +x "$temp_dir/bin/"*
export PATH="$temp_dir/bin:$PATH"
export MOCK_AWS_CALLS="$temp_dir/aws-calls"
: > "$MOCK_AWS_CALLS"

config="$temp_dir/tunnel.yaml"
url_file="$temp_dir/health.url"
printf 'placeholder: private config\n' > "$config"
chmod 600 "$config"
printf 'http://127.0.0.1:12345\n' > "$url_file"
common=(--tunnel-config "$config" --launch-label test.aws-mcp --health-url-file "$url_file")

# Backward-compatible, single-profile case.
bash "$root/scripts/verify-setup.sh" --profile readonly "${common[@]}" > "$temp_dir/output"
[[ "$(wc -l < "$MOCK_AWS_CALLS" | tr -d ' ')" == 1 ]]
grep -q '1 profile(s)' "$temp_dir/output"

# Both profiles must be checked and both account identities must be distinct.
: > "$MOCK_AWS_CALLS"
bash "$root/scripts/verify-setup.sh" --profile readonly --profile secondary \
  --require-distinct-accounts "${common[@]}" > "$temp_dir/output"
[[ "$(wc -l < "$MOCK_AWS_CALLS" | tr -d ' ')" == 4 ]]
[[ "$(grep -c '^readonly$' "$MOCK_AWS_CALLS")" == 2 ]]
[[ "$(grep -c '^secondary$' "$MOCK_AWS_CALLS")" == 2 ]]
grep -q 'Distinct AWS accounts: OK' "$temp_dir/output"
! grep -q 'synthetic-account-' "$temp_dir/output"

# Invalid input and a failed secondary profile must not pass silently.
if bash "$root/scripts/verify-setup.sh" --profile readonly --profile readonly "${common[@]}" >/dev/null 2>&1; then
  echo "duplicate profiles incorrectly accepted" >&2; exit 1
fi
if bash "$root/scripts/verify-setup.sh" --profile readonly --profile same-account \
  --require-distinct-accounts "${common[@]}" >/dev/null 2>&1; then
  echo "identical AWS accounts incorrectly accepted" >&2; exit 1
fi
if MOCK_FAIL_PROFILE=secondary bash "$root/scripts/verify-setup.sh" \
  --profile readonly --profile secondary "${common[@]}" >/dev/null 2>&1; then
  echo "failed secondary profile incorrectly accepted" >&2; exit 1
fi
if bash "$root/scripts/verify-setup.sh" "${common[@]}" >/dev/null 2>&1; then
  echo "missing profile incorrectly accepted" >&2; exit 1
fi

echo "verify-setup mock tests: OK"
