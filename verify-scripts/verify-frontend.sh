#!/usr/bin/env bash
set -euo pipefail

echo "==> Running frontend verification"

echo "--- TypeScript type check ---"
npx tsc --noEmit

echo "--- Lint ---"
npx eslint . --max-warnings 0

echo "--- Tests ---"
npx vitest run

echo ""
echo "All checks passed."
