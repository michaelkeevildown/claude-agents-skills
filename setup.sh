#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"

usage() {
  cat <<EOF
Usage:
  ./setup.sh --global                       Install global agents and skills to ~/.claude/
  ./setup.sh <stack> [extra...]             Setup project-local skills for a stack
  ./setup.sh --vendor <target> [options]    Copy the engineering pack into a consumer repo

Stacks: frontend, flutter, python, rust

Vendor options:
  --dry-run    Print what would change; write nothing.
  --force      Proceed even when the target has uncommitted changes under .claude/.

Examples:
  ./setup.sh --global
  ./setup.sh frontend
  ./setup.sh python neo4j          (adds neo4j-specific skills alongside python skills)
  ./setup.sh --vendor ~/code/widget-cli --dry-run
  ./setup.sh --vendor ~/code/widget-cli
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
    echo "Error: Unknown stack '${stack}'. Available: frontend, flutter, python, rust"
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

  # Copy verify scripts if they exist
  local verify_file="${REPO_DIR}/verify-scripts/verify-${stack}.sh"
  if [ -f "${verify_file}" ]; then
    mkdir -p "${project_dir}/scripts"
    cp "${verify_file}" "${project_dir}/scripts/verify.sh"
    chmod +x "${project_dir}/scripts/verify.sh"
    echo "    Copied verify-${stack}.sh -> scripts/verify.sh"
  fi

  # Copy fast-verify script if it exists
  local fast_verify_file="${REPO_DIR}/verify-scripts/fast-verify-${stack}.sh"
  if [ -f "${fast_verify_file}" ]; then
    mkdir -p "${project_dir}/scripts"
    cp "${fast_verify_file}" "${project_dir}/scripts/fast-verify.sh"
    chmod +x "${project_dir}/scripts/fast-verify.sh"
    echo "    Copied fast-verify-${stack}.sh -> scripts/fast-verify.sh"
  fi

  # Copy guard script if it exists
  local guard_file="${REPO_DIR}/verify-scripts/guard-bash.sh"
  if [ -f "${guard_file}" ]; then
    mkdir -p "${project_dir}/scripts"
    cp "${guard_file}" "${project_dir}/scripts/guard-bash.sh"
    chmod +x "${project_dir}/scripts/guard-bash.sh"
    echo "    Copied guard-bash.sh -> scripts/guard-bash.sh"
  fi

  # Copy agent teams hook scripts and utilities if they exist
  for hook_script in task-completed.sh teammate-idle.sh stop-hook.sh next-feature-number.sh lifecycle-stage.sh check-deps.sh; do
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

    # Create agent_logs/ directory for verbose output
    mkdir -p "${project_dir}/agent_logs"
    echo "    Created agent_logs/ directory"

    # Create empty STATUS.md for progress dashboard
    if [ ! -f "${project_dir}/feature-docs/STATUS.md" ]; then
      printf "# Feature Status Dashboard\n\nUpdated by agents after each stage transition.\n" \
        > "${project_dir}/feature-docs/STATUS.md"
      echo "    Created feature-docs/STATUS.md"
    fi

    echo "    Created feature-docs/ lifecycle directories"
  fi

  echo ""
  echo "Done. Project skills installed:"
  echo "  Skills: $(ls "${project_dir}/.claude/skills/" 2>/dev/null | tr '\n' ' ')"
  [ -d "${project_dir}/.claude/agents" ] && echo "  Agents: $(ls "${project_dir}/.claude/agents/" 2>/dev/null | tr '\n' ' ')"
  echo ""
  echo "Note: Global skills (neo4j-cypher, etc.) are available via ~/.claude/skills/ symlinks."
}

# --- Vendor: copy the engineering pack into a consumer repo -------------------------------------
#
# COPIES, never symlinks. The target environment is a box that runs `git clone` + `git reset --hard`
# + `claude -p` with no ~/.claude, so a symlink, a submodule or a plugin is exactly what does not
# survive. A copy in the repo does.
#
# Two properties this mode must never lose:
#   * It copies PER FILE and never removes a directory. A consumer's .claude/skills/ also holds that
#     project's own skills; an `rm -rf` on the target dir would eat them.
#   * It preserves `# override:` declarations in .vendored.lock across a re-vendor, and refuses to
#     overwrite a file declared as an override. Losing an override would silently destroy deliberate
#     local divergence.

