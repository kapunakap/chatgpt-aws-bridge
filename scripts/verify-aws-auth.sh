#!/usr/bin/env bash
set -euo pipefail

profile=""
region=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      profile="${2:?missing value for --profile}"
      shift 2
      ;;
    --region)
      region="${2:?missing value for --region}"
      shift 2
      ;;
    -h|--help)
      echo "usage: $0 [--profile PROFILE] [--region REGION]"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

command -v aws >/dev/null 2>&1 || { echo "aws CLI not found" >&2; exit 1; }

args=(sts get-caller-identity --output json)
[[ -n "$profile" ]] && args+=(--profile "$profile")
[[ -n "$region" ]] && args+=(--region "$region")

# Suppress account, ARN, and user ID from stdout. Only success/failure matters here.
if aws "${args[@]}" >/dev/null; then
  echo "AWS authentication: OK"
else
  echo "AWS authentication: FAILED" >&2
  exit 1
fi
