#!/usr/bin/env bash
set -uo pipefail

# Full verification pipeline: type check → lint → tests.
# Verbose output goes to agent_logs/; only the summary is printed to stderr.

mkdir -p agent_logs

echo "==> Running Python verification" >&2

echo "--- Type check (mypy) ---" >&2
mypy . 2>&1 | tee agent_logs/mypy.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: mypy type errors (see agent_logs/mypy.log)" >&2; exit 2; }

echo "--- Lint (ruff) ---" >&2
ruff check . 2>&1 | tee agent_logs/ruff.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: ruff lint errors (see agent_logs/ruff.log)" >&2; exit 2; }

echo "--- Tests (pytest) ---" >&2
pytest --tb=short --no-header -q 2>&1 | tee agent_logs/pytest.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: pytest failed (see agent_logs/pytest.log)" >&2; exit 2; }

echo "" >&2
echo "All checks passed." >&2