PACK_DIR="${REPO_DIR}/skills/engineering"

# DEPENDENCY SKILLS. The pack's skills cite these BY NAME (`create-issue` from /epic and /triage;
# `git-workflow`, `bash-pipefail-safety` and `regression-proof-red-green` from /implement-issue and
# the correctness reviewer). A vendored skill may only depend on something that is also vendored: the
# target box runs `git clone` + `claude -p` with no `~/.claude`, so an unvendored dependency does not
# resolve and the citing skill hard-stops at its own gate.
#
# Each entry is "<path under skills/>:<name the pack cites it by>". The install name is what the
# consumer's directory is called, and it must match the skill's own frontmatter `name:` - which is why
# `global/issue-authoring` lands as `create-issue`.
PACK_DEPS=(
  "global/issue-authoring:create-issue"
  "global/git-workflow:git-workflow"
  "global/bash-pipefail-safety:bash-pipefail-safety"
  "global/regression-proof-red-green:regression-proof-red-green"
)

# sha256 without a pipeline (a pipeline's exit status is a trap under `set -euo pipefail`).
VENDOR_HASHER=""
_pick_hasher() {
  if [ -n "${VENDOR_HASHER}" ]; then return 0; fi
  if command -v shasum >/dev/null 2>&1; then
    VENDOR_HASHER="shasum"
  elif command -v sha256sum >/dev/null 2>&1; then
    VENDOR_HASHER="sha256sum"
  elif command -v openssl >/dev/null 2>&1; then
    VENDOR_HASHER="openssl"
  else
    echo "vendor: no sha256 tool on PATH (shasum / sha256sum / openssl)." >&2
    echo "  The lock cannot be written without one. Hard failure, not a skip." >&2
    exit 2
  fi
}

_sha256() {
  local out
  # Declared then assigned separately: `local x=$(...)` masks the command's exit status.
  case "${VENDOR_HASHER}" in
    shasum)    out="$(shasum -a 256 "$1")" ;;
    sha256sum) out="$(sha256sum "$1")" ;;
    *)         out="$(openssl dgst -sha256 "$1")" ;;   # "SHA256(path)= <hex>"
  esac
  case "${VENDOR_HASHER}" in
    openssl) printf '%s\n' "${out##* }" ;;
    *)       printf '%s\n' "${out%% *}" ;;
  esac
}

# First whitespace-separated word of $1 (deliberate word splitting, no pipeline).
_first_word() {
  # shellcheck disable=SC2086
  set -- $1
  if [ "$#" -ge 1 ]; then printf '%s\n' "$1"; fi
}

# $1 with leading spaces/tabs removed, matching the drift checker's own trimming.
_lstrip() {
  local s="$1"
  while [ -n "$s" ]; do
    case "$s" in
      ' '*)   s="${s# }" ;;
      $'\t'*) s="${s#$'\t'}" ;;
      *)      break ;;
    esac
  done
  printf '%s\n' "$s"
}

# Parallel arrays, because bash 3.2 has no associative arrays.
OV_LINES=()   # verbatim `# override:` lines, preserved across a re-vendor
OV_PATHS=()   # the repo-relative path each one names
EX_PATHS=()   # existing checklist paths
EX_SHAS=()    # their recorded digests

