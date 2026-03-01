#!/usr/bin/env bash
set -uo pipefail

# Fast verification: dart analyze only, no format check or full test suite.
# Use this for quick feedback during development. The full verify.sh
# runs on TaskCompleted and before marking work done.

echo "==> Running fast Flutter verification (dart analyze only)" >&2

echo "--- Analyze (dart analyze) ---" >&2
dart analyze --fatal-infos 2>&1 || { echo "FAIL: dart analyze errors" >&2; exit 2; }

echo "" >&2
echo "Fast check passed." >&2
