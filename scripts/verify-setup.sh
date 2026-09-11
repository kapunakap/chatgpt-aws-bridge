#!/usr/bin/env bash
set -euo pipefail

profiles=()
tunnel_config=""
launch_label=""
health_url_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      profiles+=("${2:?missing value for --profile}")
      shift 2
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
      echo "usage: $0 --profile PROFILE [--profile PROFILE ...] --tunnel-config FILE --launch-label LABEL --health-url-file FILE"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ${#profiles[@]} -eq 0 ]]; then
  echo "missing required argument: profile" >&2
  exit 2
fi

for required in tunnel_config launch_label health_url_file; do
  if [[ -z "${!required}" ]]; then
    echo "missing required argument: $required" >&2
    exit 2
  fi
done

[[ -f "$tunnel_config" ]] || { echo "missing tunnel config: $tunnel_config" >&2; exit 1; }

# Private config should not be readable by group/other.
if command -v stat >/dev/null 2>&1; then
  perms="$(stat -f '%Lp' "$tunnel_config" 2>/dev/null || stat -c '%a' "$tunnel_config")"
  case "$perms" in
    600|400) ;;
    *) echo "warning: expected restrictive permissions (600/400), found $perms on $tunnel_config" >&2 ;;
  esac
fi

for profile in "${profiles[@]}"; do
  echo "Checking AWS profile: $profile"
  "$(dirname "$0")/verify-aws-auth.sh" --profile "$profile"
done

if ! launchctl print "gui/$(id -u)/${launch_label}" >/dev/null 2>&1; then
  echo "launchd job not found/running: $launch_label" >&2
  exit 1
fi
echo "launchd: OK"

"$(dirname "$0")/health-check.sh" --url-file "$health_url_file"

echo "Local SigV4/tunnel checks: OK"
echo "Final ChatGPT-side AWS MCP acceptance is still required."