_read_existing_lock() {
  local lock="$1"
  OV_LINES=(); OV_PATHS=(); EX_PATHS=(); EX_SHAS=()
  [ -f "$lock" ] || return 0

  local raw line rest op sha path
  while IFS= read -r raw || [ -n "$raw" ]; do
    line="$(_lstrip "$raw")"
    rest=""
    case "$line" in
      '# override:'*) rest="${line#'# override:'}" ;;
      '#override:'*)  rest="${line#'#override:'}" ;;
    esac
    if [ -n "$rest" ]; then
      op="$(_first_word "$rest")"
      if [ -n "$op" ]; then
        OV_LINES+=("$line")
        OV_PATHS+=("$op")
      fi
      continue
    fi
    case "$line" in
      ''|'#'*) continue ;;
    esac
    sha="${line%%  *}"
    path="${line#*  }"
    if [ "$sha" = "$line" ] || [ -z "$path" ] || [ "$path" = "$line" ]; then
      echo "    warn: dropping malformed lock line: $line"
      continue
    fi
    EX_PATHS+=("$path")
    EX_SHAS+=("$sha")
  done < "$lock"
}

_is_override() {
  local candidate="$1" o
  for o in ${OV_PATHS[@]+"${OV_PATHS[@]}"}; do
    if [ "$o" = "$candidate" ]; then return 0; fi
  done
  return 1
}

# Echo the digest previously recorded for $1, or nothing.
_recorded_sha() {
  local candidate="$1" i=0
  while [ "$i" -lt "${#EX_PATHS[@]}" ]; do
    if [ "${EX_PATHS[$i]}" = "$candidate" ]; then
      printf '%s\n' "${EX_SHAS[$i]}"
      return 0
    fi
    i=$((i + 1))
  done
  return 0
}

# --- the manifest's reviewers declaration -------------------------------------------------------
#
# Agents are vendored ONLY when the consumer's manifest names them. An agent file copied into
# .claude/agents/ is a spawnable agent and reads as a wired-up review gate; installing one that no
# manifest entry references leaves an inert file that lies about the repo's review posture. So the
# rule is: named in the manifest = vendored, not named = not installed and said out loud.
#
# The bindings live in a MARKDOWN TABLE IN THE BODY, not in YAML frontmatter (an `@` import carries
# the prose body only - frontmatter is stripped and never reaches a headless run's context). The scan
# is deliberately shape-tolerant: it collects table rows from any section whose heading mentions
# "reviewer", plus any row of a "bindings" table whose first cell starts with `reviewers`, then asks
# whether a given agent's name appears in what it collected. It never has to agree with the exact
# value syntax, and anything it cannot find is treated as "not declared" - fail safe, install nothing.

MANIFEST_STATE=""            # missing | no-section | declared
MANIFEST_REVIEWERS_TEXT=""   # the candidate table rows, concatenated

# Lowercase $1. printf and tr cannot fail on this input, so the pipeline is safe under pipefail.
_lower() {
  local out
  out="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  printf '%s\n' "$out"
}

# A table cell reduced to a comparable key: no spaces, tabs, backticks or bold markers, lowercased.
_cell_key() {
  local out
  out="$(printf '%s' "$1" | tr -d ' \t`*' | tr '[:upper:]' '[:lower:]')"
  printf '%s\n' "$out"
}

_scan_manifest_reviewers() {
  local manifest="$1"
  MANIFEST_STATE="missing"
  MANIFEST_REVIEWERS_TEXT=""
  [ -f "$manifest" ] || return 0

  MANIFEST_STATE="no-section"
  local raw line low scope="" first in_fence=0
  while IFS= read -r raw || [ -n "$raw" ]; do
    line="$(_lstrip "$raw")"
    case "$line" in
      '```'*|'~~~'*) in_fence=$((1 - in_fence)); continue ;;
    esac
    [ "$in_fence" = "0" ] || continue

    case "$line" in
      '#'*)
        low="$(_lower "$line")"
        scope="other"
        case "$low" in
          *reviewer*) scope="reviewers" ;;
          *binding*)  scope="bindings" ;;
        esac
        continue
        ;;
      '|'*) ;;
      *) continue ;;
    esac

    if [ "$scope" = "reviewers" ]; then
      MANIFEST_STATE="declared"
      MANIFEST_REVIEWERS_TEXT="${MANIFEST_REVIEWERS_TEXT}
