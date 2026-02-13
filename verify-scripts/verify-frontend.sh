#!/usr/bin/env bash
set -uo pipefail

# Full verification pipeline: type check → lint → tests.
# Verbose output goes to agent_logs/; only the summary is printed to stderr.

mkdir -p agent_logs

echo "==> Running frontend verification" >&2

echo "--- Format check (Prettier) ---" >&2
npx prettier --check . 2>&1 | tee agent_logs/prettier.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: prettier format check failed (see agent_logs/prettier.log)" >&2; exit 2; }

echo "--- TypeScript type check ---" >&2
npx tsc --noEmit 2>&1 | tee agent_logs/tsc.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: TypeScript errors (see agent_logs/tsc.log)" >&2; exit 2; }

echo "--- Lint ---" >&2
npx eslint . --max-warnings 0 2>&1 | tee agent_logs/eslint.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: Lint errors (see agent_logs/eslint.log)" >&2; exit 2; }

echo "--- Unit Tests (Vitest) ---" >&2
if [ -d node_modules/vitest ]; then
  npx vitest run 2>&1 | tee agent_logs/vitest.log | tail -10 >&2
  [ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: Unit tests failed (see agent_logs/vitest.log)" >&2; exit 2; }
else
  echo "SKIP: vitest not installed" >&2
fi

echo "--- E2E Tests (Playwright) ---" >&2
if [ -d node_modules/@playwright/test ]; then
  npx playwright test 2>&1 | tee agent_logs/playwright.log | tail -10 >&2
  [ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: E2E tests failed (see agent_logs/playwright.log)" >&2; exit 2; }
else
  echo "SKIP: @playwright/test not installed" >&2
fi

echo "" >&2
echo "All checks passed." >&2
