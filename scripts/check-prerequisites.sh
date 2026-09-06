#!/usr/bin/env bash
set -euo pipefail

mode="${1:-sigv4}"

need() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    printf 'missing: %s\n' "$name" >&2
    return 1
  fi
  printf 'ok: %s -> %s\n' "$name" "$(command -v "$name")"
}

case "$mode" in
  oauth)
    echo "Direct OAuth mode has no required local MCP proxy dependency."
    echo "You still need a browser/ChatGPT client and an AWS identity authorized for MCP OAuth sign-in."
    ;;
  sigv4)
    need aws
    need uvx
    need curl
    if command -v tunnel-client >/dev/null 2>&1; then
      printf 'ok: tunnel-client -> %s\n' "$(command -v tunnel-client)"
    else
      echo "missing: tunnel-client (required for the local Secure MCP Tunnel path)" >&2
      exit 1
    fi
    ;;
  *)
    echo "usage: $0 [oauth|sigv4]" >&2
    exit 2
    ;;
esac
