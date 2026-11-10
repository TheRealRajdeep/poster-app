#!/usr/bin/env bash
# Run the same checks as CI. Usage: bash tool/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || export PATH="$PATH:/c/src/flutter/bin"

echo "== analyze"; flutter analyze --fatal-infos
echo "== app";     flutter test
echo "== poster_spec";     (cd packages/poster_spec && dart test)
echo "== poster_renderer"; (cd packages/poster_renderer && flutter test)
echo "== wa_share";        (cd packages/wa_share && flutter test)
if python -c "import jsonschema" 2>/dev/null; then
  echo "== spec schema"; python packages/poster_spec/tool/check_schema.py packages/poster_spec >/dev/null
else
  echo "== spec schema: skipped (pip install jsonschema to enable)"
fi
echo "ALL CHECKS PASSED"
