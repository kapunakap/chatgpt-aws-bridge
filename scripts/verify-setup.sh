#!/usr/bin/env bash
set -euo pipefail

profiles=()
tunnel_config=""
launch_label=""
health_url_file=""
region=""
require_distinct_accounts=false

usage() {
  echo "usage: $0 --profile PROFILE [--profile PROFILE ...] --tunnel-config FILE --launch-label LABEL --health-url-file FILE [--region REGION] [--require-distinct-accounts]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { echo "missing value for --profile" >&2; exit 2; }
      profiles+=("$2")
      shift 2
      ;;
    --region)
      region="${2:?missing value for --region}"
      shift 2
      ;;
    --require-distinct-accounts)
      require_distinct_accounts=true
      shift
      ;;
    --tunnel-config)
      tunnel_config="${2:?missing value for --tunnel-config}"
      shift 2
      ;;
    --launch-label)
      launch_label="${2:?missing value for --launch-label}"
      shift 2
      ;;
    --health-url-file)
      health_url_file="${2:?missing value for --health-url-file}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ "${#profiles[@]}" -eq 0 || -z "$tunnel_config" || -z "$launch_label" || -z "$health_url_file" ]]; then
  usage >&2
  exit 2
fi

# Repeated profile names would make a purported multi-profile check misleading.
for ((i = 0; i < ${#profiles[@]}; i++)); do
  for ((j = 0; j < i; j++)); do
    if [[ "${profiles[i]}" == "${profiles[j]}" ]]; then
      echo "duplicate AWS profile in verification arguments" >&2
      exit 2
    fi
  done
done

if [[ "$require_distinct_accounts" == true && "${#profiles[@]}" -lt 2 ]]; then
  echo "--require-distinct-accounts needs at least two profiles" >&2
  exit 2
fi

[[ -f "$tunnel_config" ]] || { echo "missing tunnel config: $tunnel_config" >&2; exit 1; }

# Private config should not be readable by group/other.
if command -v stat >/dev/null 2>&1; then
  perms="$(stat -f '%Lp' "$tunnel_config" 2>/dev/null || stat -c '%a' "$tunnel_config")"
  case "$perms" in
    600|400) ;;
    *) echo "warning: expected restrictive permissions (600/400), found $perms on $tunnel_config" >&2 ;;
  esac
fi

# Verify EACH allowlisted profile independently, in the same order as --profile
# in the private tunnel config. Profile/account identifiers are never printed.
# Avoid expanding an empty array: macOS still ships Bash 3.2 with nounset.
for ((i = 0; i < ${#profiles[@]}; i++)); do
  echo "Checking AWS profile $((i + 1))/${#profiles[@]}"
  if [[ -n "$region" ]]; then
    "$(dirname "$0")/verify-aws-auth.sh" --profile "${profiles[i]}" --region "$region"
  else
    "$(dirname "$0")/verify-aws-auth.sh" --profile "${profiles[i]}"
  fi
done

if [[ "$require_distinct_accounts" == true ]]; then
  # Compare account identifiers in memory without printing or writing them.
  # Different roles in the same account are valid configurations, but do not
  # satisfy the separate-accounts acceptance gate.
  accounts=()
  for profile in "${profiles[@]}"; do
    args=(sts get-caller-identity --profile "$profile" --query Account --output text)
    [[ -n "$region" ]] && args+=(--region "$region")
    if ! account="$(aws "${args[@]}" 2>/dev/null)" || [[ -z "$account" || "$account" == None ]]; then
      echo "could not verify account separation" >&2
      exit 1
    fi
    for ((i = 0; i < ${#accounts[@]}; i++)); do
      if [[ "$account" == "${accounts[i]}" ]]; then
        echo "configured profiles are not all in distinct AWS accounts" >&2
        exit 1
      fi
    done
    accounts+=("$account")
  done
  echo "Distinct AWS accounts: OK (identifiers suppressed)"
fi

if ! launchctl print "gui/$(id -u)/${launch_label}" >/dev/null 2>&1; then
  echo "launchd job not found/running: $launch_label" >&2
  exit 1
fi
echo "launchd: OK"

"$(dirname "$0")/health-check.sh" --url-file "$health_url_file"

echo "Local SigV4/tunnel checks: OK (${#profiles[@]} profile(s))"
echo "Final ChatGPT-side AWS MCP acceptance is still required."
