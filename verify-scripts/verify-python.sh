#!/usr/bin/env bash
set -euo pipefail

echo "==> Running Python verification"

echo "--- Type check (mypy) ---"
mypy .

echo "--- Lint (ruff) ---"
ruff check .

echo "--- Tests (pytest) ---"
pytest

echo ""
echo "All checks passed."
