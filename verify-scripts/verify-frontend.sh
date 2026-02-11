#!/usr/bin/env bash
set -uo pipefail

# Full verification pipeline: type check → lint → tests.
# Verbose output goes to agent_logs/; only the summary is printed to stderr.

mkdir -p agent_logs

echo "==> Running frontend verification" >&2

echo "--- TypeScript type check ---" >&2
npx tsc --noEmit 2>&1 | tee agent_logs/tsc.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: TypeScript errors (see agent_logs/tsc.log)" >&2; exit 2; }

echo "--- Lint ---" >&2
npx eslint . --max-warnings 0 2>&1 | tee agent_logs/eslint.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: Lint errors (see agent_logs/eslint.log)" >&2; exit 2; }

echo "--- Tests ---" >&2
npx vitest run 2>&1 | tee agent_logs/vitest.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: Tests failed (see agent_logs/vitest.log)" >&2; exit 2; }

echo "" >&2
echo "All checks passed." >&2
