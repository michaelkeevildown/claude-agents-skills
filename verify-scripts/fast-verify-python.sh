#!/usr/bin/env bash
set -uo pipefail

# Fast verification: type check only, no lint or full test suite.
# Use this for quick feedback during development. The full verify.sh
# runs on TaskCompleted and before marking work done.

echo "==> Running fast Python verification (type check only)" >&2

echo "--- Type check (mypy) ---" >&2
mypy . 2>&1 || { echo "FAIL: mypy type errors" >&2; exit 2; }

echo "" >&2
echo "Fast check passed." >&2
