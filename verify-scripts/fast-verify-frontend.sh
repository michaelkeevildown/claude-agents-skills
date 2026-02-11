#!/usr/bin/env bash
set -uo pipefail

# Fast verification: type check only, no lint or full test suite.
# Use this for quick feedback during development. The full verify.sh
# runs on TaskCompleted and before marking work done.

echo "==> Running fast frontend verification (type check only)" >&2

echo "--- TypeScript type check ---" >&2
npx tsc --noEmit 2>&1 || { echo "FAIL: TypeScript errors" >&2; exit 2; }

echo "" >&2
echo "Fast check passed." >&2
