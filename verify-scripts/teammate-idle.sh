#!/usr/bin/env bash
set -uo pipefail

# TeammateIdle hook: scans feature-docs/ for pending work and logs what it finds.
# Always exits 0 to let the agent session terminate cleanly. The coordinator
# manages role transitions and launches fresh agent sessions.
# (Previously used exit 2 to redirect idle agents, but this caused agents to
# linger and interfere with the next role's file changes.)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FEATURE_DIR="${PROJECT_DIR}/feature-docs"

# If no feature-docs directory, nothing to do
if [ ! -d "${FEATURE_DIR}" ]; then
  exit 0
fi

# Detect project stack for flow-aware priority routing
. "${PROJECT_DIR}/scripts/lifecycle-stage.sh"

# Stuck detection: warn if a feature has been in building/ for over 30 minutes.
# Uses the file's modification time as a proxy for when work started.
STUCK_THRESHOLD=1800  # 30 minutes in seconds
NOW=$(date +%s)
for doc in "${FEATURE_DIR}"/building/*.md; do
  [ -f "${doc}" ] || continue
  if [ "$(uname)" = "Darwin" ]; then
    MOD_TIME=$(stat -f '%m' "${doc}")
  else
    MOD_TIME=$(stat -c '%Y' "${doc}")
  fi
  ELAPSED=$((NOW - MOD_TIME))
  if [ "${ELAPSED}" -gt "${STUCK_THRESHOLD}" ]; then
    TITLE=$(grep -m1 '^title:' "${doc}" | sed 's/^title:[[:space:]]*//')
    MINS=$((ELAPSED / 60))
    echo "WARN: ${TITLE} has been in building/ for ${MINS} minutes without completing." >&2
    echo "The builder may be stuck. Consider checking agent_logs/ for errors or moving the doc back to testing/ to restart." >&2
  fi
done

if [ "${PROJECT_STACK}" = "frontend" ]; then
  # Frontend (build-first): builder picks up from ready/, test-writer from testing/

  # Priority 1: Features needing E2E tests (test-writer)
  for doc in "${FEATURE_DIR}"/testing/*.md; do
    [ -f "${doc}" ] || continue
    TITLE=$(grep -m1 '^title:' "${doc}" | sed 's/^title:[[:space:]]*//')
    echo "Pending work found: ${TITLE} needs E2E tests (status: testing)" >&2
    echo "Pick up feature-docs/testing/$(basename "${doc}") — read the feature doc and implementation, then write passing Playwright E2E tests." >&2
    exit 0
  done

  # Priority 2: Features ready for building
  for doc in "${FEATURE_DIR}"/ready/*.md; do
    [ -f "${doc}" ] || continue
    TITLE=$(grep -m1 '^title:' "${doc}" | sed 's/^title:[[:space:]]*//')
    echo "Pending work found: ${TITLE} needs implementation (status: ready)" >&2
    echo "Pick up feature-docs/ready/$(basename "${doc}") — read the feature doc and implement from acceptance criteria." >&2
    exit 0
  done
else
  # Python/Rust (TDD): test-writer picks up from ready/, builder from testing/

  # Priority 1: Features with failing tests need a builder
  for doc in "${FEATURE_DIR}"/testing/*.md; do
    [ -f "${doc}" ] || continue
    TITLE=$(grep -m1 '^title:' "${doc}" | sed 's/^title:[[:space:]]*//')
    echo "Pending work found: ${TITLE} needs implementation (status: testing)" >&2
    echo "Pick up feature-docs/testing/$(basename "${doc}") — read the feature doc and failing tests, then implement until all tests pass." >&2
    exit 0
  done

  # Priority 2: Features ready for test-writing
  for doc in "${FEATURE_DIR}"/ready/*.md; do
    [ -f "${doc}" ] || continue
    TITLE=$(grep -m1 '^title:' "${doc}" | sed 's/^title:[[:space:]]*//')
    echo "Pending work found: ${TITLE} needs tests (status: ready)" >&2
    echo "Pick up feature-docs/ready/$(basename "${doc}") — read the feature doc and write failing tests for all acceptance criteria." >&2
    exit 0
  done
fi

# Priority 3: Features waiting for review
for doc in "${FEATURE_DIR}"/review/*.md; do
  [ -f "${doc}" ] || continue
  TITLE=$(grep -m1 '^title:' "${doc}" | sed 's/^title:[[:space:]]*//')
  echo "Pending work found: ${TITLE} needs review (status: review)" >&2
  echo "Review feature-docs/review/$(basename "${doc}") — check code quality, conventions, and test coverage." >&2
  exit 0
done

# No pending work
exit 0
