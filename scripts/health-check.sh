#!/usr/bin/env bash
set -euo pipefail

base_url=""
url_file=""
port=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      base_url="${2:?missing value for --base-url}"
      shift 2
      ;;
    --url-file)
      url_file="${2:?missing value for --url-file}"
      shift 2
      ;;
    --port)
      port="${2:?missing value for --port}"
      shift 2
      ;;
    -h|--help)
      echo "usage: $0 [--base-url URL | --url-file FILE | --port PORT]"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -n "$url_file" ]]; then
  [[ -r "$url_file" ]] || { echo "health URL file is not readable: $url_file" >&2; exit 1; }
  base_url="$(tr -d '\r\n' < "$url_file")"
elif [[ -n "$port" ]]; then
  base_url="http://127.0.0.1:${port}"
fi

[[ -n "$base_url" ]] || { echo "provide --base-url, --url-file, or --port" >&2; exit 2; }
base_url="${base_url%/}"

check() {
  local path="$1"
  local expected="$2"
  local body status
  body="$(mktemp)"
  trap 'rm -f "$body"' RETURN
  status="$(curl --silent --show-error --max-time 5 --output "$body" --write-out '%{http_code}' "$base_url$path")"
  if [[ "$status" != "200" ]]; then
    echo "$path -> HTTP $status" >&2
    return 1
  fi
  if ! grep -qi "$expected" "$body"; then
    echo "$path -> HTTP 200 but expected marker '$expected' not found" >&2
    return 1
  fi
  echo "$path -> OK"
}

check /healthz live
check /readyz ready
