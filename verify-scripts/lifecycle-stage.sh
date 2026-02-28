#!/usr/bin/env bash
# Detects the active lifecycle stage and project stack from feature-docs/.
# Source this script; it sets:
#   LIFECYCLE_STAGE: testing | building | review | none
#   PROJECT_STACK:   frontend | python | rust | unknown
#
# Permissive stage logic (for verification skipping):
#   Python/Rust (TDD): testing > building > review
#     — test-writer's unresolved imports poison the type checker
#   Frontend (build-first): no stage needs skipping
#     — builder writes real code, test-writer writes passing E2E tests

_PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PROJECT_DIR:-$(pwd)}}"
_FEATURE_DIR="${_PROJECT_ROOT}/feature-docs"

# Detect project stack from project root marker files
PROJECT_STACK="unknown"
if [ -f "${_PROJECT_ROOT}/package.json" ]; then
  PROJECT_STACK="frontend"
elif [ -f "${_PROJECT_ROOT}/Cargo.toml" ]; then
  PROJECT_STACK="rust"
elif [ -f "${_PROJECT_ROOT}/pyproject.toml" ] || [ -f "${_PROJECT_ROOT}/setup.py" ]; then
  PROJECT_STACK="python"
fi

LIFECYCLE_STAGE="none"

if [ -d "${_FEATURE_DIR}" ]; then
  if [ "${PROJECT_STACK}" = "frontend" ]; then
    # Frontend (build-first): builder goes first, no permissiveness needed.
    # Scan building > testing > review for informational stage detection.
    for _stage in building testing review; do
      _dir="${_FEATURE_DIR}/${_stage}"
      [ -d "${_dir}" ] || continue
      for _doc in "${_dir}"/*.md; do
        [ -f "${_doc}" ] || continue
        if awk '/^---$/{if(++c==2)exit} c==1 && /^status:/{found=1} END{exit !found}' "${_doc}" 2>/dev/null; then
          LIFECYCLE_STAGE="${_stage}"
          break 2
        fi
      done
    done
  else
    # Python/Rust (TDD): testing wins as most permissive stage
    # because test-writer's unresolved imports poison the type checker.
    for _stage in testing building review; do
      _dir="${_FEATURE_DIR}/${_stage}"
      [ -d "${_dir}" ] || continue
      for _doc in "${_dir}"/*.md; do
        [ -f "${_doc}" ] || continue
        if awk '/^---$/{if(++c==2)exit} c==1 && /^status:/{found=1} END{exit !found}' "${_doc}" 2>/dev/null; then
          LIFECYCLE_STAGE="${_stage}"
          break 2
        fi
      done
    done
  fi
fi
