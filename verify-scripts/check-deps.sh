#!/usr/bin/env bash
set -euo pipefail

# check-deps.sh — Recursively check feature dependency chain.
# Usage: bash check-deps.sh <feature-doc-path> [feature-docs-dir]
#   Exit 0 = all dependencies satisfied (or no dependencies)
#   Exit 1 = blocked (prints the blocking dependency to stderr)
#   Exit 2 = circular dependency detected
#
# Reads depends-on from YAML frontmatter, checks if the dependency is in
# feature-docs/completed/, then recurses into that doc's depends-on.
# Tracks visited docs via colon-separated string to detect cycles.

if [ $# -lt 1 ]; then
  echo "Usage: check-deps.sh <feature-doc-path> [feature-docs-dir]" >&2
  exit 1
fi

DOC_PATH="$1"
FEATURE_DIR="${2:-feature-docs}"

# _VISITED tracks docs already checked in this invocation to detect cycles.
# Passed through the environment for recursive calls within the same process.
_VISITED="${_VISITED:-}"

check_deps() {
  local doc_path="$1"
  local doc_basename
  doc_basename="$(basename "${doc_path}" .md)"

  # Cycle detection
  if echo ":${_VISITED}:" | grep -q ":${doc_basename}:"; then
    echo "CIRCULAR DEPENDENCY: ${doc_basename} appears twice in the chain: ${_VISITED}:${doc_basename}" >&2
    return 2
  fi

  _VISITED="${_VISITED:+${_VISITED}:}${doc_basename}"

  # Extract depends-on from YAML frontmatter
  local dep_name
  dep_name=$(awk '/^---$/{if(++c==2)exit} c==1 && /^depends-on:/{sub(/^depends-on:[[:space:]]*/, ""); print}' "${doc_path}")

  # No dependency declared — unblocked
  if [ -z "${dep_name}" ]; then
    return 0
  fi

  # Check if the dependency is in completed/
  local dep_doc="${FEATURE_DIR}/completed/${dep_name}.md"
  if [ ! -f "${dep_doc}" ]; then
    local title
    title=$(awk '/^---$/{if(++c==2)exit} c==1 && /^title:/{sub(/^title:[[:space:]]*/, ""); print}' "${doc_path}")
    echo "BLOCKED: ${title:-${doc_basename}} depends on ${dep_name} which is not in completed/" >&2

    # Report actual location of the dependency
    local found=0
    for stage_dir in ready testing building review; do
      if [ -f "${FEATURE_DIR}/${stage_dir}/${dep_name}.md" ]; then
        echo "  (${dep_name} is currently in ${stage_dir}/)" >&2
        found=1
        break
      fi
    done
    if [ "${found}" -eq 0 ]; then
      echo "  (${dep_name} was not found in any lifecycle directory)" >&2
    fi
    return 1
  fi

  # Dependency is in completed/ — recursively check its dependencies
  check_deps "${dep_doc}"
}

check_deps "${DOC_PATH}"