${line}"
    elif [ "$scope" = "bindings" ]; then
      first="${line#|}"
      first="${first%%|*}"
      first="$(_cell_key "$first")"
      case "$first" in
        reviewer*)
          MANIFEST_STATE="declared"
          MANIFEST_REVIEWERS_TEXT="${MANIFEST_REVIEWERS_TEXT}
${line}"
          ;;
      esac
    fi
  done < "$manifest"
}

_manifest_names_agent() {
  case "${MANIFEST_REVIEWERS_TEXT}" in
    *"$1"*) return 0 ;;
  esac
  return 1
}

vendor_pack() {
  local target="" dry_run=0 force=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      --force)   force=1; shift ;;
      -h|--help) usage ;;
      -*)
        echo "vendor: unknown option '$1'." >&2
        exit 2
        ;;
      *)
        if [ -n "$target" ]; then
          echo "vendor: one target repo at a time (got '$target' and '$1')." >&2
          exit 2
        fi
        target="$1"; shift
        ;;
    esac
  done

  if [ -z "$target" ]; then
    echo "vendor: needs a target repo path." >&2
    exit 2
  fi
  if [ ! -d "$target" ]; then
    echo "vendor: no such directory: $target" >&2
    exit 2
  fi
  if [ ! -d "${PACK_DIR}" ]; then
    echo "vendor: no engineering pack at ${PACK_DIR}" >&2
    exit 2
  fi

  # Refuse a non-repo. Vendoring writes copies plus a lock, and both only mean something under
  # version control: without git there is no way to review, revert or diff what landed.
  local root
  if ! root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)"; then
    echo "vendor: '$target' is not a git repository." >&2
    echo "  A vendored file is reviewed and reverted through git; refusing to write outside it." >&2
    exit 2
  fi

  # Refuse to run over an in-progress edit under .claude/. A re-vendor overwrites files; without
  # this guard it could silently eat someone's uncommitted work.
  local dirty
  dirty="$(git -C "$root" status --porcelain -- .claude 2>/dev/null || true)"
  if [ -n "$dirty" ] && [ "$force" != "1" ]; then
    echo "vendor: '$root' has uncommitted changes under .claude/:" >&2
    printf '%s\n' "$dirty" >&2
    echo "" >&2
    echo "  A re-vendor overwrites vendored files, so it would eat an in-progress edit." >&2
    echo "  Commit or stash them first, or re-run with --force if you know they are disposable." >&2
    exit 1
  fi
  if [ -n "$dirty" ] && [ "$force" = "1" ]; then
    echo "    warn: --force, proceeding over uncommitted changes under .claude/"
  fi

  _pick_hasher

  local lock_rel=".claude/skills/.vendored.lock"
  local lock="${root}/${lock_rel}"
  _read_existing_lock "$lock"

  # ---- build the plan ---------------------------------------------------------------------------
  local srcs=() rels=() prov_paths=("skills/engineering")
  local skill_dir skill_name agent_file agent_name
  for skill_dir in "${PACK_DIR}"/*/; do
    [ -d "${skill_dir}" ] || continue
    skill_name="$(basename "${skill_dir}")"
    [ "${skill_name}" != "agents" ] || continue
    [ -f "${skill_dir}SKILL.md" ] || continue
    srcs+=("${skill_dir}SKILL.md")
    rels+=(".claude/skills/${skill_name}/SKILL.md")
  done

  # The dependency skills the pack cites by name. Every file under each one rides along, so a
  # dependency that later grows a references/ directory needs no change here.
  local dep_spec dep_src dep_name dep_file dep_rel
  local dep_names=()
  for dep_spec in ${PACK_DEPS[@]+"${PACK_DEPS[@]}"}; do
    dep_src="${REPO_DIR}/skills/${dep_spec%%:*}"
    dep_name="${dep_spec##*:}"
    if [ ! -f "${dep_src}/SKILL.md" ]; then
      echo "vendor: dependency skill '${dep_name}' is missing at ${dep_src}/SKILL.md" >&2
      echo "  The pack cites it by name, so vendoring without it would ship a skill that hard-stops" >&2
      echo "  on the target box. Refusing to write a half pack." >&2
      exit 2
    fi
    prov_paths+=("skills/${dep_spec%%:*}")
    dep_names+=("${dep_name}")
    while IFS= read -r dep_file; do
      dep_rel="${dep_file#"${dep_src}"/}"
      srcs+=("${dep_file}")
      rels+=(".claude/skills/${dep_name}/${dep_rel}")
    done < <(find "${dep_src}" -type f ! -name '.DS_Store')
  done

  # Agents, conditional on the manifest naming them.
  local manifest_rel=".claude/PROJECT.md"
  _scan_manifest_reviewers "${root}/${manifest_rel}"
  local wanted_agents=() skipped_agents=()
  for agent_file in "${PACK_DIR}"/agents/*.md; do
    [ -f "${agent_file}" ] || continue
    agent_name="$(basename "${agent_file}")"
    if _manifest_names_agent "${agent_name%.md}"; then
      srcs+=("${agent_file}")
      rels+=(".claude/agents/${agent_name}")
      wanted_agents+=("${agent_name%.md}")
    else
      skipped_agents+=("${agent_name%.md}")
    fi
  done

  if [ "${#srcs[@]}" -eq 0 ]; then
    echo "vendor: the pack at ${PACK_DIR} holds no SKILL.md or agent files." >&2
    exit 2
  fi

  if [ "$dry_run" = "1" ]; then
    echo "==> DRY RUN. Vendoring engineering pack -> ${root} (nothing will be written)"
  else
    echo "==> Vendoring engineering pack -> ${root}"
  fi
  echo "    source: ${PACK_DIR}"
  echo "    dependency skills: ${dep_names[*]+"${dep_names[*]}"}"

  # ---- say what the manifest bought, and what it did not ------------------------------------------
  case "${MANIFEST_STATE}" in
    declared)
      if [ "${#wanted_agents[@]}" -gt 0 ]; then
        echo "    reviewers declared in ${manifest_rel}: ${wanted_agents[*]}"
      else
        echo "    reviewers: ${manifest_rel} declares none - no agent will be installed."
      fi
      ;;
    missing)
      echo "    reviewers: no ${manifest_rel} in the target - no agent will be installed."
      ;;
    *)
      echo "    reviewers: could not find a reviewers declaration in ${manifest_rel}."
      echo "               The bindings live in a MARKDOWN TABLE in the body; YAML frontmatter is"
      echo "               not read (an @import strips it). No agent will be installed."
      ;;
  esac
  if [ "${#skipped_agents[@]}" -gt 0 ]; then
    local sk
    for sk in ${skipped_agents[@]+"${skipped_agents[@]}"}; do
      echo "    NOT installed (no manifest entry references it): ${sk}"
      if [ -f "${root}/.claude/agents/${sk}.md" ]; then
        echo "      warn: .claude/agents/${sk}.md already exists in the target. Left alone (vendoring"
        echo "            never deletes), but nothing activates it and it drops out of the lock."
      fi
    done
    echo "    To install one, add it to the reviewers table in ${manifest_rel} and re-vendor."
  fi

  # ---- apply ------------------------------------------------------------------------------------
  local out_paths=() out_shas=()
  local i=0 n_add=0 n_update=0 n_same=0 n_override=0
  local src rel dest src_sha dest_sha kept
  while [ "$i" -lt "${#srcs[@]}" ]; do
    src="${srcs[$i]}"
    rel="${rels[$i]}"
    dest="${root}/${rel}"
    i=$((i + 1))

    src_sha="$(_sha256 "$src")"

    if _is_override "$rel"; then
      # Declared divergence: never overwrite, and keep the digest the fork was recorded against.
      kept="$(_recorded_sha "$rel")"
      [ -n "$kept" ] || kept="$src_sha"
      out_paths+=("$rel"); out_shas+=("$kept")
      n_override=$((n_override + 1))
      echo "    override (kept, not overwritten): ${rel}"
      continue
    fi

    if [ -f "$dest" ]; then
      dest_sha="$(_sha256 "$dest")"
      if [ "$dest_sha" = "$src_sha" ]; then
        n_same=$((n_same + 1))
        echo "    unchanged: ${rel}"
      else
        n_update=$((n_update + 1))
        echo "    update:    ${rel}"
      fi
    else
      n_add=$((n_add + 1))
      echo "    add:       ${rel}"
    fi

    if [ "$dry_run" != "1" ]; then
      mkdir -p "$(dirname "$dest")"
      cp "$src" "$dest"
    fi
    out_paths+=("$rel"); out_shas+=("$src_sha")
  done

  # An override may name a path this pack no longer ships (or never did). Keep its checklist line so
  # the declaration stays meaningful.
  local o j found
  for o in ${OV_PATHS[@]+"${OV_PATHS[@]}"}; do
    found=0
    j=0
    while [ "$j" -lt "${#out_paths[@]}" ]; do
      if [ "${out_paths[$j]}" = "$o" ]; then found=1; break; fi
      j=$((j + 1))
    done
    [ "$found" = "0" ] || continue
    kept="$(_recorded_sha "$o")"
    if [ -n "$kept" ]; then
      out_paths+=("$o"); out_shas+=("$kept")
      echo "    override (foreign to this pack, entry preserved): ${o}"
    else
      echo "    warn: override names '$o' with no checklist entry; declaration preserved, no digest"
    fi
  done

  # Anything the old lock listed that is neither shipped nor overridden has left the pack.
  local ep
  i=0
  while [ "$i" -lt "${#EX_PATHS[@]}" ]; do
    ep="${EX_PATHS[$i]}"
    i=$((i + 1))
    found=0
    j=0
    while [ "$j" -lt "${#out_paths[@]}" ]; do
      if [ "${out_paths[$j]}" = "$ep" ]; then found=1; break; fi
      j=$((j + 1))
    done
    [ "$found" = "0" ] || continue
    echo "    dropped from lock (no longer vendored; the file itself is left alone): ${ep}"
  done

  # ---- provenance -------------------------------------------------------------------------------
  local source_repo source_commit pack_dirty vendored_at
  source_repo="$(git -C "${REPO_DIR}" remote get-url origin 2>/dev/null || true)"
  [ -n "$source_repo" ] || source_repo="${REPO_DIR}"
  source_commit="$(git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null || true)"
  [ -n "$source_commit" ] || source_commit="(no commit - not a git checkout)"
  # Dirty means dirty ANYWHERE the vendored bytes come from - the pack and every dependency skill.
  pack_dirty="$(git -C "${REPO_DIR}" status --porcelain -- ${prov_paths[@]+"${prov_paths[@]}"} 2>/dev/null || true)"
  if [ -n "$pack_dirty" ]; then
    source_commit="${source_commit}-dirty"
  fi
  vendored_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [ "$dry_run" = "1" ]; then
    echo ""
    echo "    would write ${lock_rel}:"
    echo "      source_repo:   ${source_repo}"
    echo "      source_commit: ${source_commit}"
    echo "      vendored_at:   <now>"
    echo "      ${#out_paths[@]} checklist entr(ies), ${#OV_LINES[@]} override(s) preserved"
    echo ""
    echo "Dry run complete: ${n_add} add, ${n_update} update, ${n_same} unchanged, ${n_override} override(s) skipped."
    return 0
  fi

  mkdir -p "$(dirname "$lock")"
  {
    cat <<'LOCKHEAD'
# .vendored.lock - integrity lock for VENDORED skill/agent files (sha256).
#
# GENERATED by `setup.sh --vendor` in the shared skills repo. Re-run it to refresh; the only lines
# meant to be hand-edited are the `# override:` declarations, which a re-vendor preserves.
#
# WHY THIS EXISTS
# A vendored skill is a COPY of a file that lives upstream in the shared skills repo. Editing that
# copy in place forks it silently: the next re-vendor overwrites the edit, and the improvement never
# reaches the other repos. The repo's drift checker reads this lock at gate time and catches such an
# in-place edit.
#
# The check is PURELY LOCAL and OFFLINE. It never contacts the network, so it cannot fail open, and
# it never conflates "someone edited this file here" (revert, re-vendor, or declare an override)
# with "upstream has moved on" (a different question, with a different remedy and a different
# urgency).
#
# PROVENANCE HEADER
LOCKHEAD
    printf '# source_repo:   %s\n' "${source_repo}"
    printf '# source_commit: %s\n' "${source_commit}"
    printf '# vendored_at:   %s\n' "${vendored_at}"
    cat <<'LOCKFMT'
#
# FORMAT
# A `shasum -a 256 -c` checklist, so a human can read it and standard tooling can consume it:
#
#     <64 lowercase hex digest><two spaces><repo-relative path>
#
# Rules:
#   * paths are relative to the REPO ROOT, not to this file, and must not contain spaces
#   * digests are lowercase hex, exactly as `shasum -a 256` emits them (uppercase is rejected as
#     malformed rather than silently reported as drift)
#   * blank lines and lines beginning with `#` are ignored by the checker
#
# Record or refresh one entry by hand with:
#
#     shasum -a 256 .claude/skills/<name>/SKILL.md
#
# OVERRIDES
# A file this repo has DELIBERATELY diverged from upstream. Declare it and the drift check skips it,
# so legitimate local divergence is declarable rather than punished:
#
#     # override: <repo-relative path> <free-text reason>
#
# The overridden file KEEPS its checklist line below, recording the upstream digest it forked from,
# and `setup.sh --vendor` will neither overwrite the file nor drop the declaration. One consequence,
# by design: a plain `shasum -a 256 -c` run reports a declared override as FAILED, because the
# recorded digest is deliberately stale. The repo's drift checker is the authoritative check; plain
# `shasum -c` is only a rough eyeball.
#
# ---- overrides ----
LOCKFMT
    if [ "${#OV_LINES[@]}" -eq 0 ]; then
      echo "# (none)"
    else
      local ol
      for ol in ${OV_LINES[@]+"${OV_LINES[@]}"}; do
        printf '%s\n' "$ol"
      done
    fi
    echo "#"
    echo "# ---- vendored files ----"
    local k=0
    while [ "$k" -lt "${#out_paths[@]}" ]; do
      printf '%s  %s\n' "${out_shas[$k]}" "${out_paths[$k]}"
      k=$((k + 1))
    done
  } > "$lock"

  echo ""
  echo "    wrote ${lock_rel} (${#out_paths[@]} entr(ies), ${#OV_LINES[@]} override(s) preserved)"
  echo ""
  echo "Done: ${n_add} add, ${n_update} update, ${n_same} unchanged, ${n_override} override(s) skipped."
  echo "Next:"
  case "${MANIFEST_STATE}" in
    missing)
      echo "  1. Write ${root}/${manifest_rel} and import it from the root CLAUDE.md (@.claude/PROJECT.md)."
      echo "     The bindings go in a '## Bindings' MARKDOWN TABLE in the body, NOT in YAML frontmatter:"
      echo "     the import strips frontmatter, so a binding written there never reaches a headless run."
      ;;
    *)
      echo "  1. Check ${manifest_rel} still binds everything the pack reads (gate.command, labels.*,"
      echo "     branch.*, worktree.*), and that the root CLAUDE.md imports it (@.claude/PROJECT.md)."
      ;;
  esac
  if [ "${#wanted_agents[@]}" -eq 0 ]; then
    echo "     No reviewer agent was installed. Declare the ones you want in the manifest's reviewers"
    echo "     table, then re-vendor to install them."
  fi
  echo "  2. Commit the copies AND the lock together, so the drift check stays green."
  echo "  3. Restart Claude Code if any agent changed - the agent registry loads at BOOT."
  echo "  4. Add this repo to consumers.txt upstream if it is not already there."
}

# --- Main ---
if [ $# -eq 0 ]; then
  usage
fi

case "$1" in
  --global)
    install_global
    ;;
  --vendor)
    shift
    vendor_pack "$@"
    ;;
  --help|-h)
    usage
    ;;
  *)
    setup_project "$@"
    ;;
esac
