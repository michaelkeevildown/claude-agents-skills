#!/usr/bin/env bash
set -uo pipefail

echo "==> Running Python verification" >&2

echo "--- Type check (mypy) ---" >&2
mypy . 2>&1 || { echo "FAIL: mypy type errors" >&2; exit 2; }

echo "--- Lint (ruff) ---" >&2
ruff check . 2>&1 || { echo "FAIL: ruff lint errors" >&2; exit 2; }

echo "--- Tests (pytest) ---" >&2
pytest 2>&1 || { echo "FAIL: pytest failed" >&2; exit 2; }

echo "" >&2
echo "All checks passed." >&2
