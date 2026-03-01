#!/usr/bin/env bash
set -uo pipefail

# Full verification pipeline: format check → analyze → tests.
# Verbose output goes to agent_logs/; only the summary is printed to stderr.

mkdir -p agent_logs

echo "==> Running Flutter verification" >&2

echo "--- Format check (dart format) ---" >&2
dart format --set-exit-if-changed . 2>&1 | tee agent_logs/dart-format.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: dart format check failed (see agent_logs/dart-format.log)" >&2; exit 2; }

echo "--- Analyze (dart analyze) ---" >&2
dart analyze --fatal-infos 2>&1 | tee agent_logs/dart-analyze.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: dart analyze errors (see agent_logs/dart-analyze.log)" >&2; exit 2; }

echo "--- Tests (flutter test) ---" >&2
flutter test --reporter compact 2>&1 | tee agent_logs/flutter-test.log | tail -10 >&2
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "FAIL: flutter test failed (see agent_logs/flutter-test.log)" >&2; exit 2; }

echo "" >&2
echo "All checks passed." >&2
