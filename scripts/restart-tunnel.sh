#!/usr/bin/env bash
set -euo pipefail

label="${1:-}"
if [[ -z "$label" ]]; then
  echo "usage: $0 LAUNCHD_LABEL" >&2
  exit 2
fi

launchctl kickstart -k "gui/$(id -u)/${label}"
echo "restarted: ${label}"
