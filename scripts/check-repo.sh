#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

for script in "$root"/scripts/*.sh; do
  bash -n "$script"
done

echo "bash syntax: OK"

python3 - <<'PY' "$root"
import json
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
for path in sorted((root / "examples" / "iam").glob("*.json")):
    json.loads(path.read_text())
    print(f"json: OK {path.relative_to(root)}")
PY

"$root/scripts/secret-scan.sh" "$root"

echo "repo checks: OK"
