#!/usr/bin/env bash
set -uo pipefail

echo "==> Running frontend verification" >&2

echo "--- TypeScript type check ---" >&2
npx tsc --noEmit 2>&1 || { echo "FAIL: TypeScript errors" >&2; exit 2; }

echo "--- Lint ---" >&2
npx eslint . --max-warnings 0 2>&1 || { echo "FAIL: Lint errors" >&2; exit 2; }

echo "--- Tests ---" >&2
npx vitest run 2>&1 || { echo "FAIL: Tests failed" >&2; exit 2; }

echo "" >&2
echo "All checks passed." >&2
