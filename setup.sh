#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"

usage() {
  cat <<EOF
Usage:
  ./setup.sh --global              Install global agents and skills to ~/.claude/
  ./setup.sh <stack> [extra...]    Setup project-local skills for a stack

Stacks: frontend, python, rust

Examples:
  ./setup.sh --global
  ./setup.sh frontend
  ./setup.sh python neo4j          (adds neo4j-specific skills alongside python skills)
EOF
  exit 1
}

# --- Global install ---
install_global() {
  echo "==> Installing global agents and skills to ${CLAUDE_HOME}/"

  # Agents
  mkdir -p "${CLAUDE_HOME}"

  # Remove old agents symlink/directory if it exists
  if [ -L "${CLAUDE_HOME}/agents" ] || [ -d "${CLAUDE_HOME}/agents" ]; then
    echo "    Removing old ${CLAUDE_HOME}/agents"
    rm -rf "${CLAUDE_HOME}/agents"
  fi

  ln -s "${REPO_DIR}/agents/universal" "${CLAUDE_HOME}/agents"
  echo "    Linked ${CLAUDE_HOME}/agents -> ${REPO_DIR}/agents/universal/"

  # Global skills
  mkdir -p "${CLAUDE_HOME}/skills"

  for skill_dir in "${REPO_DIR}"/skills/global/*/; do
    skill_name="$(basename "${skill_dir}")"
    target="${CLAUDE_HOME}/skills/${skill_name}"

    # Remove old symlink/directory if it exists
    if [ -L "${target}" ] || [ -d "${target}" ]; then
      rm -rf "${target}"
    fi

    ln -s "${skill_dir}" "${target}"
    echo "    Linked ${target} -> ${skill_dir}"
  done

  echo ""
  echo "Done. Global agents and skills installed."
  echo "  Agents: $(ls "${CLAUDE_HOME}/agents/" 2>/dev/null | tr '\n' ' ')"
  echo "  Skills: $(ls "${CLAUDE_HOME}/skills/" 2>/dev/null | tr '\n' ' ')"
}

# --- Project setup ---
setup_project() {
  local stack="$1"
  shift
  local extras=("$@")

  local stack_dir="${REPO_DIR}/skills/${stack}"
  if [ ! -d "${stack_dir}" ]; then
    echo "Error: Unknown stack '${stack}'. Available: frontend, python, rust"
    exit 1
  fi

  local project_dir
  project_dir="$(pwd)"
  echo "==> Setting up ${stack} skills in ${project_dir}/.claude/"

  # Copy stack skills
  mkdir -p "${project_dir}/.claude/skills"

  for skill_dir in "${stack_dir}"/*/; do
    [ -d "${skill_dir}" ] || continue
    skill_name="$(basename "${skill_dir}")"
    dest="${project_dir}/.claude/skills/${skill_name}"

    if [ -d "${dest}" ]; then
      echo "    Updating ${skill_name}/"
      rm -rf "${dest}"
    else
      echo "    Adding ${skill_name}/"
    fi
    cp -r "${skill_dir}" "${dest}"
  done

  # Copy extra stack skills (e.g. neo4j-specific from other stacks)
  for extra in "${extras[@]+"${extras[@]}"}"; do
    # Search all stacks for skills matching the extra keyword
    for extra_skill in "${REPO_DIR}"/skills/*/"${extra}"*/; do
      [ -d "${extra_skill}" ] || continue
      skill_name="$(basename "${extra_skill}")"
      dest="${project_dir}/.claude/skills/${skill_name}"

      if [ -d "${dest}" ]; then
        echo "    Updating ${skill_name}/ (extra: ${extra})"
        rm -rf "${dest}"
      else
        echo "    Adding ${skill_name}/ (extra: ${extra})"
      fi
      cp -r "${extra_skill}" "${dest}"
    done
  done

  # Copy stack-specific agents if they exist
  local agents_dir="${REPO_DIR}/agents/${stack}"
  if [ -d "${agents_dir}" ] && [ "$(ls -A "${agents_dir}" 2>/dev/null)" ]; then
    mkdir -p "${project_dir}/.claude/agents"
    for agent_file in "${agents_dir}"/*; do
      [ -f "${agent_file}" ] || continue
      agent_name="$(basename "${agent_file}")"
      echo "    Adding agent: ${agent_name}"
      cp "${agent_file}" "${project_dir}/.claude/agents/${agent_name}"
    done
  fi

  # Merge hooks settings if they exist
  local hooks_file="${REPO_DIR}/hooks/${stack}-settings.json"
  if [ -f "${hooks_file}" ]; then
    local settings_file="${project_dir}/.claude/settings.json"
    if [ -f "${settings_file}" ]; then
      echo "    Note: ${stack}-settings.json exists but settings.json already present — skipping merge"
    else
      echo "    Copying ${stack}-settings.json -> settings.json"
      cp "${hooks_file}" "${settings_file}"
    fi
  fi

  # Copy verify script if it exists
  local verify_file="${REPO_DIR}/verify-scripts/verify-${stack}.sh"
  if [ -f "${verify_file}" ]; then
    mkdir -p "${project_dir}/scripts"
    cp "${verify_file}" "${project_dir}/scripts/verify.sh"
    chmod +x "${project_dir}/scripts/verify.sh"
    echo "    Copied verify-${stack}.sh -> scripts/verify.sh"
  fi

  # Copy guard script if it exists
  local guard_file="${REPO_DIR}/verify-scripts/guard-bash.sh"
  if [ -f "${guard_file}" ]; then
    mkdir -p "${project_dir}/scripts"
    cp "${guard_file}" "${project_dir}/scripts/guard-bash.sh"
    chmod +x "${project_dir}/scripts/guard-bash.sh"
    echo "    Copied guard-bash.sh -> scripts/guard-bash.sh"
  fi

  # Copy agent teams hook scripts if they exist
  for hook_script in task-completed.sh teammate-idle.sh stop-hook.sh; do
    local hook_file="${REPO_DIR}/verify-scripts/${hook_script}"
    if [ -f "${hook_file}" ]; then
      mkdir -p "${project_dir}/scripts"
      cp "${hook_file}" "${project_dir}/scripts/${hook_script}"
      chmod +x "${project_dir}/scripts/${hook_script}"
      echo "    Copied ${hook_script} -> scripts/${hook_script}"
    fi
  done

  # Copy feature-docs/ tree (mirrors repo structure into downstream project)
  local feature_docs_src="${REPO_DIR}/feature-docs"
  if [ -d "${feature_docs_src}" ]; then
    # Create lifecycle directories
    for status_dir in ideation ready testing building review completed; do
      mkdir -p "${project_dir}/feature-docs/${status_dir}"
    done

    # Copy files from repo's feature-docs/ tree (overwrites existing)
    while IFS= read -r src_file; do
      local rel_path="${src_file#"${feature_docs_src}"/}"
      local dest="${project_dir}/feature-docs/${rel_path}"
      local dest_dir
      dest_dir="$(dirname "${dest}")"
      mkdir -p "${dest_dir}"
      if [ -f "${dest}" ]; then
        cp "${src_file}" "${dest}"
        echo "    Updated feature-docs/${rel_path}"
      else
        cp "${src_file}" "${dest}"
        echo "    Added feature-docs/${rel_path}"
      fi
    done < <(find "${feature_docs_src}" -type f)

    echo "    Created feature-docs/ lifecycle directories"
  fi

  echo ""
  echo "Done. Project skills installed:"
  echo "  Skills: $(ls "${project_dir}/.claude/skills/" 2>/dev/null | tr '\n' ' ')"
  [ -d "${project_dir}/.claude/agents" ] && echo "  Agents: $(ls "${project_dir}/.claude/agents/" 2>/dev/null | tr '\n' ' ')"
  echo ""
  echo "Note: Global skills (neo4j-cypher, etc.) are available via ~/.claude/skills/ symlinks."
}

# --- Main ---
if [ $# -eq 0 ]; then
  usage
fi

case "$1" in
  --global)
    install_global
    ;;
  --help|-h)
    usage
    ;;
  *)
    setup_project "$@"
    ;;
esac
