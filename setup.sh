#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"

usage() {
  cat <<EOF
Usage:
  ./setup.sh --global                        Install global agents and skills to ~/.claude/
  ./setup.sh <stack> [extra...]              Setup project-local skills for a stack
  ./setup.sh --vendor <target> [options]     Copy the engineering pack into a consumer repo
  ./setup.sh --bootstrap [<target>] [opts]   Set a repo UP for the pack, then vendor it
                                             (target defaults to the current directory)

Stacks: frontend, flutter, python, rust

Vendor / bootstrap options:
  --dry-run    Print what would change; write nothing.
  --force      Proceed even when the target has uncommitted changes under .claude/.

Examples:
  ./setup.sh --global
  ./setup.sh frontend
  ./setup.sh python neo4j          (adds neo4j-specific skills alongside python skills)
  ./setup.sh --vendor ~/code/widget-cli --dry-run
  ./setup.sh --vendor ~/code/widget-cli
  ./setup.sh --bootstrap . --dry-run
  ./setup.sh --bootstrap .
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
# Project-layer scaffold: real template files + a TSV registry, so adding a scaffolded file is a
# markdown edit plus one row rather than a shell edit. See templates/README.md.
TEMPLATES_DIR="${REPO_DIR}/templates"

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
  local target="" dry_run=0 force=0 skip_dirty=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      --force)   force=1; shift ;;
      # INTERNAL, --bootstrap only. Bootstrap runs the very same guard BEFORE it writes its
      # scaffold, so by the time it hands off, the only thing dirty under .claude/ is the manifest
      # and the gate shim bootstrap just created. Re-running the guard here would refuse on
      # bootstrap's own work. Not advertised in usage(): nothing else has the right to skip it.
      --skip-dirty-check) skip_dirty=1; shift ;;
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
  local dirty=""
  if [ "$skip_dirty" != "1" ]; then
    dirty="$(git -C "$root" status --porcelain -- .claude 2>/dev/null || true)"
  fi
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

# --- Bootstrap: set a repo UP for the pack, then vendor it ---------------------------------------
#
# `--vendor` copies the pack in. It does not make a repo READY for it: a vendored skill reads
# `.claude/PROJECT.md` for every label, path and command; the root `CLAUDE.md` has to IMPORT that
# manifest for it to reach a headless run; and `gate.command` has to point at a shim that exists.
# Those three steps were a hand-written checklist, and a checklist is the thing a human forgets.
# This mode does them, reports what it did, then hands off to `--vendor`.
#
# Four properties it must never lose:
#
#   * IDEMPOTENT. Every step is safe to re-run. An existing PROJECT.md, gate.sh or CLAUDE.md import
#     is left EXACTLY as it is and reported as skipped. Bootstrap never edits a file it did not
#     write itself, and never removes anything.
#   * EVIDENCE, NOT GUESSWORK. Every detected value is printed with the evidence it came from, so a
#     wrong guess is visible rather than silent. Anything it cannot detect lands as a loud TODO;
#     nothing is invented to fill a hole.
#   * A SCAFFOLDED GATE NEVER EXITS 0. The worst failure available here is a stub gate that reports
#     green without running anything, because every caller downstream treats 0 as "the tree is
#     proved green". The undetected case therefore exits 2 (COULD NOT RUN) by construction.
#   * IT DOES NOT REIMPLEMENT VENDORING. Step 6 calls `vendor_pack`, so the lock, the override
#     preservation and the per-file copy have exactly one implementation.

# Detection results. Parallel arrays for the summary (bash 3.2 has no associative arrays).
BOOT_KEYS=(); BOOT_VALS=(); BOOT_EVS=()
BOOT_CREATED=(); BOOT_SKIPPED=(); BOOT_TODOS=()

_boot_detected() { BOOT_KEYS+=("$1"); BOOT_VALS+=("$2"); BOOT_EVS+=("$3"); }
_boot_created()  { BOOT_CREATED+=("$1"); }
_boot_skipped()  { BOOT_SKIPPED+=("$1"); }
_boot_todo()     { BOOT_TODOS+=("$1"); }

# $1 with leading AND trailing spaces/tabs removed.
_boot_trim() {
  local s
  s="$(_lstrip "$1")"
  while [ -n "$s" ]; do
    case "$s" in
      *' ')   s="${s% }" ;;
      *$'\t') s="${s%$'\t'}" ;;
      *)      break ;;
    esac
  done
  printf '%s\n' "$s"
}

# First existing path among the arguments. Call it with UNQUOTED globs: an unmatched glob arrives as
# its own literal, which simply fails the -e test.
_boot_first_existing() {
  local p
  for p in "$@"; do
    if [ -e "$p" ]; then printf '%s\n' "$p"; return 0; fi
  done
  return 1
}

# --- fact 1: repo.slug ---------------------------------------------------------------------------
#
# Both remote spellings, plus a deliberate refusal. `git@github.com:owner/repo.git` (scp/SSH) and
# `https://github.com/owner/repo.git` (HTTPS) both reduce to `owner/repo`; a remote that is not
# host-shaped (a bare local path, say) yields NO slug rather than a plausible-looking wrong one,
# because `owner/repo` is what `gh search issues --repo` is handed.

# Sets BOOT_REMOTE_HOST + BOOT_REMOTE_SLUG and returns 0/1, rather than echoing: a `$( )` would run
# it in a SUBSHELL, and the host it parsed (which `tracker` is read off) would never come back.
BOOT_REMOTE_HOST=""
BOOT_REMOTE_SLUG=""
_boot_slug_from_remote() {
  local url="$1" s host path repo rest owner
  BOOT_REMOTE_HOST=""
  BOOT_REMOTE_SLUG=""

  s="${url%.git}"
  s="${s%/}"
  case "$s" in
    *://*)                            # scheme form: https://host[:port]/owner/repo, ssh://git@host/...
      s="${s##*://}"
      s="${s#*@}"
      host="${s%%/*}"; host="${host%%:*}"
      path="${s#*/}"
      ;;
    *@*:*)                            # scp form: git@host:owner/repo
      s="${s#*@}"
      host="${s%%:*}"
      path="${s#*:}"
      ;;
    *:*/*)                            # scp form without a user: host:owner/repo
      host="${s%%:*}"
      path="${s#*:}"
      ;;
    *)
      return 1
      ;;
  esac

  case "$host" in *.*) ;; *) return 1 ;; esac   # host-shaped, or we are not looking at a forge
  case "$path" in */*) ;; *) return 1 ;; esac

  # Keep the LAST two segments, so a nested group path (GitLab) still yields owner/repo.
  repo="${path##*/}"
  rest="${path%/*}"
  case "$rest" in */*) owner="${rest##*/}" ;; *) owner="$rest" ;; esac
  [ -n "$owner" ] && [ -n "$repo" ] || return 1

  BOOT_REMOTE_HOST="$host"
  BOOT_REMOTE_SLUG="${owner}/${repo}"
}

BOOT_SLUG=""; BOOT_SLUG_EV=""; BOOT_TRACKER=""; BOOT_TRACKER_EV=""
_boot_detect_slug() {
  local root="$1" url=""
  BOOT_SLUG=""; BOOT_SLUG_EV=""; BOOT_TRACKER=""; BOOT_TRACKER_EV=""

  url="$(git -C "$root" remote get-url origin 2>/dev/null || true)"
  if [ -z "$url" ]; then
    BOOT_SLUG_EV="no 'origin' remote (git remote get-url origin returned nothing)"
    BOOT_TRACKER_EV="no 'origin' remote, so the tracker cannot be read off the forge host"
    return 0
  fi

  if _boot_slug_from_remote "$url"; then
    BOOT_SLUG="${BOOT_REMOTE_SLUG}"
    BOOT_SLUG_EV="git remote get-url origin -> ${url}"
  else
    BOOT_SLUG=""
    BOOT_SLUG_EV="git remote get-url origin -> ${url} (not owner/repo shaped, so no slug was inferred)"
  fi

  case "${BOOT_REMOTE_HOST}" in
    github.com|*.github.com)
      BOOT_TRACKER="github"
      BOOT_TRACKER_EV="origin host is ${BOOT_REMOTE_HOST}"
      ;;
    "")
      BOOT_TRACKER_EV="origin remote '${url}' names no host"
      ;;
    *)
      BOOT_TRACKER_EV="origin host is ${BOOT_REMOTE_HOST}, which is not GitHub"
      ;;
  esac
}

# --- fact 2: repo.default_branch -----------------------------------------------------------------

BOOT_BRANCH=""; BOOT_BRANCH_EV=""
_boot_detect_default_branch() {
  local root="$1" ref=""
  BOOT_BRANCH=""; BOOT_BRANCH_EV=""

  if ref="$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"; then
    BOOT_BRANCH="${ref#origin/}"
    BOOT_BRANCH_EV="git symbolic-ref refs/remotes/origin/HEAD -> ${ref}"
    return 0
  fi

  local cand
  for cand in main master; do
    if git -C "$root" show-ref --verify --quiet "refs/remotes/origin/${cand}"; then
      BOOT_BRANCH="$cand"
      BOOT_BRANCH_EV="no origin/HEAD; refs/remotes/origin/${cand} exists"
      return 0
    fi
  done
  for cand in main master; do
    if git -C "$root" show-ref --verify --quiet "refs/heads/${cand}"; then
      BOOT_BRANCH="$cand"
      BOOT_BRANCH_EV="no origin/HEAD and no origin/${cand}; local branch ${cand} exists"
      return 0
    fi
  done

  # `symbolic-ref HEAD` (not rev-parse) so a repo with no commit yet still answers.
  if ref="$(git -C "$root" symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
    BOOT_BRANCH="$ref"
    BOOT_BRANCH_EV="last resort: the branch currently checked out (git symbolic-ref HEAD)"
    return 0
  fi
  BOOT_BRANCH_EV="no origin/HEAD, no main/master, and HEAD is detached"
}

# --- fact 3: gate.command ------------------------------------------------------------------------
#
# THE important one, and the one where a wrong answer is dangerous rather than untidy. The failure
# that matters here is NOT "no gate detected" - it is a gate that RETURNS GREEN ON A BROKEN TREE,
# because every caller downstream reads a 0 as proof the tree is green. A detector that returns
# nothing is therefore strictly better than one that returns a command which can pass on a broken
# tree, and every rule below is written that way round.
#
# PRECEDENCE (first match wins):
#
#   1. `.claude/scripts/gate.sh` already exists     -> already wired; bootstrap does not look inside
#   2a. a workflow CI definition (the repo's OWN answer) -> the UNION of every required job's commands
#   2b. a host-build declaration (netlify.toml, vercel.json) -> the build the host runs on every push
#   3. `scripts/verify.sh`                          -> bash scripts/verify.sh
#   4. `package.json` scripts                       -> verify > check > ci > test:ci > test (+ lint)
#   5. `Makefile`                                   -> make check, else make test
#   6. `Cargo.toml`                                 -> cargo fmt --check && clippy && test
#   7. `pyproject.toml`                             -> ruff (when configured) + pytest
#   8. `pubspec.yaml`                               -> dart analyze + flutter/dart test
#   9. `.claude/settings.json` Stop hook            -> whatever verify-ish command it already names
#
# Rule 2 is first among the guesses because it is not a guess. `.github/workflows/*.yml`,
# `.gitlab-ci.yml`, `.circleci/config.yml`, `netlify.toml` and `vercel.json` are the repo WRITING
# DOWN what it means by green, and that beats any inference from a manifest. Rules 4-8 read what the
# repo is BUILT with, never what it is CHECKED with, and that gap is exactly how a heuristic ships a
# false green: a Next.js repo whose CI compiles the project gets `npm run lint && npm run test` from
# a package.json scan, which never compiles anything, so a TypeScript type error walks straight
# through a gate reporting 0.
#
# Rule 2 is a UNION, never a pick. A workflow with `verify` and `migrations` jobs has TWO required
# checks; replaying only the first certifies exactly the tree the second exists to reject. And a job
# that could not be read is reported as a TODO naming it, because "the repo's own CI is its own
# answer" is a lie when only half of it was read.
#
# Whatever rule fires, the answer then goes through four post-checks before it is allowed out:
#
#   A. WATCH-MODE GUARD. A command that never exits is a hang, not a gate. A watch/dev-server
#      delegate is swapped for its non-watch variant, or thrown away.
#   B. COMPLETENESS CHECK. The delegate is resolved (package scripts expanded, repo-local `.sh`
#      bodies and Makefile recipes read) and compared against the checks the repo EVIDENTLY HAS. A
#      repo with a `tsconfig.json` MUST compile inside its gate; a repo that PRODUCES A BUILD
#      ARTEFACT (a `build` script plus a framework config) MUST build inside it, because a gate that
#      type-checks but never builds is not a gate for a site that has to build. Missing legs are
#      composed on where that can be done safely, and where it cannot the whole delegate is
#      DOWNGRADED to a TODO with a loud reason. An incomplete gate is never shipped quietly.
#   C. EXIT-2 WARNING. A repo-local delegate script with a bare `exit 2` collides with the pack's
#      COULD NOT RUN code. The direction is safe (a red reads as unproved, never as green) so the
#      code is left alone, but the collision is surfaced in the summary and in PROJECT.md.
#   D. TSC EXIT-2 NORMALISATION. `tsc --noEmit` exits 2 (DiagnosticsPresent_OutputsGenerated) on a
#      COLD incremental run and 1 when the `*.tsbuildinfo` cache is warm - and that file is
#      gitignored, so COLD is the default state of a fresh clone or worktree. For tsc a 2 means
#      DIAGNOSTICS, i.e. RED, so any leg bootstrap KNOWS is tsc gets its 2 remapped to 1 in the
#      generated shim. Only legs bootstrap resolved to tsc itself: a third-party delegate's 2 is
#      never touched, because for `scripts/verify.sh` a 2 may genuinely mean could-not-run.
#
# Files first, the settings hook last: a file IS the gate, whereas a hook merely mentions one and may
# well name a fast/partial check. Nothing matches -> NO command. It never invents one.

BOOT_GATE_STATE="none"   # existing | detected | none
BOOT_GATE=""             # the delegate command line
BOOT_GATE_EV=""          # which rule matched, and on what
BOOT_GATE_WARNS=()       # loud notes: repeated in the summary AND written into PROJECT.md
BOOT_GATE_REJECTED=""    # a delegate the post-checks threw away (named so the refusal is auditable)
BOOT_GATE_EXIT2=""       # repo-local delegate script(s) carrying a bare `exit 2`
BOOT_GATE_PKG_WHY=""     # why a package.json script was passed over, for the no-rule-matched note

_boot_gate_warn() { BOOT_GATE_WARNS+=("$1"); }

# The `"scripts": { ... }` object of a package.json, and nothing else. The sed range gets the
# pretty-printed case; truncating at the FIRST `}` gets the minified single-line case, where the
# range runs to EOF and would otherwise drag devDependencies in with it (a `"verify"` DEPENDENCY
# read as a `verify` SCRIPT is exactly the silent wrong answer this mode exists to avoid).
_boot_pkg_scripts_block() {
  local block
  block="$(sed -n '/"scripts"[[:space:]]*:[[:space:]]*{/,/^[[:space:]]*}/p' "$1" 2>/dev/null || true)"
  printf '%s\n' "${block%%\}*}"
}

# Does a `"scripts": { ... }` block name key $2?
_boot_block_has_key() {
  if printf '%s\n' "$1" | grep -qE "\"$2\"[[:space:]]*:"; then return 0; fi
  return 1
}

# The VALUE of script $2 in scripts block $1, i.e. what `npm run $2` actually runs. Needed because
# every post-check below reasons about the command that ends up executing, not the alias for it.
_boot_pkg_script_value() {
  local block="$1" name="$2" line
  line="$(printf '%s\n' "$block" | grep -E "\"${name}\"[[:space:]]*:" | head -n1 || true)"
  [ -n "$line" ] || return 1
  line="${line#*\"${name}\"}"
  line="${line#*:}"
  line="$(_boot_trim "$line")"
  line="${line%,}"
  line="$(_boot_trim "$line")"
  case "$line" in \"*) line="${line#\"}" ;; *) return 1 ;; esac
  # End the value at its own closing quote, not at the end of the line: a `"scripts": { ... }` object
  # written on ONE line would otherwise hand back every script after this one as part of this one's
  # value, and a stray `dev` dragged into a `build` value makes the watch guard refuse a gate that
  # never had a watch command in it. The first alternative eats escaped quotes so a value containing
  # \" survives intact; `.*` after the closing quote is what gets dropped.
  line="$(printf '%s' "$line" | sed -E 's/(([^\\"]|\\.)*)".*/\1/')"
  [ -n "$line" ] || return 1
  printf '%s\n' "$line"
}

# --- the CI readers (rule 2) ---------------------------------------------------------------------
#
# bash 3.2 with no yq, so this is a targeted line scan rather than a YAML parse, and it is written to
# BAIL rather than half-parse: anything it cannot read confidently is reported, never guessed at.
# Shared awk prelude, one main body per flavour.
#
# THE GATE IS THE UNION OF THE REQUIRED JOBS, NOT ONE OF THEM. A workflow with a `verify` job and a
# `migrations` job has TWO required checks, and a shim that replays only the first certifies as green
# exactly the tree the second job exists to reject. So every job that (a) belongs to a workflow that
# runs on push/PR, (b) is not named as a deploy/release/notify step, and (c) could be read, goes into
# the delegate, commands de-duplicated and in workflow order.
#
# A job that could NOT be read is never silently discarded: it comes back as a SKIP with its reason,
# and the caller turns that into a loud TODO naming the job. "The repo's own CI is its own answer" is
# only true if all of it was read, so when it was not, the operator is told which half was missed.
#
# A job that needs something a laptop does not have (a service container, a live database) still gets
# read: the infrastructure command comes back as a PREREQUISITE rather than a gate leg, and the
# ordinary commands around it - typically the standalone script the job actually asserts with - stay
# in the gate. That is how `migrations`' `./scripts/check-schema-sync.sh` lands in the delegate while
# its `supabase db push` is reported as a prerequisite instead of being pretended into coverage.

_boot_ci_awk_common() {
  cat <<'AWKCOMMON'
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

# Steps that set the machine up, ship something, or talk to a service. None of them is evidence of a
# green tree, and dropping them is safe in the only direction that matters: it can never turn a red
# tree green, it just keeps `npm ci` out of a local gate.
function skippable(c,   l) {
  l = tolower(c)
  if (l ~ /^(npm|yarn|pnpm|bun)[ \t]+(ci|install|i|add)([ \t]|$)/) return 1
  if (l ~ /^(pip|pip3)[ \t]+install/) return 1
  if (l ~ /^python[0-9.]*[ \t]+-m[ \t]+pip[ \t]+install/) return 1
  if (l ~ /^(poetry|pipenv)[ \t]+install/) return 1
  if (l ~ /^uv[ \t]+(sync|venv|pip)/) return 1
  if (l ~ /^bundle[ \t]+install/) return 1
  if (l ~ /^go[ \t]+mod[ \t]+(download|tidy)/) return 1
  if (l ~ /^cargo[ \t]+(fetch|install)/) return 1
  if (l ~ /^(rustup|nvm|corepack|asdf|mise|pyenv)([ \t]|$)/) return 1
  if (l ~ /^(sudo|apt|apt-get|yum|apk|brew|choco|winget)([ \t]|$)/) return 1
  if (l ~ /^docker([ \t]+(login|push|pull|build|tag|compose))?([ \t]|$)/) return 1
  if (l ~ /^(gh|aws|az|gcloud|kubectl|helm|terraform|flyctl|vercel|netlify|fastlane)([ \t]|$)/) return 1
  if (l ~ /^(echo|printf|cd|export|source|set|ls|cat|pwd|env|mkdir|cp|mv|rm|chmod|touch|sleep|true|exit)([ \t]|$)/) return 1
  if (l ~ /^git[ \t]+(config|clone|fetch|checkout|remote|submodule|status|rev-parse)/) return 1
  if (l ~ /^(curl|wget)([ \t]|$)/) return 1
  if (l ~ /(deploy|publish|release|notify|slack|codecov|coveralls|upload|artifact|changeset|semantic-release)/) return 1
  if (l ~ /^(flutter|dart)[ \t]+pub[ \t]+get/) return 1
  if (l ~ /^(npm|yarn|pnpm|bun)[ \t]+(run[ \t]+)?(dev|start|serve|preview)([ \t]|$)/) return 1
  return 0
}

# Something we would have to interpret to reproduce. Interpreting it is how a half-parsed command
# ends up in a gate, so a hazard poisons the whole job and the rule falls through instead.
function hazard(c,   l) {
  if (c ~ /\$\{\{/) return "a ${{ ... }} expression the gate cannot expand"
  if (c ~ /<</) return "a heredoc"
  if (c ~ /\\$/) return "a line continuation"
  if (c ~ /^[({})]/) return "shell block syntax"
  l = tolower(c)
  if (l ~ /^(if|for|while|until|case|then|else|elif|fi|done|esac|do|function)([ \t]|$)/) return "shell control flow"
  return ""
}

# A command that cannot run on a laptop because it needs a service the laptop has not got: a live
# database, a compose stack, a migration engine pointed at a real server. Unlike skippable() this is
# NOT dropped quietly - it comes back as a PREREQUISITE, because a job whose set-up needs a database
# is a job the local gate only partly covers, and the operator has to be told which part.
function prereq_reason(c,   l) {
  l = tolower(c)
  if (l ~ /^(supabase|psql|pg_dump|pg_restore|pg_isready|createdb|dropdb|mysql|mysqladmin|redis-cli|mongo|mongosh|sqlcmd|clickhouse-client)([ \t]|$)/) return "needs a live database"
  if (l ~ /^(alembic|prisma|sqlx|knex|flyway|liquibase|dbmate|goose|atlas|sequelize|migrate)([ \t]|$)/) return "needs a live database"
  if (l ~ /^(bundle[ \t]+exec[ \t]+)?(rails|rake)[ \t]+db:/) return "needs a live database"
  if (l ~ /^(python[0-9.]*[ \t]+)?(\.\/)?manage\.py[ \t]+migrate/) return "needs a live database"
  if (l ~ /^docker[ \t]+compose[ \t]+(up|start|run)([ \t]|$)/) return "needs a docker service"
  if (l ~ /^docker-compose[ \t]+(up|start|run)([ \t]|$)/) return "needs a docker service"
  return ""
}

# A command that is nothing but an invocation of a repo-local shell script, with no shell syntax
# around it. That is the one thing worth RESCUING out of a job the reader otherwise cannot replay:
# a job whose set-up is a heredoc against a database, but whose actual assertion is
# `./scripts/check-schema-sync.sh`, still has a check a laptop can run. Returns the script path so
# the caller can confirm the file is really in the repo before putting it in a gate.
function standalone(c,   t) {
  if (c ~ /[;&|><$`(){}]/) return ""
  t = c
  sub(/^(bash|sh)[ \t]+/, "", t)
  sub(/[ \t].*$/, "", t)
  if (t ~ /\.sh$/) return t
  return ""
}

function record(c,   h, p) {
  if (cur == "") return
  c = trim(c)
  if (c == "") return
  if (substr(c, 1, 1) == "#") return
  p = prereq_reason(c)
  if (p != "") {
    svc[cur] = 1
    pcnt[cur]++
    prq[cur, pcnt[cur]] = c " (" p ")"
    return
  }
  if (skippable(c)) return
  h = hazard(c)
  if (h != "") { amb[cur] = h; return }
  cnt[cur]++
  cmds[cur, cnt[cur]] = c
  if (standalone(c) != "") { rcnt[cur]++; resc[cur, rcnt[cur]] = c }
}

# Setup actions carry no assertion, so a job made only of them has nothing to replay and proves
# nothing either way. Any OTHER `uses:` might BE the whole check (a composite action that runs the
# suite), and a job like that must never be dropped in silence.
function boring_action(u,   l) {
  l = tolower(u)
  if (l ~ /^actions\/(checkout|setup-|cache|upload-artifact|download-artifact|configure-pages)/) return 1
  if (l ~ /^(pnpm|oven-sh|denoland|ruby|subosito|dtolnay|swatinem|astral-sh|actions-rs|actions-rust-lang|google-github-actions)\//) return 1
  return 0
}

# A job whose NAME says it ships, announces or reports rather than proves the tree green. Excluded on
# purpose and reported as DROPPED rather than as a TODO: replaying `deploy` locally is not a gate,
# it is an outage. Deliberately narrow - anything not obviously in this class is read as required.
function notgate(j,   l) {
  l = tolower(j)
  if (l ~ /(deploy|release|publish|promote|preview|rollback|notify|slack|discord|comment|label|stale|announce|changeset|semantic|codeql|scorecard|dependabot|benchmark|coverage-report|upload)/) return 1
  return 0
}

# The standalone scripts of a job that is otherwise unreadable. Offered, not taken: the caller only
# keeps the ones whose file actually exists in the repo, and the job stays reported as skipped.
function rescue(j,   k) {
  for (k = 1; k <= rcnt[j]; k++) printf "RESC\t%s\t%s\n", j, resc[j, k]
}

END {
  # A workflow that never runs on push or a pull request is not the repo's answer to "is this tree
  # green" - it is a button or a cron. Only judged when the triggers were actually readable.
  if (trigseen && !trigok) {
    printf "NONE\tit runs on %s, never on push or pull_request, so it is not a green-tree check\n", (triglist == "" ? "no readable trigger" : trim(triglist))
    exit
  }

  emitted = 0
  for (i = 1; i <= nj; i++) {
    j = order[i]
    if (notgate(j)) { printf "DROP\t%s\tthe job name says it ships or reports rather than proves the tree green\n", j; continue }
    if (j in wd)     { printf "SKIP\t%s\tit runs in a sub-directory (working-directory:), which a repo-root shim cannot replay\n", j; continue }
    if (j in amb)    { printf "SKIP\t%s\tits steps contain %s\n", j, amb[j]; rescue(j); continue }
    if (cnt[j] > 15) { printf "SKIP\t%s\tit runs %d commands, far more than a gate plausibly is\n", j, cnt[j]; rescue(j); continue }
    if (cnt[j] < 1) {
      if (j in realuses)   printf "SKIP\t%s\tevery step is an action (%s), so there is no command to replay\n", j, realuses[j]
      else if (pcnt[j] > 0) printf "SKIP\t%s\teverything it runs needs a service this shim has not got\n", j
      else                  printf "DROP\t%s\tit runs no commands of its own\n", j
      continue
    }
    printf "JOB\t%s\t%s\n", j, ((j in svc) ? "needs-a-service" : "plain")
    for (k = 1; k <= cnt[j]; k++) printf "CMD\t%s\t%s\n", j, cmds[j, k]
    for (k = 1; k <= pcnt[j]; k++) printf "PRQ\t%s\t%s\n", j, prq[j, k]
    emitted++
  }
  if (emitted == 0) printf "NONE\tno job in this file runs a command a repo-root shim can replay\n"
}
AWKCOMMON
}

# GitHub Actions and CircleCI: `jobs:` at column 0, job names at indent 2, commands under `run:` (GH)
# or `run:`/`command:` (CircleCI), single-line or a `|` block.
_boot_ci_awk_steps() {
  _boot_ci_awk_common
  cat <<'AWKSTEPS'
BEGIN { injobs = 0; cur = ""; nj = 0; inblock = 0; blockind = 0; inon = 0; trigseen = 0; trigok = 0; triglist = "" }

# `on:` (or the YAML-1.1-safe `"on":`) - the workflow's triggers. Inline scalar, inline flow list and
# the nested-map spelling all appear in the wild, so all three are read. Unreadable = not judged.
function note_trigger(t) {
  t = trim(t)
  gsub(/["']/, "", t)
  if (t == "") return
  trigseen = 1
  if (t == "push" || t == "pull_request" || t == "pull_request_target" || t == "merge_group") trigok = 1
  triglist = triglist " " t
}
{
  line = $0
  sub(/\r$/, "", line)

  if (inblock) {
    if (line ~ /^[ \t]*$/) next
    ind = match(line, /[^ ]/) - 1
    if (ind > blockind) { record(substr(line, ind + 1)); next }
    inblock = 0
  }

  if (line ~ /^[ \t]*#/) next
  if (line ~ /^[ \t]*$/) next

  if (line ~ /^["']?on["']?:[ \t]*$/) { inon = 1; injobs = 0; cur = ""; next }
  if (line ~ /^["']?on["']?:[ \t]*\[/) {
    t = line
    sub(/^[^\[]*\[/, "", t)
    sub(/\].*$/, "", t)
    n = split(t, parts, ",")
    for (q = 1; q <= n; q++) note_trigger(parts[q])
    inon = 0
    next
  }
  if (line ~ /^["']?on["']?:[ \t]*[^ \t]/) {
    t = line
    sub(/^[^:]*:[ \t]*/, "", t)
    sub(/[ \t]*#.*$/, "", t)
    note_trigger(t)
    inon = 0
    next
  }
  if (inon) {
    if (line ~ /^[^ \t]/) { inon = 0 }
    else if (line ~ /^  -[ \t]*[A-Za-z_]/) { t = line; sub(/^[ \t]*-[ \t]*/, "", t); sub(/[ \t]*#.*$/, "", t); note_trigger(t); next }
    else if (line ~ /^  [A-Za-z_]+:/) { t = line; sub(/:.*$/, "", t); note_trigger(t); next }
    else next
  }

  if (line ~ /^jobs:[ \t]*$/) { injobs = 1; cur = ""; next }
  if (injobs && line ~ /^[^ \t]/) { injobs = 0; cur = "" }
  if (!injobs) next

  if (line ~ /^  [A-Za-z0-9_.-]+:[ \t]*(#.*)?$/) {
    cur = line
    sub(/^  /, "", cur)
    sub(/:.*$/, "", cur)
    if (!(cur in seen)) { seen[cur] = 1; nj++; order[nj] = cur; cnt[cur] = 0 }
    next
  }
  if (cur == "") next

  # A step that runs somewhere other than the repo root cannot be replayed by a root-level shim.
  if (line ~ /working[_-]directory:/) { wd[cur] = 1; next }

  # A `services:` block is the job saying out loud that it needs a container to be up. The job is
  # still read; its infrastructure is reported as a prerequisite rather than pretended into the gate.
  if (line ~ /^[ \t]+services:[ \t]*$/) {
    svc[cur] = 1
    pcnt[cur]++
    prq[cur, pcnt[cur]] = "a services: container (the job declares one, so its checks need it running)"
    next
  }

  # A step that IS an action rather than a command. Setup actions prove nothing and are ignored; any
  # other action might be the whole assertion, so it is remembered and reported if the job ends up
  # with nothing replayable.
  if (line ~ /^[ \t]*(-[ \t]+)?uses:[ \t]*[^ \t]/) {
    u = trim(substr(line, index(line, "uses:") + 5))
    gsub(/["']/, "", u)
    if (!boring_action(u)) realuses[cur] = realuses[cur] (realuses[cur] == "" ? "" : ", ") u
    next
  }

  if (line ~ /^[ \t]*(-[ \t]+)?(run|command):[ \t]*[|>][-+0-9]*[ \t]*(#.*)?$/) {
    blockind = match(line, /(run|command):/) - 1
    inblock = 1
    next
  }
  if (line ~ /^[ \t]*(-[ \t]+)?(run|command):[ \t]*[^ \t]/) {
    p = match(line, /(run|command):/)
    c = trim(substr(line, p + RLENGTH))
    if (c ~ /^".*"$/) c = substr(c, 2, length(c) - 2)
    else if (c ~ /^'.*'$/) c = substr(c, 2, length(c) - 2)
    record(c)
    next
  }
}
AWKSTEPS
}

# GitLab CI: jobs are top-level keys, commands live in a `script:` list.
_boot_ci_awk_gitlab() {
  _boot_ci_awk_common
  cat <<'AWKGITLAB'
BEGIN { cur = ""; nj = 0; inscript = 0; trigseen = 0; trigok = 0; triglist = "" }
function reserved(k) {
  return (k == "stages" || k == "variables" || k == "default" || k == "include" || \
          k == "workflow" || k == "image" || k == "services" || k == "cache" || \
          k == "before_script" || k == "after_script" || k == "script" || k == "pages" || \
          k == "types" || k == "retry" || k == "interruptible")
}
{
  line = $0
  sub(/\r$/, "", line)
  if (line ~ /^[ \t]*#/) next
  if (line ~ /^[ \t]*$/) next

  if (line ~ /^[A-Za-z0-9_.]/) {
    k = trim(line)
    sub(/:.*$/, "", k)
    inscript = 0
    if (reserved(tolower(k)) || substr(k, 1, 1) == ".") { cur = "" }
    else {
      cur = k
      if (!(cur in seen)) { seen[cur] = 1; nj++; order[nj] = cur; cnt[cur] = 0 }
    }
    next
  }
  if (cur == "") next

  # Same reading as the GitHub `services:` block: the job says out loud that it needs a container.
  if (line ~ /^[ \t]+services:[ \t]*/) {
    svc[cur] = 1
    pcnt[cur]++
    prq[cur, pcnt[cur]] = "a services: container (the job declares one, so its checks need it running)"
    inscript = 0
    next
  }

  if (line ~ /^[ \t]+script:[ \t]*$/) { inscript = 1; next }
  if (line ~ /^[ \t]+script:[ \t]*[^ \t]/) {
    record(trim(substr(line, index(line, "script:") + 7)))
    inscript = 0
    next
  }
  if (line ~ /^[ \t]+[A-Za-z_]+:/) { inscript = 0; next }
  if (inscript && line ~ /^[ \t]*-[ \t]*[^ \t]/) {
    c = line
    sub(/^[ \t]*-[ \t]*/, "", c)
    c = trim(c)
    if (c ~ /^".*"$/) c = substr(c, 2, length(c) - 2)
    else if (c ~ /^'.*'$/) c = substr(c, 2, length(c) - 2)
    record(c)
    next
  }
}
AWKGITLAB
}

# `<rank>\t<file>\t<flavour>`, best-looking CI definition first. Workflows whose NAME says they are
# not a gate (deploy, release, codeql, ...) are dropped outright: reading a deploy job for a gate is
# how you end up with `vercel deploy` as your proof of green.
_boot_ci_candidates() {
  local root="$1" f base l rank
  {
    for f in "${root}"/.github/workflows/*.yml "${root}"/.github/workflows/*.yaml; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      l="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
      case "$l" in
        *deploy*|*release*|*publish*|*codeql*|*scorecard*|*stale*|*label*|*dependabot*|*pages*|*docs*|*docker*|*cron*|*schedul*|*sync*|*greet*|*triage*)
          continue ;;
      esac
      case "$l" in
        ci.y*)                                  rank=1 ;;
        *ci*|*verify*|*check*|*quality*|*gate*) rank=2 ;;
        *test*)                                 rank=3 ;;
        *build*)                                rank=4 ;;
        *lint*)                                 rank=5 ;;
        *main*|*pr*|*pull*)                     rank=6 ;;
        *)                                      rank=9 ;;
      esac
      printf '%s\t%s\tsteps\n' "$rank" "$f"
    done
    if [ -f "${root}/.circleci/config.yml" ]; then printf '2\t%s\tsteps\n' "${root}/.circleci/config.yml"; fi
    if [ -f "${root}/.gitlab-ci.yml" ]; then printf '2\t%s\tgitlab\n' "${root}/.gitlab-ci.yml"; fi
  } | sort -n -k1,1 | cut -f2-
}

BOOT_GATE_CI_FILE=""; BOOT_GATE_CI_JOBS=""; BOOT_GATE_CI_WHY=""
BOOT_GATE_CI_SKIPPED=""   # `job (why)` list: required-looking jobs that could NOT be read -> a TODO
BOOT_GATE_CI_DROPPED=""   # `job (why)` list: jobs deliberately excluded (ship/report, not a check)
BOOT_GATE_CI_PREREQ=""    # `job: command (why)` list: what the gate does NOT cover locally
BOOT_GATE_CI_RESCUED=""   # `job: command` list: the standalone script salvaged from a skipped job

# Rule 2a: the repo's own workflow CI, read as the UNION of its required jobs.
_boot_gate_from_ci() {
  local root="$1" file flavour prog out
  local tag a b composed seen jobs skipped dropped prereq why n rpath rescued
  BOOT_GATE_CI_FILE=""; BOOT_GATE_CI_JOBS=""; BOOT_GATE_CI_WHY=""
  BOOT_GATE_CI_SKIPPED=""; BOOT_GATE_CI_DROPPED=""; BOOT_GATE_CI_PREREQ=""; BOOT_GATE_CI_RESCUED=""

  while IFS=$'\t' read -r file flavour; do
    [ -n "${file:-}" ] || continue
    case "$flavour" in
      gitlab) prog="$(_boot_ci_awk_gitlab)" ;;
      *)      prog="$(_boot_ci_awk_steps)" ;;
    esac
    out="$(awk "$prog" "$file" 2>/dev/null || true)"

    composed=""; seen=""; jobs=""; skipped=""; dropped=""; prereq=""; why=""; rescued=""; n=0
    while IFS=$'\t' read -r tag a b; do
      case "${tag:-}" in
        JOB)  jobs="${jobs}${jobs:+, }${a}" ;;
        RESC)
          # A standalone script salvaged from a job that could not be read as a whole. Taken ONLY if
          # the file is really there - a path that does not resolve would put a 127 in the gate and
          # turn a red tree into a could-not-run.
          rpath="${b#bash }"; rpath="${rpath#sh }"; rpath="${rpath%% *}"
          if [ -f "${root}/${rpath#./}" ] && ! printf '%s\n' "$seen" | grep -Fxq -- "$b"; then
            seen="${seen}
${b}"
            composed="${composed}${composed:+ && }${b}"
            rescued="${rescued}${rescued:+, }${a}: ${b}"
            n=$((n + 1))
          fi
          ;;
        CMD)
          # De-duplicate identical commands across jobs (a matrix, or two jobs that both lint) while
          # keeping the order they were declared in. `grep -Fxq` on a newline-joined list is the
          # bash-3.2 stand-in for the associative array this would otherwise be.
          if ! printf '%s\n' "$seen" | grep -Fxq -- "$b"; then
            seen="${seen}
${b}"
            composed="${composed}${composed:+ && }${b}"
            n=$((n + 1))
          fi
          ;;
        PRQ)  prereq="${prereq}${prereq:+; }${a}: ${b}" ;;
        SKIP) skipped="${skipped}${skipped:+; }${a} (${b})" ;;
        DROP) dropped="${dropped}${dropped:+; }${a} (${b})" ;;
        NONE) why="${a}" ;;
      esac
    done <<CIEOF
${out}
CIEOF

    if [ "$n" -lt 1 ]; then
      if [ -z "$BOOT_GATE_CI_WHY" ]; then
        BOOT_GATE_CI_WHY="${file#"${root}"/}: ${why:-${skipped:-no readable job}}"
      fi
      continue
    fi

    BOOT_GATE_CI_FILE="${file#"${root}"/}"
    BOOT_GATE_CI_JOBS="$jobs"
    BOOT_GATE_CI_SKIPPED="$skipped"
    BOOT_GATE_CI_DROPPED="$dropped"
    BOOT_GATE_CI_PREREQ="$prereq"
    BOOT_GATE_CI_RESCUED="$rescued"
    BOOT_GATE="$composed"
    return 0
  done <<CANDEOF
$(_boot_ci_candidates "$root")
CANDEOF
  return 1
}

# --- rule 2b: host-build CI ----------------------------------------------------------------------
#
# A repo with no .github/workflows has not necessarily got no CI. A static site on Netlify or Vercel
# declares its build IN THE REPO (`netlify.toml`, `vercel.json`) and the host runs it on every push:
# that build IS the repo's pass/fail check, and a tree that fails it produces no deployable site. So
# a host-build declaration is read as CI - it is the repo writing down what it means by green just as
# much as a workflow is - rather than falling through to a package.json guess that never builds.

# `command = "..."` inside netlify.toml's `[build]` table (and only that table: `[build.environment]`
# is a different thing and its keys must not be read as the build command).
_boot_netlify_build() {
  awk '
    BEGIN { inb = 0 }
    /^[ \t]*\[/ { inb = ($0 ~ /^[ \t]*\[build\][ \t]*$/) ? 1 : 0; next }
    inb && /^[ \t]*(command|base)[ \t]*=/ {
      key = $0; sub(/[ \t]*=.*$/, "", key); gsub(/[ \t]/, "", key)
      v = $0
      sub(/^[ \t]*[A-Za-z_]+[ \t]*=[ \t]*/, "", v)
      sub(/[ \t]*$/, "", v)
      if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
      else if (v ~ /^'"'"'.*'"'"'$/) v = substr(v, 2, length(v) - 2)
      if (v != "") printf "%s\t%s\n", toupper(key), v
    }
  ' "$1" 2>/dev/null || true
}

_boot_gate_from_hostbuild() {
  local root="$1" out cmd base block
  BOOT_GATE_CI_FILE=""; BOOT_GATE_CI_JOBS=""
  BOOT_GATE_CI_SKIPPED=""; BOOT_GATE_CI_DROPPED=""; BOOT_GATE_CI_PREREQ=""; BOOT_GATE_CI_RESCUED=""

  block=""
  [ -f "${root}/package.json" ] && block="$(_boot_pkg_scripts_block "${root}/package.json")"

  if [ -f "${root}/netlify.toml" ]; then
    out="$(_boot_netlify_build "${root}/netlify.toml")"
    cmd="$(printf '%s\n' "$out" | awk -F'\t' '$1 == "COMMAND" { print $2; exit }' || true)"
    base="$(printf '%s\n' "$out" | awk -F'\t' '$1 == "BASE" { print $2; exit }' || true)"
    if [ -n "$cmd" ]; then
      BOOT_GATE_CI_FILE="netlify.toml"
      BOOT_GATE_CI_JOBS="[build] command"
      case "$base" in
        ""|"."|"./") ;;
        *) BOOT_GATE_CI_PREREQ="netlify.toml declares base = \"${base}\", so the host builds from that sub-directory and this shim runs the command at the repo root" ;;
      esac
      BOOT_GATE="$cmd"
      return 0
    fi
  fi

  if [ -f "${root}/vercel.json" ]; then
    cmd="$(grep -oE '"buildCommand"[[:space:]]*:[[:space:]]*"[^"]*"' "${root}/vercel.json" 2>/dev/null | head -n1 || true)"
    if [ -n "$cmd" ]; then
      cmd="${cmd#*:}"
      cmd="$(_boot_trim "$cmd")"
      cmd="${cmd#\"}"; cmd="${cmd%\"}"
    fi
    if [ -z "$cmd" ] && [ -n "$block" ] && _boot_block_has_key "$block" build; then
      # No explicit buildCommand means Vercel runs the framework default, which for every JS
      # framework it detects is the package.json `build` script.
      cmd="npm run build"
      BOOT_GATE_CI_JOBS="framework-default build (no explicit buildCommand)"
    else
      BOOT_GATE_CI_JOBS="buildCommand"
    fi
    if [ -n "$cmd" ]; then
      BOOT_GATE_CI_FILE="vercel.json"
      BOOT_GATE="$cmd"
      return 0
    fi
  fi

  return 1
}

# --- resolving a delegate (what the post-checks reason about) -------------------------------------
#
# `npm run verify` says nothing on its own. Expand it: package scripts (recursively, bounded), the
# body of any repo-local `.sh` it names, and the recipe of any make target it names. The result is a
# blob of everything the delegate ultimately runs, which is what completeness and the watch guard
# have to judge - judging the alias instead is how `npm run verify` passes for a compile step it
# never performs.
_boot_gate_resolved() {
  local root="$1" cmd="$2" depth="$3" block names name val tok path targets target

  printf '%s\n' "$cmd"
  [ "$depth" -ge 3 ] && return 0

  if [ -f "${root}/package.json" ]; then
    block="$(_boot_pkg_scripts_block "${root}/package.json")"
    names="$(printf '%s\n' "$cmd" \
      | grep -oE '(npm|yarn|pnpm|bun)[[:space:]]+(run[[:space:]]+)?[A-Za-z0-9:_.-]+' \
      | awk '{ print $NF }' | sort -u || true)"
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      case "$name" in run|npm|yarn|pnpm|bun) continue ;; esac
      if val="$(_boot_pkg_script_value "$block" "$name")"; then
        _boot_gate_resolved "$root" "$val" "$((depth + 1))"
      fi
    done <<PKGEOF
${names}
PKGEOF
  fi

  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    path="${root}/${tok#./}"
    if [ -f "$path" ]; then cat "$path"; fi
  done <<SHEOF
$(printf '%s\n' "$cmd" | grep -oE '[A-Za-z0-9_./-]+\.(sh|bash)' | sort -u || true)
SHEOF

  if [ -f "${root}/Makefile" ]; then
    targets="$(printf '%s\n' "$cmd" | grep -oE 'make[[:space:]]+[A-Za-z0-9_.-]+' | awk '{ print $NF }' | sort -u || true)"
    while IFS= read -r target; do
      [ -n "$target" ] || continue
      awk -v t="$target" '
        $0 ~ "^" t "[ \t]*:" { inr = 1; next }
        inr && /^\t/ { print; next }
        inr && /^[^\t]/ { inr = 0 }
      ' "${root}/Makefile" 2>/dev/null || true
    done <<MKEOF
${targets}
MKEOF
  fi
}

# --- post-check A: the watch-mode guard -----------------------------------------------------------
#
# A gate that never exits is a hang, not a gate: the caller waits forever and no verdict is ever
# reached. Prints the reason and returns 0 when $2 looks interactive.
_boot_watch_reason() {
  local root="$1" c cfg
  c="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
  # The explicit "not watching" spellings must not trip the substring tests below.
  c="${c//--watchman/ }"
  c="${c//--no-watchman/ }"
  c="${c//--watchall=false/ }"
  c="${c//--watch=false/ }"
  c="${c//--no-watch/ }"
  c="${c//--watch false/ }"

  case " ${c} " in
    *--watchall*)     printf -- '--watchAll never exits\n'; return 0 ;;
    *--watch*)        printf -- '--watch never exits\n'; return 0 ;;
    *nodemon*)        printf 'nodemon re-runs on every change and never exits\n'; return 0 ;;
    *"cargo watch"*)  printf 'cargo watch never exits\n'; return 0 ;;
    *pytest-watch*|*" ptw "*) printf 'pytest-watch never exits\n'; return 0 ;;
    *"next dev"*|*"nuxt dev"*|*"vite dev"*|*"astro dev"*|*"ng serve"*|*"webpack serve"*|*"npm start"*|*"npm run dev"*|*"yarn dev"*|*"pnpm dev"*)
      printf 'it starts a dev server, which never exits\n'; return 0 ;;
  esac

  if printf '%s' "$c" | grep -qE '(^|[;&|[:space:]])vitest([[:space:]]|$)'; then
    if ! printf '%s' "$c" | grep -qE 'vitest[[:space:]]+(run|related|bench)([[:space:]]|$)' \
      && ! printf '%s' "$c" | grep -qE 'vitest[^;&|]*--run([[:space:]]|$)'; then
      printf 'bare `vitest` defaults to watch mode and never exits\n'
      return 0
    fi
  fi
  if printf '%s' "$c" | grep -qE '(^|[;&|[:space:]])vite([[:space:]]|$)'; then
    # `vite build` and `vite optimize` run once and exit. Only the bare invocation (and `vite
    # preview`, which serves) is the dev server. Getting this wrong refuses a perfectly good build
    # leg, and defect 2's whole point is that a site's gate must contain its build.
    if ! printf '%s' "$c" | grep -qE 'vite[[:space:]]+(build|optimize|--version)([[:space:]]|$)'; then
      printf 'bare `vite` starts the dev server and never exits\n'
      return 0
    fi
  fi
  if printf '%s' "$c" | grep -qE '(^|[;&|[:space:]])jest([[:space:]]|$)'; then
    if cfg="$(_boot_first_existing "${root}"/jest.config.js "${root}"/jest.config.ts "${root}"/jest.config.cjs "${root}"/jest.config.mjs "${root}"/jest.config.json)"; then
      if grep -qE '"?watch(All)?"?[[:space:]]*:[[:space:]]*true' "$cfg"; then
        printf 'jest is run bare and %s sets watch: true, so it never exits\n' "$(basename "$cfg")"
        return 0
      fi
    fi
  fi
  return 1
}

_boot_gate_guard_watch() {
  local root="$1" blob reason fixed

  blob="$(_boot_gate_resolved "$root" "${BOOT_GATE}" 0)"
  reason="$(_boot_watch_reason "$root" "$blob" || true)"
  [ -n "$reason" ] || return 0

  # The one rewrite that is safe without reading anything: `vitest` -> `vitest run` is the documented
  # non-watch spelling of the same command.
  if printf '%s' "${BOOT_GATE}" | grep -qE '(^|[;&|[:space:]])vitest([[:space:]]|$)'; then
    fixed="$(printf '%s' "${BOOT_GATE}" | sed -E 's/(^|[;&| ])vitest($|[ ])/\1vitest run\2/g')"
    if [ -z "$(_boot_watch_reason "$root" "$(_boot_gate_resolved "$root" "$fixed" 0)" || true)" ]; then
      _boot_gate_warn "the detected delegate was watch-mode (${reason%$'\n'}); it was rewritten to the non-watch spelling \`${fixed}\`."
      BOOT_GATE="$fixed"
      return 0
    fi
  fi

  BOOT_GATE_REJECTED="${BOOT_GATE}"
  BOOT_GATE_STATE="none"
  BOOT_GATE=""
  BOOT_GATE_EV="REFUSED \`${BOOT_GATE_REJECTED}\` (${BOOT_GATE_EV}): ${reason%$'\n'}. A gate that never exits is a hang, not a gate, and no non-watch variant could be found, so nothing is wired."
  _boot_gate_warn "REFUSED the detected delegate \`${BOOT_GATE_REJECTED}\` because ${reason%$'\n'}. Wire a non-watch command (a \`test:ci\` script, \`--run\`, \`--watch=false\`) into .claude/scripts/gate.sh."
  return 0
}

# --- post-check B: the completeness check ---------------------------------------------------------
#
# The fix for the false green. Whatever produced the delegate, it now has to cover the checks this
# repo EVIDENTLY HAS. A tsconfig.json means the repo compiles, so its gate must compile: a lint+test
# pair that never invokes the compiler certifies a type-error tree as green, and 0 is read as proof
# everywhere downstream. Missing legs are composed on where that is safe; where it is not, the whole
# delegate is thrown away in favour of a TODO, because no gate beats a lying gate.

# Does the resolved blob $1 actually typecheck? `vite build`, `tsup` and friends STRIP types rather
# than check them, so they deliberately do not count.
_boot_blob_typechecks() {
  printf '%s\n' "$1" | grep -qE '(^|[^a-z-])(tsc|vue-tsc|svelte-check)([^a-z-]|$)|type-?check|astro[[:space:]]+check|deno[[:space:]]+check|(next|nuxt)[[:space:]]+build'
}
# Does the resolved blob $1 actually BUILD? Separate from typechecking on purpose: `astro check` and
# `tsc --noEmit` prove the types and produce nothing, so neither of them proves the site still
# builds, and for a repo whose whole output is a build artefact that is the check that matters.
_boot_blob_builds() {
  printf '%s\n' "$1" | grep -qE '(^|[^a-z-])(astro|next|nuxt|vite|gatsby|remix|ng|parcel|rollup|webpack|tsup|esbuild|svelte-kit|expo|turbo)[[:space:]]+build|(npm|yarn|pnpm|bun)[[:space:]]+(run[[:space:]]+)?build([[:space:]]|$)|make[[:space:]]+build([[:space:]]|$)|cargo[[:space:]]+build|go[[:space:]]+build|tsc[[:space:]]+(-b|--build)([[:space:]]|$)'
}

# Does this repo produce a build artefact? Both halves are required, so this is evidence rather than
# a guess: a `build` script says the repo is built, and a framework config says what it is built
# INTO. A site that has to build and a gate that never builds it is the false green all over again -
# `npm run check` (astro check) reports 0 on a tree whose build has been broken for weeks.
_boot_repo_builds_artefact() {
  local root="$1" block="$2"
  [ -n "$block" ] || return 1
  _boot_block_has_key "$block" build || return 1
  if _boot_first_existing "${root}"/astro.config.* "${root}"/next.config.* "${root}"/nuxt.config.* \
    "${root}"/svelte.config.* "${root}"/vite.config.* "${root}"/remix.config.* \
    "${root}"/gatsby-config.* "${root}"/angular.json "${root}"/rollup.config.* \
    "${root}"/webpack.config.* >/dev/null; then
    return 0
  fi
  return 1
}

_boot_blob_lints() {
  printf '%s\n' "$1" | grep -qiE 'lint|eslint|biome|ruff|clippy|rubocop|golangci|flake8|black[[:space:]]+--check|stylelint|dart[[:space:]]+analyze'
}
_boot_blob_tests() {
  printf '%s\n' "$1" | grep -qiE '(^|[^a-z-])(test|tests|jest|vitest|mocha|pytest|karma|playwright|cypress|rspec|phpunit|ava)([^a-z-]|$)'
}

_boot_gate_complete() {
  local root="$1" block blob missing="" name script ext
  block=""
  [ -f "${root}/package.json" ] && block="$(_boot_pkg_scripts_block "${root}/package.json")"
  blob="$(_boot_gate_resolved "$root" "${BOOT_GATE}" 0)"

  # -- compile. The one the false green came through.
  if [ -f "${root}/tsconfig.json" ] && ! _boot_blob_typechecks "$blob"; then
    ext=""
    # `check` sits late but before `build`: it is the Astro/Svelte convention for the type checker
    # (`astro check`, `svelte-check`), and taking the repo's own checker beats composing `npx tsc`
    # onto a project whose types are only correct under the framework's checker. Every candidate is
    # confirmed to actually typecheck before it is accepted, so a `check` that is really a linter
    # is passed over rather than trusted.
    for name in typecheck type-check tsc types check-types check build; do
      if [ -n "$block" ] && _boot_block_has_key "$block" "$name"; then
        script="$(_boot_pkg_script_value "$block" "$name" || true)"
        if [ -n "$script" ] && _boot_blob_typechecks "$(_boot_gate_resolved "$root" "npm run ${name}" 0)"; then
          ext="npm run ${name}"
          break
        fi
      fi
    done
    if [ -z "$ext" ] && [ -f "${root}/package.json" ] && grep -q '"typescript"' "${root}/package.json"; then
      # `--no-install` so a missing compiler exits 127, which the shim maps to COULD NOT RUN. It can
      # never silently succeed, which is the only property that matters here.
      ext="npx --no-install tsc --noEmit"
    fi
    if [ -n "$ext" ]; then
      BOOT_GATE="${BOOT_GATE} && ${ext}"
      blob="$(_boot_gate_resolved "$root" "${BOOT_GATE}" 0)"
      _boot_gate_warn "the detected command never compiled the project even though tsconfig.json says this repo is TypeScript, so \`${ext}\` was composed onto it. Without that leg the gate reports GREEN on a tree that does not compile."
    else
      missing="a compile/typecheck step (tsconfig.json exists, so a type error is a red tree)"
    fi
  fi

  # -- build. A site that has to build must build inside its gate. Composable whenever it applies,
  # because `_boot_repo_builds_artefact` already required the `build` script to exist.
  if [ -z "$missing" ] && _boot_repo_builds_artefact "$root" "$block" && ! _boot_blob_builds "$blob"; then
    ext="npm run build"
    BOOT_GATE="${BOOT_GATE} && ${ext}"
    blob="$(_boot_gate_resolved "$root" "${BOOT_GATE}" 0)"
    _boot_gate_warn "the detected command never BUILT the project even though this repo has a \`build\` script and a framework config, so \`${ext}\` was composed onto it. A gate that type-checks but never builds reports GREEN on a tree that produces no deployable output."
  fi

  # -- tests. Only on strong evidence a test runner is actually configured here.
  if [ -z "$missing" ] && _boot_repo_has_tests "$root" "$block" && ! _boot_blob_tests "$blob"; then
    ext=""
    for name in test:ci test test:unit; do
      if [ -n "$block" ] && _boot_block_has_key "$block" "$name"; then
        script="$(_boot_pkg_script_value "$block" "$name" || true)"
        if [ -n "$script" ] && ! _boot_watch_reason "$root" "$script" >/dev/null; then
          ext="npm run ${name}"
          break
        fi
      fi
    done
    if [ -n "$ext" ]; then
      BOOT_GATE="${BOOT_GATE} && ${ext}"
      blob="$(_boot_gate_resolved "$root" "${BOOT_GATE}" 0)"
      _boot_gate_warn "the detected command ran no tests even though this repo configures a test runner, so \`${ext}\` was composed onto it."
    else
      missing="a test step (this repo configures a test runner, so a failing test is a red tree)"
    fi
  fi

  # -- lint. Weaker: a missing linter does not certify a broken tree green, so it warns, never blocks.
  if [ -z "$missing" ] && _boot_repo_has_lint "$root" "$block" && ! _boot_blob_lints "$blob"; then
    ext=""
    for name in lint lint:ci lint:all; do
      if [ -n "$block" ] && _boot_block_has_key "$block" "$name"; then ext="npm run ${name}"; break; fi
    done
    if [ -n "$ext" ]; then
      BOOT_GATE="${BOOT_GATE} && ${ext}"
      _boot_gate_warn "the detected command ran no linter even though this repo configures one, so \`${ext}\` was composed onto it."
    else
      _boot_gate_warn "this repo configures a linter but the detected gate never runs it, and no lint script was available to compose on. The gate is weaker than the repo's own standard - add the lint leg by hand."
    fi
  fi

  [ -z "$missing" ] && return 0

  BOOT_GATE_REJECTED="${BOOT_GATE}"
  BOOT_GATE_STATE="none"
  BOOT_GATE=""
  BOOT_GATE_EV="REFUSED \`${BOOT_GATE_REJECTED}\` (${BOOT_GATE_EV}): it is MISSING ${missing}, and no safe way to compose that leg on was available."
  _boot_gate_warn "REFUSED the detected delegate \`${BOOT_GATE_REJECTED}\`: it is MISSING ${missing}. Shipping it would have CERTIFIED A RED TREE AS GREEN, so no gate is wired and .claude/scripts/gate.sh exits 2 until you write the real one."
  return 0
}

_boot_repo_has_tests() {
  local root="$1" block="$2"
  if [ -n "$block" ]; then
    if _boot_block_has_key "$block" test || _boot_block_has_key "$block" "test:ci"; then return 0; fi
  fi
  if _boot_first_existing "${root}"/jest.config.* "${root}"/vitest.config.* "${root}"/vitest.workspace.* \
    "${root}"/playwright.config.* "${root}"/cypress.config.* "${root}"/karma.conf.* "${root}"/pytest.ini \
    "${root}"/phpunit.xml >/dev/null; then
    return 0
  fi
  if [ -f "${root}/pyproject.toml" ] && grep -q 'pytest' "${root}/pyproject.toml"; then return 0; fi
  return 1
}

_boot_repo_has_lint() {
  local root="$1" block="$2"
  if [ -n "$block" ]; then
    if _boot_block_has_key "$block" lint; then return 0; fi
  fi
  if _boot_first_existing "${root}"/.eslintrc "${root}"/.eslintrc.* "${root}"/eslint.config.* \
    "${root}"/biome.json "${root}"/.rubocop.yml "${root}"/.golangci.yml "${root}"/.golangci.yaml \
    "${root}"/.flake8 "${root}"/ruff.toml "${root}"/.ruff.toml "${root}"/.stylelintrc \
    "${root}"/.stylelintrc.* >/dev/null; then
    return 0
  fi
  if [ -f "${root}/pyproject.toml" ] && grep -q 'ruff' "${root}/pyproject.toml"; then return 0; fi
  return 1
}

# --- post-check C: the exit-2 collision -----------------------------------------------------------
#
# 2 is the pack's COULD NOT RUN code. A repo-local delegate that uses `exit 2` for an ordinary
# failure therefore reports RED as UNPROVED. That direction is SAFE (it is never read as green), so
# the code is deliberately not remapped - it is just made visible, here and in PROJECT.md.
_boot_gate_check_exit2() {
  local root="$1" blob tok path hits=""

  blob="$(_boot_gate_resolved "$root" "${BOOT_GATE}" 0)"
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    path="${root}/${tok#./}"
    [ -f "$path" ] || continue
    # Comment lines stripped first: a script that merely DOCUMENTS the exit-2 contract is not a
    # script that USES 2 for an ordinary failure, and warning about the former is noise.
    if grep -vE '^[[:space:]]*#' "$path" | grep -qE '(^|[[:space:];&(])exit[[:space:]]+2[[:space:]]*($|[;&)])'; then
      hits="${hits}${hits:+, }${tok}"
    fi
  done <<EXITEOF
$(printf '%s\n' "$blob" | grep -oE '[A-Za-z0-9_./-]+\.(sh|bash)' | sort -u || true)
EXITEOF

  [ -n "$hits" ] || return 0
  BOOT_GATE_EXIT2="$hits"
  _boot_gate_warn "the delegate script(s) ${hits} contain a bare \`exit 2\`, and 2 is this pack's COULD NOT RUN code - so THIS DELEGATE REPORTS RED AS COULD NOT RUN. The code is left alone because that direction is safe (a failure is never read as green), but read a 2 from this gate as 'it may simply have failed'."
  return 0
}

# --- post-check D: the tsc exit-2 collision -------------------------------------------------------
#
# `tsc --noEmit` does NOT have one failure code. Its ExitStatus enum returns 1
# (DiagnosticsPresent_OutputsSkipped) when nothing was emitted and 2
# (DiagnosticsPresent_OutputsGenerated) when it had already written output - which is what happens on
# a COLD run of a project with `"incremental": true`, because writing the `.tsbuildinfo` counts as
# generating output. That file is gitignored in every repo that has one, so COLD IS THE DEFAULT STATE
# of a fresh clone, a fresh worktree and a CI runner - exactly where builds actually happen.
#
# Both codes mean the same thing: DIAGNOSTICS WERE PRESENT. That is RED. But 2 is this pack's COULD
# NOT RUN code, so without this remap an ordinary type error arrives as "nothing was proved" on every
# first run and as "the tree is red" on every subsequent one. Same defect, two verdicts, decided by a
# cache file.
#
# So: legs bootstrap can SEE are tsc get their 2 remapped to 1 in the generated shim. Only those.
# A third-party delegate (`bash scripts/verify.sh`, `make check`) keeps its 2 untouched, because
# there a 2 may genuinely mean could-not-run and post-check C's warning is the right answer instead.

BOOT_GATE_TSC_LEGS=()   # the exact legs of BOOT_GATE the shim wraps in the 2 -> 1 remap

# The `&&`-separated legs of $1, one per line. Splitting and re-joining on " && " is an identity, so
# a leg that itself contains `&&` is safe: it is only ever wrapped when it matches a tsc leg exactly.
_boot_gate_legs() {
  local rest="$1" leg
  while [ -n "$rest" ]; do
    case "$rest" in
      *" && "*) leg="${rest%%" && "*}"; rest="${rest#*" && "}" ;;
      *)        leg="$rest"; rest="" ;;
    esac
    printf '%s\n' "$leg"
  done
}

# TRUE only when every command this leg ultimately runs is tsc (or vue-tsc). An alias line - the
# `npm run typecheck` that points at it - does not count against that, since npm exits with the
# script's own code. Anything else at all (a second command, a shell operator, a script body) makes
# this false, which is the safe direction: an unremapped 2 is read as could-not-run, never as green.
_boot_leg_is_tsc() {
  local root="$1" leg="$2" blob line saw=0
  blob="$(_boot_gate_resolved "$root" "$leg" 0)"
  while IFS= read -r line; do
    line="$(_boot_trim "$line")"
    [ -n "$line" ] || continue
    case "$line" in \#*) continue ;; esac
    case "$line" in *"&&"*|*"||"*|*";"*|*"|"*) return 1 ;; esac
    if printf '%s' "$line" | grep -qE '^(npm|yarn|pnpm|bun)[[:space:]]+(run[[:space:]]+)?[A-Za-z0-9:_.-]+[[:space:]]*$'; then
      continue
    fi
    if printf '%s' "$line" | grep -qE '^(npx[[:space:]]+(--no-install[[:space:]]+)?)?(tsc|vue-tsc)([[:space:]]|$)'; then
      saw=1
      continue
    fi
    return 1
  done <<TSCEOF
${blob}
TSCEOF
  [ "$saw" = "1" ]
}

_boot_gate_mark_tsc() {
  local root="$1" leg hits=""
  BOOT_GATE_TSC_LEGS=()
  while IFS= read -r leg; do
    [ -n "$leg" ] || continue
    if _boot_leg_is_tsc "$root" "$leg"; then
      BOOT_GATE_TSC_LEGS+=("$leg")
      hits="${hits}${hits:+, }\`${leg}\`"
    fi
  done <<LEGEOF
$(_boot_gate_legs "${BOOT_GATE}")
LEGEOF

  [ -n "$hits" ] || return 0
  _boot_gate_warn "the leg(s) ${hits} are tsc, and tsc exits 2 (not 1) whenever it has already written a \`.tsbuildinfo\` - which is what a COLD run of an incremental project does, i.e. every fresh clone and worktree. 2 is this pack's COULD NOT RUN code, so the shim REMAPS those legs' 2 to 1 (RED). No other leg's exit code is touched."
  return 0
}

# --- the detector ---------------------------------------------------------------------------------

_boot_detect_gate() {
  local root="$1"
  BOOT_GATE_STATE="none"; BOOT_GATE=""; BOOT_GATE_EV=""
  BOOT_GATE_WARNS=(); BOOT_GATE_REJECTED=""; BOOT_GATE_EXIT2=""; BOOT_GATE_PKG_WHY=""
  BOOT_GATE_TSC_LEGS=()

  # Rule 1
  if [ -f "${root}/.claude/scripts/gate.sh" ]; then
    BOOT_GATE_STATE="existing"
    BOOT_GATE_EV="rule 1: .claude/scripts/gate.sh already exists - it owns the delegate, left alone"
    return 0
  fi

  _boot_gate_pick "$root"

  # The post-checks, in order. Each may extend, replace or throw the delegate away, so every one of
  # them re-reads the state rather than assuming the previous one left it detected.
  if [ "${BOOT_GATE_STATE}" = "detected" ]; then _boot_gate_guard_watch "$root"; fi
  if [ "${BOOT_GATE_STATE}" = "detected" ]; then _boot_gate_complete "$root"; fi
  if [ "${BOOT_GATE_STATE}" = "detected" ]; then _boot_gate_check_exit2 "$root"; fi
  if [ "${BOOT_GATE_STATE}" = "detected" ]; then _boot_gate_mark_tsc "$root"; fi
}

# Rules 2-9. Sets BOOT_GATE_STATE/BOOT_GATE/BOOT_GATE_EV and nothing else; the post-checks are the
# caller's job, so every rule can be read as "what does this evidence say" on its own.
_boot_gate_pick() {
  local root="$1"

  # Rule 2a: the repo's own workflow CI, as the UNION of its required jobs. Not a guess - the repo
  # wrote down what it means by green. The claim "the repo's own CI is its own answer" is only made
  # for the jobs actually read, and anything skipped is named here and carried into PROJECT.md.
  if _boot_gate_from_ci "$root"; then
    BOOT_GATE_STATE="detected"
    BOOT_GATE_EV="rule 2a: ${BOOT_GATE_CI_FILE} job(s) ${BOOT_GATE_CI_JOBS} - the repo's own CI is its own answer to 'is this tree green'"
    if [ -n "${BOOT_GATE_CI_DROPPED}" ]; then
      BOOT_GATE_EV="${BOOT_GATE_EV}; not read as checks: ${BOOT_GATE_CI_DROPPED}"
    fi
    if [ -n "${BOOT_GATE_CI_RESCUED}" ]; then
      BOOT_GATE_EV="${BOOT_GATE_EV}; salvaged from an unreadable job: ${BOOT_GATE_CI_RESCUED}"
    fi
    if [ -n "${BOOT_GATE_CI_SKIPPED}" ]; then
      BOOT_GATE_EV="${BOOT_GATE_EV}; NOT FULLY COVERED: ${BOOT_GATE_CI_SKIPPED}"
      _boot_gate_warn "ONLY PART OF THE CI WAS READ. ${BOOT_GATE_CI_FILE} declares job(s) this shim could not replay in full: ${BOOT_GATE_CI_SKIPPED}. The gate covers ${BOOT_GATE_CI_JOBS}${BOOT_GATE_CI_RESCUED:+ plus the standalone script(s) ${BOOT_GATE_CI_RESCUED}}, and NOTHING else those jobs assert - so a green from it is NOT the same verdict as the repo's own CI. Add the missing check(s) to .claude/scripts/gate.sh by hand, or accept that CI can still reject a tree this gate calls green."
    fi
    if [ -n "${BOOT_GATE_CI_PREREQ}" ]; then
      _boot_gate_warn "PREREQUISITES THIS GATE DOES NOT SET UP: ${BOOT_GATE_CI_PREREQ}. Those commands were kept OUT of the delegate because they need a service a laptop has not got; the ordinary commands of the same job(s) are in. If a leg fails because the service is not up, that is a could-not-run wearing a red coat - start the service and re-run before believing the failure."
    fi
    return 0
  fi

  # Rule 2b: a host-build declaration. No workflows does not mean no CI: for a site on Netlify or
  # Vercel the build in netlify.toml / vercel.json IS the check every push is judged by.
  if _boot_gate_from_hostbuild "$root"; then
    BOOT_GATE_STATE="detected"
    BOOT_GATE_EV="rule 2b: ${BOOT_GATE_CI_FILE} ${BOOT_GATE_CI_JOBS} - the host builds this repo on every push, so a tree that fails this build fails CI and ships nothing"
    if [ -n "${BOOT_GATE_CI_PREREQ}" ]; then
      _boot_gate_warn "${BOOT_GATE_CI_PREREQ}. Check the command is the right one to run from the root before trusting a green."
    fi
    return 0
  fi

  # Rule 3
  if [ -f "${root}/scripts/verify.sh" ]; then
    BOOT_GATE_STATE="detected"
    BOOT_GATE="bash scripts/verify.sh"
    BOOT_GATE_EV="rule 3: scripts/verify.sh exists"
    return 0
  fi

  # Rule 4. Preference order is deliberate: a CI-INTENDED script beats a developer-convenience one,
  # so `test:ci` (coverage ratchet, --watch=false, whatever the repo added on purpose) wins over
  # `test`. A watch-mode script is passed over here rather than picked and rejected later.
  if [ -f "${root}/package.json" ]; then
    local block name val skipped="" lint_name="" test_name=""
    block="$(_boot_pkg_scripts_block "${root}/package.json")"

    for name in verify check ci; do
      if _boot_block_has_key "$block" "$name"; then
        val="$(_boot_pkg_script_value "$block" "$name" || true)"
        if [ -n "$val" ] && _boot_watch_reason "$root" "$val" >/dev/null; then
          skipped="${skipped}${skipped:+, }${name}"
          continue
        fi
        BOOT_GATE_STATE="detected"
        BOOT_GATE="npm run ${name}"
        BOOT_GATE_EV="rule 4: package.json declares scripts.${name} (the CI-intended script, preferred over test/lint)"
        [ -n "$skipped" ] && _boot_gate_warn "package.json script(s) ${skipped} were passed over: they are watch-mode and would never exit."
        return 0
      fi
    done

    for name in test:ci test:coverage test:unit test; do
      if _boot_block_has_key "$block" "$name"; then
        val="$(_boot_pkg_script_value "$block" "$name" || true)"
        if [ -n "$val" ] && _boot_watch_reason "$root" "$val" >/dev/null; then
          skipped="${skipped}${skipped:+, }${name}"
          continue
        fi
        test_name="$name"
        break
      fi
    done
    for name in lint lint:ci lint:all; do
      if _boot_block_has_key "$block" "$name"; then lint_name="$name"; break; fi
    done
    if [ -n "$skipped" ]; then
      _boot_gate_warn "package.json script(s) ${skipped} were passed over: they are watch-mode and would never exit."
      BOOT_GATE_PKG_WHY="package.json script(s) ${skipped} exist but are watch-mode, so they were passed over"
    fi

    if [ -n "$lint_name" ] && [ -n "$test_name" ]; then
      BOOT_GATE_STATE="detected"
      BOOT_GATE="npm run ${lint_name} && npm run ${test_name}"
      BOOT_GATE_EV="rule 4: package.json has no verify/check/ci script, composed from scripts.${lint_name} + scripts.${test_name}"
      return 0
    fi
    if [ -n "$test_name" ]; then
      BOOT_GATE_STATE="detected"
      BOOT_GATE="npm run ${test_name}"
      BOOT_GATE_EV="rule 4: package.json declares scripts.${test_name} only (no lint leg)"
      return 0
    fi
    if [ -n "$lint_name" ]; then
      BOOT_GATE_STATE="detected"
      BOOT_GATE="npm run ${lint_name}"
      BOOT_GATE_EV="rule 4: package.json declares scripts.${lint_name} only (NO test leg - a lint-only gate proves little)"
      return 0
    fi
  fi

  # Rule 5
  if [ -f "${root}/Makefile" ]; then
    local target
    for target in check test; do
      if grep -qE "^${target}[[:space:]]*:" "${root}/Makefile"; then
        BOOT_GATE_STATE="detected"
        BOOT_GATE="make ${target}"
        BOOT_GATE_EV="rule 5: Makefile declares a '${target}' target"
        return 0
      fi
    done
  fi

  # Rule 6
  if [ -f "${root}/Cargo.toml" ]; then
    BOOT_GATE_STATE="detected"
    BOOT_GATE="cargo fmt --check && cargo clippy --all-targets -- -D warnings && cargo test"
    BOOT_GATE_EV="rule 6: Cargo.toml exists (the standard Rust three-leg gate)"
    return 0
  fi

  # Rule 7
  if [ -f "${root}/pyproject.toml" ]; then
    local pfx="" runner_ev="no lockfile, so no runner prefix"
    if [ -f "${root}/uv.lock" ]; then
      pfx="uv run "; runner_ev="uv.lock present, so the legs run under uv"
    elif [ -f "${root}/poetry.lock" ]; then
      pfx="poetry run "; runner_ev="poetry.lock present, so the legs run under poetry"
    fi
    BOOT_GATE_STATE="detected"
    if grep -q "ruff" "${root}/pyproject.toml"; then
      BOOT_GATE="${pfx}ruff check . && ${pfx}pytest -q"
      BOOT_GATE_EV="rule 7: pyproject.toml mentions ruff; ${runner_ev}"
    else
      BOOT_GATE="${pfx}pytest -q"
      BOOT_GATE_EV="rule 7: pyproject.toml exists, no ruff mentioned; ${runner_ev}"
    fi
    return 0
  fi

  # Rule 8
  if [ -f "${root}/pubspec.yaml" ]; then
    BOOT_GATE_STATE="detected"
    if grep -qE "^[[:space:]]*flutter[[:space:]]*:" "${root}/pubspec.yaml"; then
      BOOT_GATE="dart analyze && flutter test"
      BOOT_GATE_EV="rule 8: pubspec.yaml declares a flutter dependency/sdk"
    else
      BOOT_GATE="dart analyze && dart test"
      BOOT_GATE_EV="rule 8: pubspec.yaml exists with no flutter key (plain Dart package)"
    fi
    return 0
  fi

  # Rule 9. A Stop hook that already names a verify-ish command is the repo telling us what it runs.
  # `|| true` on both legs: grep exiting 1 on no-match is the normal case, not a failure.
  local settings="${root}/.claude/settings.json" hit cmd
  if [ -f "$settings" ]; then
    hit="$(grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' "$settings" 2>/dev/null | grep -iE 'verify|quality-gate|gate\.sh|check' | head -n1 || true)"
    if [ -n "$hit" ]; then
      cmd="${hit#*\"command\"}"
      cmd="${cmd#*\"}"
      cmd="${cmd%\"}"
      if [ -n "$cmd" ]; then
        BOOT_GATE_STATE="detected"
        BOOT_GATE="$cmd"
        BOOT_GATE_EV="rule 9: .claude/settings.json hook already names this command"
        return 0
      fi
    fi
  fi

  # Nothing matched. Say exactly what was looked for, because "not detected" is only useful to a
  # reader who can see which stones were turned over.
  BOOT_GATE_EV="no rule matched: no usable CI job (${BOOT_GATE_CI_WHY:-no .github/workflows, .gitlab-ci.yml or .circleci/config.yml}), no netlify.toml/vercel.json host build, no scripts/verify.sh, no USABLE verify/check/ci/test:ci/test/lint script in package.json${BOOT_GATE_PKG_WHY:+ (${BOOT_GATE_PKG_WHY})}, no check/test target in a Makefile, no Cargo.toml, no pyproject.toml, no pubspec.yaml, no verify-ish command in .claude/settings.json"
}

# --- fact 4: ui.enabled --------------------------------------------------------------------------
#
# TRUE only on real evidence, and false by default. A wrongly-true ui.enabled makes every build try
# a UI gate that does not exist; a wrongly-false one merely skips a gate and says so, which is the
# declared degrade. So the asymmetry is deliberate: never guess true.

BOOT_UI="false"; BOOT_UI_PATHS=""; BOOT_UI_PATHS_SURE=1; BOOT_UI_EV=""
_boot_detect_ui() {
  local root="$1" hit
  BOOT_UI="false"; BOOT_UI_PATHS=""; BOOT_UI_PATHS_SURE=1; BOOT_UI_EV="no web/ directory, no vite/next config, no index.html"

  if [ -d "${root}/web" ]; then
    BOOT_UI="true"; BOOT_UI_PATHS="[web/]"
    BOOT_UI_EV="web/ directory exists"
    return 0
  fi
  if hit="$(_boot_first_existing "${root}"/vite.config.* "${root}"/next.config.* "${root}"/index.html)"; then
    BOOT_UI="true"
    BOOT_UI_EV="$(basename "$hit") in the repo root"
    if [ -d "${root}/src" ]; then
      BOOT_UI_PATHS="[src/]"; BOOT_UI_PATHS_SURE=0
    else
      BOOT_UI_PATHS=""; BOOT_UI_PATHS_SURE=0
    fi
    return 0
  fi
}

# --- writers -------------------------------------------------------------------------------------

_boot_import_block() {
  cat <<'IMPORTBLOCK'
@.claude/PROJECT.md

The line above imports `.claude/PROJECT.md`, the **project manifest**: the per-repo facts the
vendored engineering skills bind to (repo slug, default branch, labels, branch prefixes, worktree
paths, the gate command, the reviewers). Its bindings are Markdown tables **in the body**, because
an `@` import carries the prose body only and strips YAML frontmatter, so a binding written up there
would never reach a session.
IMPORTBLOCK
}

# Is the manifest already imported? Whitespace-tolerant, and it accepts the `./`-prefixed spelling.
_boot_has_import() {
  local file="$1" raw line
  [ -f "$file" ] || return 1
  while IFS= read -r raw || [ -n "$raw" ]; do
    line="$(_boot_trim "$raw")"
    case "$line" in
      '@.claude/PROJECT.md'|'@./.claude/PROJECT.md') return 0 ;;
    esac
  done < "$file"
  return 1
}

# True when templates/FILES.tsv will write $1 into the consumer (respecting the `when` filter).
# Lets the manifest bind only to files that will actually exist.
_boot_registry_writes() {
  local want="$1" registry="${TEMPLATES_DIR}/FILES.tsv"
  local r_source r_dest r_mode r_when r_summary
  [ -f "$registry" ] || return 1
  while IFS="$(printf '\t')" read -r r_source r_dest r_mode r_when r_summary; do
    case "$r_source" in ""|"#"*) continue ;; esac
    [ "$r_dest" = "$want" ] || continue
    if [ "$r_when" = "ui" ] && [ "${BOOT_UI}" != "true" ]; then return 1; fi
    return 0
  done < "$registry"
  return 1
}

# --- project-layer scaffold (templates/FILES.tsv) ------------------------------------------------
# Substitute {{TOKEN}} placeholders on stdin. An UNKNOWN token is left verbatim rather than blanked:
# a typo must show up in the output, never silently delete the line it was on.
_boot_render_template() {
  local name="$1" today="$2" ui_ev="$3"
  sed -e "s|{{REPO_NAME}}|${name}|g" \
      -e "s|{{TODAY}}|${today}|g" \
      -e "s|{{UI_EV}}|${ui_ev}|g"
}

# Walk templates/FILES.tsv and write each row whose `when` matches. Never overwrites: a destination
# that already exists is reported as skipped, exactly like the manifest and the gate shim, so
# bootstrap stays safe to re-run.
_boot_scaffold_registry() {
  local root="$1" name="$2" today="$3" dry_run="$4"
  local registry="${TEMPLATES_DIR}/FILES.tsv"

  if [ ! -f "$registry" ]; then
    echo "    WARNING: no template registry at ${registry} - nothing scaffolded." >&2
    return 0
  fi

  local source dest mode when summary src_path dest_path
  while IFS="$(printf '\t')" read -r source dest mode when summary; do
    case "$source" in ''|'#'*) continue ;; esac
    [ -n "$dest" ] || continue

    if [ "$when" = "ui" ] && [ "${BOOT_UI}" != "true" ]; then
      continue
    fi

    src_path="${TEMPLATES_DIR}/project/${source}"
    dest_path="${root}/${dest}"

    if [ ! -f "$src_path" ]; then
      echo "    WARNING: registry names ${source}, which is missing from templates/project - skipped." >&2
      continue
    fi
    if [ -e "$dest_path" ]; then
      echo "    ${dest} already present, untouched."
      _boot_skipped "${dest} (already present)"
      continue
    fi
    if [ "$dry_run" = "1" ]; then
      echo "    would create ${dest} - ${summary}"
      _boot_created "${dest}"
      continue
    fi

    mkdir -p "$(dirname "$dest_path")"
    _boot_render_template "$name" "$today" "${BOOT_UI_EV}" < "$src_path" > "$dest_path"
    [ -n "$mode" ] && chmod "$mode" "$dest_path"
    echo "    created ${dest} - ${summary}"
    _boot_created "${dest}"
  done < "$registry"
}

_boot_write_manifest() {
  local path="$1" name="$2" today="$3"
  local agent_file agent_name n

  {
    printf '# %s - project manifest\n\n' "$name"
    cat <<'MANI1'
**This file is imported into every session** by the root `CLAUDE.md`'s literal `@.claude/PROJECT.md`
line, so it is in context on every run, including a headless `claude -p` where nothing prompts
anyone to go and read it.

**The bindings tables below are the contract.** A vendored skill reads a value by its dotted key
name (`gate.command`, `labels.ready`, `branch.epic_prefix`, ...). Those names are the interface, and
these tables are the only place a value lives.

**The bindings are in the prose body on purpose.** The `@` import strips YAML frontmatter, so a
binding written up there would never reach a headless session. Do not tidy these tables into
frontmatter, and do not add a frontmatter mirror of them.

MANI1
    printf 'Scaffolded by `setup.sh --bootstrap` on %s. Detected values carry their evidence in the\n' "$today"
    printf 'note under each table. Anything it could not detect is marked **TODO** and listed below.\n\n'

    if [ "${#BOOT_TODOS[@]}" -gt 0 ]; then
      cat <<'MANITODO'
## TODO - bootstrap could NOT detect these

Until every line here is answered this manifest is **not true**, and a skill reading it will either
stop or degrade. Fix them, then delete this section.

MANITODO
      local t
      for t in ${BOOT_TODOS[@]+"${BOOT_TODOS[@]}"}; do
        printf -- '- **TODO** %s\n' "$t"
      done
      printf '\n'
    fi

    cat <<'MANI2'
## Bindings

`manifest_version: 1`

### repo

MANI2
    printf '| Key | Value |\n|---|---|\n'
    if [ -n "${BOOT_SLUG}" ]; then
      printf '| `repo.slug` | `%s` |\n' "${BOOT_SLUG}"
    else
      printf '| `repo.slug` | **TODO** - not detected (%s) |\n' "${BOOT_SLUG_EV}"
    fi
    if [ -n "${BOOT_BRANCH}" ]; then
      printf '| `repo.default_branch` | `%s` |\n' "${BOOT_BRANCH}"
    else
      printf '| `repo.default_branch` | **TODO** - not detected (%s) |\n' "${BOOT_BRANCH_EV}"
    fi
    printf '| `repo.visibility` | `private` |\n'
    if [ -n "${BOOT_TRACKER}" ]; then
      printf '| `tracker` | `%s` |\n' "${BOOT_TRACKER}"
    else
      printf '| `tracker` | **TODO** - not detected (%s). `github` or `none` |\n' "${BOOT_TRACKER_EV}"
    fi
    printf '\nEvidence each of those came from:\n\n'
    printf -- '- `repo.slug` <- %s\n' "${BOOT_SLUG_EV}"
    printf -- '- `repo.default_branch` <- %s\n' "${BOOT_BRANCH_EV}"
    printf -- '- `tracker` <- %s\n\n' "${BOOT_TRACKER_EV}"
    cat <<'MANI3'
`repo.visibility` is **assumed** `private`, not detected. It only explains why an unauthenticated
fetch of an attachment 404s, and assuming private is the safe direction.

### labels

| Key | Value |
|---|---|
| `labels.ready` | `ready-to-build` |
| `labels.human_gate` | `human-merge` |
| `labels.triage` | `needs-triage` |
| `labels.epic` | `epic` |
| `labels.bug` | `bug` |
| `labels.enhancement` | `enhancement` |
| `labels.priority_order` | `[P0, P1, P2]` |

**Assumed, not detected.** These are the pack's conventional names, not a reading of your tracker.
Check them against `gh label list` and either create the missing ones or rename them here.
`labels.ready` is load-bearing: an autonomous build loop filters strictly on it, so a name that does
not exist means nothing is ever picked up.

### branch

| Key | Value |
|---|---|
| `branch.bug_prefix` | `fix` |
| `branch.feature_prefix` | `feat` |
| `branch.epic_prefix` | `epic` |
| `branch.slug_max_len` | `50` |

**Assumed, not detected.** Change them if this repo names branches differently.

### worktree

MANI3
    printf '| Key | Value |\n|---|---|\n'
    printf '| `worktree.path_template` | `../%s-<slug>` |\n' "$name"
    printf '| `worktree.epic_path_template` | `../%s-epic-<N>` |\n' "$name"
    printf '\nDerived from the repo directory name (`%s`). `<slug>` and `<N>` are substituted per build.\n\n' "$name"

    cat <<'MANI4'
### gate

| Key | Value |
|---|---|
| `gate.command` | `bash .claude/scripts/gate.sh` |

`gate.command` is the **shim**, in every repo. That indirection is the whole point: a vendored skill
says "run the gate" and never has to know what this repo's gate actually is.

MANI4
    case "${BOOT_GATE_STATE}" in
      existing)
        printf 'The shim was already present and bootstrap did not touch it, so whatever it delegates to is\nunchanged (%s).\n\n' "${BOOT_GATE_EV}"
        ;;
      detected)
        printf 'What the shim delegates to in this repo:\n\n'
        printf '    %s\n\n' "${BOOT_GATE}"
        printf 'Detected by %s.\n' "${BOOT_GATE_EV}"
        printf 'Check that really is this repo'"'"'s FULL gate before trusting a green from it.\n\n'
        if [ -n "${BOOT_GATE_CI_SKIPPED}" ]; then
          printf '> **TODO - THIS GATE IS ONLY PART OF THE CI.** `%s` also declares job(s) the shim\n' "${BOOT_GATE_CI_FILE}"
          printf '> could not replay in full: **%s**.\n' "${BOOT_GATE_CI_SKIPPED}"
          if [ -n "${BOOT_GATE_CI_RESCUED}" ]; then
            printf '> The standalone script(s) `%s` were salvaged out of that and DO run.\n' "${BOOT_GATE_CI_RESCUED}"
          fi
          printf '> Nothing else those jobs assert is covered, so a green here is **not** the verdict the repo'"'"'s own\n'
          printf '> CI gives. Either add the missing check to `.claude/scripts/gate.sh` by hand, or accept that\n'
          printf '> CI can still reject a tree this gate calls green - and say which in the PR body.\n\n'
        fi
        if [ -n "${BOOT_GATE_CI_PREREQ}" ]; then
          printf '**`gate.prereq` - what this gate does NOT set up:** %s.\n' "${BOOT_GATE_CI_PREREQ}"
          printf 'Those commands were deliberately kept out of the delegate rather than pretended into coverage.\n'
          printf 'A leg that fails because one of them was never run is a could-not-run wearing a red coat: start\n'
          printf 'the service, re-run, and only then read the colour.\n\n'
        fi
        if [ -n "${BOOT_GATE_CI_DROPPED}" ]; then
          printf 'Jobs read and deliberately NOT treated as checks: %s.\n\n' "${BOOT_GATE_CI_DROPPED}"
        fi
        if [ "${#BOOT_GATE_TSC_LEGS[@]}" -gt 0 ]; then
          printf 'The shim wraps its tsc leg(s) in a `gate_tsc` helper that remaps **exit 2 to exit 1**. `tsc\n'
          printf -- '--noEmit` exits 2 on a COLD incremental run (it wrote the `.tsbuildinfo`, which counts as\n'
          printf 'generating output) and 1 when the cache is warm. Both mean diagnostics were present, i.e. RED,\n'
          printf 'but 2 is this contract'"'"'s COULD NOT RUN code - and since `*.tsbuildinfo` is gitignored, cold is\n'
          printf 'the default state of every fresh clone and worktree. Only legs bootstrap resolved to tsc are\n'
          printf 'remapped; a third-party delegate'"'"'s 2 is left alone, because there it may really mean it could\n'
          printf 'not run.\n\n'
        fi
        if [ -n "${BOOT_GATE_EXIT2}" ]; then
          printf '**This delegate reports RED as COULD NOT RUN.** `%s` contains a bare `exit 2`, and 2 is this\n' "${BOOT_GATE_EXIT2}"
          printf 'pack'"'"'s COULD NOT RUN code, so an ordinary failure of the delegate arrives as "nothing was proved"\n'
          printf 'rather than "the tree is red". The code is deliberately NOT remapped: that direction is safe (a\n'
          printf 'failure is never read as green). Read a 2 from this gate as "it may simply have failed".\n\n'
        fi
        ;;
      *)
        printf '> **TODO - THE GATE IS NOT WIRED.** Bootstrap found no evidence of a gate command in this repo,\n'
        printf '> so `.claude/scripts/gate.sh` currently **exits 2 (COULD NOT RUN)** on every invocation. That is\n'
        printf '> deliberate: a stub that exited 0 would report a green tree without running anything. Open the\n'
        printf '> shim, replace the `exit 2` block with the real command, and delete this note. Until then every\n'
        printf '> build stops before opening a PR, which is the correct behaviour but not a working repo.\n\n'
        if [ -n "${BOOT_GATE_REJECTED}" ]; then
          printf '> **A candidate WAS found and then REFUSED:** `%s`.\n' "${BOOT_GATE_REJECTED}"
          printf '> %s\n' "${BOOT_GATE_EV}"
          printf '> A detector that returns nothing is strictly better than one that returns a command able to\n'
          printf '> pass on a broken tree, so the candidate was dropped rather than shipped.\n\n'
        fi
        ;;
    esac

    if [ "${#BOOT_GATE_WARNS[@]}" -gt 0 ]; then
      printf 'Warnings raised while working the gate out - read these before trusting a green:\n\n'
      local gw
      for gw in ${BOOT_GATE_WARNS[@]+"${BOOT_GATE_WARNS[@]}"}; do
        printf -- '- %s\n' "$gw"
      done
      printf '\n'
    fi

    # checklist/tier bind INTO the scaffolded CONTRIBUTING.md. Emitted only when that file will
    # exist (the registry writes it, or the repo already had one) - a binding pointing at a missing
    # file is a could-not-run, not a pass, which is worse than having no binding at all.
    if [ -f "${root}/CONTRIBUTING.md" ] || _boot_registry_writes "CONTRIBUTING.md"; then
      cat <<'MANICHK'
### checklist

| Key | Value |
|---|---|
| `checklist.path` | `CONTRIBUTING.md` |
| `checklist.section` | `### Requirement-quality checklist (CHK)` |

### tier

| Key | Value |
|---|---|
| `tier.path` | `CONTRIBUTING.md` |
| `tier.section` | `### Build tier — every issue declares its model AND its effort` |

`checklist.section` and `tier.section` are the **literal heading text** to read from, not a URL
slug, so renaming a heading fails loudly as "section not found" - a could-not-run - instead of
silently resolving nowhere. Rename a heading and update the binding in the same commit.

MANICHK
    else
      cat <<'MANINOCHK'
### checklist

Not bound: this repo has no `CONTRIBUTING.md`. `/create-issue` therefore runs its **floor-only**
self-check and says so in the comment it posts. Write one, then bind `checklist.path` +
`checklist.section` to its heading.

### tier

Not bound: no build-tier vocabulary here, so no `model:`/`effort:` label is stamped. That is a
silent, safe degrade - never a gap to call out in an issue.

MANINOCHK
    fi

    printf '### ui\n\n| Key | Value |\n|---|---|\n'
    printf '| `ui.enabled` | `%s` |\n' "${BOOT_UI}"
    if [ "${BOOT_UI}" = "true" ]; then
      if [ -n "${BOOT_UI_PATHS}" ]; then
        if [ "${BOOT_UI_PATHS_SURE}" = "1" ]; then
          printf '| `ui.paths` | `%s` |\n' "${BOOT_UI_PATHS}"
        else
          printf '| `ui.paths` | `%s` **TODO: confirm** |\n' "${BOOT_UI_PATHS}"
        fi
      else
        printf '| `ui.paths` | **TODO** - which paths count as a UI diff? |\n'
      fi
      printf '| `ui.command` | **TODO** - wire the scaffolded `.claude/scripts/ui-gate.sh`, THEN bind it here |\n'
      printf '\nUI evidence: %s.\n\n' "${BOOT_UI_EV}"
      cat <<'MANIUI'
Bootstrap scaffolds `.claude/scripts/ui-gate.sh` **unwired**: it exits 2 (could not run) until you
fill it in. Its stdout contract (last line is the absolute screenshot directory, every
human-readable line on stderr, nothing at all on stdout when it fails) cannot be guessed from a
directory listing, so the file carries the contract and a worked example rather than a guess at your
test command.

`ui.command` is deliberately left **unbound** until you wire it. That ordering matters: an unbound
`ui.command` means the UI gate is *skipped* — the safe degrade — whereas binding it to a shim that
still exits 2 turns every UI-touching build into a hard block. Wire the shim first, bind second, and
until then every PR body must say the UI gate was skipped.

MANIUI
    else
      printf '\nNot detected as a UI repo (%s),\n' "${BOOT_UI_EV}"
      cat <<'MANINOUI'
so the UI gate never runs. Declared degrade: skip it entirely and say the skip out loud; never
substitute a screenshot-free guess at design conformance.

MANINOUI
    fi

    cat <<'MANI5'
### reviewers

`reviewers` is a list. Each entry is one `agent` plus the `when` condition that selects it. Naming an
agent here is what makes `setup.sh --vendor` install its file into `.claude/agents/`; **delete a row
and re-vendor** and the pack stops spawning it (the file is left on disk, vendoring never deletes).

MANI5
    printf '| # | `agent` | `when` |\n|---|---|---|\n'
    n=0
    for agent_file in "${PACK_DIR}"/agents/*.md; do
      [ -f "${agent_file}" ] || continue
      agent_name="$(basename "${agent_file}" .md)"
      n=$((n + 1))
      printf '| %s | `%s` | `always` |\n' "$n" "${agent_name}"
    done
    cat <<'MANI6'

All of the pack's reviewers are declared at `always`, which is the conservative default: more review,
never a claim that a review ran when it did not. Narrow a `when` to a path prefix (`src/`, `web/`) or
drop the row entirely, then re-vendor.

## Degrade rules - what a skill does when a key is absent

Absence is a decision, not an oversight. Every key degrades to a **safe, headless-legal** behaviour:

- **`gate.command` absent or the gate could not run (exit 2)** - fatal. A skill that cannot prove the
  tree is green **must not open a PR**. Exit 2 is never a pass and is not an ordinary test failure
  either, so "just fix the failing test" is the wrong response.
- **`ui.enabled: false` or absent** - skip the UI gate entirely, and say the skip out loud in the PR
  body. Never substitute a screenshot-free guess at design conformance.
- **`board` absent** - skip every board-sync call. Card state is a convenience, never a gate, and a
  board write failure must not block a build.
- **`reviewers` absent, or an agent not installed** - that reviewer is not spawned **and the PR body
  must say so**. Never claim a review ran that did not.
- **`tracker: none`** - there is no issue to close: drop `Closes #NN` from the PR body rather than
  inventing an issue number.
- **`labels.triage` absent** - `/triage` has no queue to read and does nothing.
- **`labels.epic` absent** - an epic cannot be detected by label; fall back to "does the issue have
  sub-issues".
- **`hooks.close_out` absent** - nothing extra happens at close-out. Skip silently, never invent a
  hook.
- **`.claude/REVIEW-ANCHORS.md` absent** (project-local, never vendored) - the reviewers still run,
  on their **universal lenses only**. Say so in the task prompt, have each reviewer record
  `ANCHORS: none - universal lenses only` in its verdict, and repeat that narrowing in the PR body.
  A narrowed review must never read as a full one.

**Never "stop and ask the human" as a degrade.** On an unattended box there is no human in the loop
and the driver's resume directive actively overrides an early stop. The headless-legal terminal
action is: **do not open the PR, post the blocker as a comment on the issue, and exit non-zero.** An
interactive gate that is the whole point of a skill (`/kickoff` proposing a plan, the final epic PR
being human-gated) is a designed stop, not a failure path, and is preserved.

## Project guards

Bindings tell a vendored skill what things are *called* here. Guards tell it what it must **not do**
here - rules that are project truth rather than skill truth, which is why they live in this file and
not in the portable pack.

_None declared yet._ Add them as you find them (for example: a directory an engineering change may
never restructure, a domain the skills must not enter, a command that must never run against
production).
MANI6
  } > "$path"
}

# The delegate AS THE SHIM RUNS IT: identical to `BOOT_GATE` except that every leg bootstrap proved
# is tsc is put through `gate_tsc`, which folds tsc's cold-run exit 2 onto 1. Split and re-join on
# " && " is an identity transform, so a leg that is not a known tsc leg comes out byte-for-byte.
_boot_gate_shim_command() {
  local out="" leg tleg wrapped
  while IFS= read -r leg; do
    [ -n "$leg" ] || continue
    wrapped="$leg"
    for tleg in ${BOOT_GATE_TSC_LEGS[@]+"${BOOT_GATE_TSC_LEGS[@]}"}; do
      if [ "$leg" = "$tleg" ]; then wrapped="gate_tsc ${leg}"; break; fi
    done
    out="${out}${out:+ && }${wrapped}"
  done <<SHIMEOF
$(_boot_gate_legs "${BOOT_GATE}")
SHIMEOF
  printf '%s\n' "$out"
}

_boot_write_gate() {
  local path="$1" today="$2"

  {
    cat <<'GATE1'
#!/usr/bin/env bash
#
# gate.sh - the portable "run the quality gate" shim. REQUIRED contract.
#
# This is `gate.command` in .claude/PROJECT.md. A vendored skill never names a repo's real gate; it
# runs THIS path, and each repo points the shim at whatever its gate actually is. No logic belongs
# here: it is a shim, not a gate. Arguments pass straight through and the exit code is preserved.
#
# EXIT CODES - the contract every caller binds to:
#
#   0   GREEN. The gate ran, in full, and passed.
#
#   2   COULD NOT RUN. Nothing was proved either way: the delegate is missing, a required tool is
#       absent, or the environment short-circuited the gate before it ran. A caller MUST treat 2 as
#       UNSATISFIED. It is never a pass, and it is not an ordinary test failure either, so "just fix
#       the failing test" is the wrong response. A skill that cannot prove the tree is green must
#       NOT open a PR: post the blocker as a comment on the issue and exit non-zero.
#
#   *   RED. The gate ran and failed. Ordinary test/lint failure, fix the code.
#
# The dangerous confusion is a could-not-run being read as a pass, so every non-zero exit stays
# non-zero: this shim only ever maps one non-zero code onto another (126/127 from the delegate
# become 2). There is no path from a failing delegate to 0.
#
GATE1
    printf '# Scaffolded by `setup.sh --bootstrap` on %s.\n' "$today"
    if [ "${BOOT_GATE_STATE}" = "detected" ]; then
      printf '# Delegate detected from evidence:\n#   %s.\n' "${BOOT_GATE_EV}"
      printf '# Check that really is this repo'"'"'s FULL gate: a green from here is taken as proof.\n'
      if [ -n "${BOOT_GATE_CI_SKIPPED}" ]; then
        printf '#\n# TODO - ONLY PART OF THE CI IS REPLAYED HERE. %s also declares:\n' "${BOOT_GATE_CI_FILE}"
        printf '#   %s\n' "${BOOT_GATE_CI_SKIPPED}"
        if [ -n "${BOOT_GATE_CI_RESCUED}" ]; then
          printf '# The standalone script(s) %s WERE salvaged out of that and do run below;\n' "${BOOT_GATE_CI_RESCUED}"
          printf '# nothing else those job(s) assert is covered.\n'
        else
          printf '# Nothing those job(s) assert is covered below.\n'
        fi
        printf '# So a green from this shim is NOT the same verdict as the repo'"'"'s own CI. Add the rest by\n'
        printf '# hand, or expect CI to reject trees this shim calls green.\n'
      fi
      if [ -n "${BOOT_GATE_CI_PREREQ}" ]; then
        printf '#\n# PREREQUISITES this shim does NOT set up (kept out because they need a service):\n'
        printf '#   %s\n' "${BOOT_GATE_CI_PREREQ}"
        printf '# A leg that fails because one of those is not up is a could-not-run wearing a red coat.\n'
      fi
      if [ -n "${BOOT_GATE_EXIT2}" ]; then
        printf '#\n# WARNING: %s carries a bare `exit 2`, which is this contract'"'"'s COULD NOT RUN code.\n' "${BOOT_GATE_EXIT2}"
        printf '# THIS DELEGATE THEREFORE REPORTS RED AS COULD NOT RUN. Not remapped on purpose: that\n'
        printf '# direction is safe, since a failure is never read as a pass.\n'
      fi
      if [ "${#BOOT_GATE_TSC_LEGS[@]}" -gt 0 ]; then
        printf '#\n# TSC EXIT-CODE REMAP (2 -> 1) on these legs, and ONLY these:\n'
        local tleg
        for tleg in ${BOOT_GATE_TSC_LEGS[@]+"${BOOT_GATE_TSC_LEGS[@]}"}; do
          printf '#   %s\n' "${tleg}"
        done
        printf '# `tsc --noEmit` returns 1 (DiagnosticsPresent_OutputsSkipped) when it emitted nothing and 2\n'
        printf '# (DiagnosticsPresent_OutputsGenerated) when it had already written output - which is what a\n'
        printf '# COLD run of a project with `"incremental": true` does, because writing the `.tsbuildinfo`\n'
        printf '# counts as generating output. That file is gitignored, so COLD is the DEFAULT state of a\n'
        printf '# fresh clone, a fresh worktree and a CI runner. Both codes mean DIAGNOSTICS WERE PRESENT,\n'
        printf '# which is RED - but 2 is this contract'"'"'s COULD NOT RUN code, so without the remap the same\n'
        printf '# type error reports "nothing was proved" cold and "the tree is red" warm.\n'
        printf '# The remap is applied ONLY to legs bootstrap resolved to tsc itself. A third-party\n'
        printf '# delegate keeps its 2 untouched: there, a 2 may genuinely mean could-not-run.\n'
      fi
    elif [ -n "${BOOT_GATE_REJECTED}" ]; then
      printf '#\n# A candidate delegate WAS found and then REFUSED: %s\n' "${BOOT_GATE_REJECTED}"
      printf '#   %s\n' "${BOOT_GATE_EV}"
      printf '# It would have reported GREEN on a tree the repo'"'"'s own checks call red, so it was dropped.\n'
    fi
    cat <<'GATE2'
set -euo pipefail

# Repo root: this script sits two levels down, so the shim works from any cwd.
cd "$(dirname "$0")/../.."

GATE2

    if [ "${BOOT_GATE_STATE}" != "detected" ]; then
      cat <<'GATENONE'
# ---------------------------------------------------------------------------------------------
# NOT WIRED YET. Bootstrap found no evidence of a gate command in this repo, so this shim refuses
# to answer rather than answer wrongly.
#
# EXIT 2, NEVER 0. A stub that exited 0 would report a green tree without running anything, and
# every caller downstream treats 0 as proof. That is the single worst failure available here, so
# the unfilled state is could-not-run by construction.
#
# TO FIX: delete this block and replace it with the real gate, keeping the shape below.
#
#     command -v npm >/dev/null 2>&1 || { echo "gate: npm not on PATH - COULD NOT RUN" >&2; exit 2; }
#     status=0
#     npm run verify ${@+"$@"} || status=$?
#     case "$status" in 126|127) exit 2 ;; esac
#     exit "$status"
# ---------------------------------------------------------------------------------------------
echo "gate: no gate command is wired into this repo yet." >&2
echo "gate: COULD NOT RUN (exit 2, treat as UNSATISFIED - never a pass)." >&2
echo "gate: fill in .claude/scripts/gate.sh with the real command, then re-run." >&2
exit 2
GATENONE
    else
      local first_word shim_cmd
      first_word="$(_first_word "${BOOT_GATE}")"
      shim_cmd="$(_boot_gate_shim_command)"
      if [ "${#BOOT_GATE_TSC_LEGS[@]}" -gt 0 ]; then
        cat <<'GATETSC'
# tsc says RED with two different codes. On a COLD incremental run it exits 2
# (DiagnosticsPresent_OutputsGenerated, because it wrote the .tsbuildinfo) and on a warm one it exits
# 1 - and .tsbuildinfo is gitignored, so cold is what a fresh clone or worktree always is. Both mean
# diagnostics were present, i.e. the tree is RED, but 2 is this contract's COULD NOT RUN code. So the
# legs bootstrap RESOLVED TO TSC, and only those, come through here and have their 2 folded onto 1.
# Nothing else is touched: another delegate's 2 may genuinely mean it could not run.
gate_tsc() {
  local tsc_status=0
  "$@" || tsc_status=$?
  if [ "$tsc_status" = "2" ]; then tsc_status=1; fi
  return "$tsc_status"
}

GATETSC
      fi
      printf '# The delegate must be reachable at all, or nothing was proved.\n'
      printf 'command -v %s >/dev/null 2>&1 || {\n' "${first_word}"
      printf '  echo "gate: '"'"'%s'"'"' is not on PATH - the gate COULD NOT RUN (exit 2, treat as UNSATISFIED)." >&2\n' "${first_word}"
      printf '  exit 2\n'
      printf '}\n\n'
      # Argument pass-through is only well defined for a SINGLE-command delegate. Appending the
      # arguments to a composed `a && b` would silently hand them to the last leg alone, which is
      # not what "pass them straight through" means, so a multi-leg delegate says so out loud
      # instead of quietly doing the wrong thing.
      case "${BOOT_GATE}" in
        *"&&"*)
          cat <<'GATEARGS'
# This delegate is a multi-leg command, so there is no single place to forward arguments to.
# Saying so beats handing them to the last leg alone and calling that a pass-through.
if [ "$#" -gt 0 ]; then
  echo "gate: delegate is multi-leg; arguments are NOT forwarded (got: $*)." >&2
fi

# `|| status=$?` keeps the failure out of `set -e`'s hands so we can inspect and re-raise it.
status=0
GATEARGS
          printf '{ %s; } || status=$?\n' "${shim_cmd}"
          ;;
        *)
          cat <<'GATERUN'
# `|| status=$?` keeps the failure out of `set -e`'s hands so we can inspect and re-raise it.
# ${@+"$@"} is the bash 3.2 safe expansion: a bare "$@" with no args trips `set -u` on macOS.
status=0
GATERUN
          printf '%s ${@+"$@"} || status=$?\n' "${shim_cmd}"
          ;;
      esac
      cat <<'GATETAIL'

case "$status" in
  126 | 127)
    # Delegate not executable, or a tool it needs is not on PATH. It never reached a verdict.
    echo "gate: delegate exited $status (tool missing or not executable) - COULD NOT RUN (exit 2)." >&2
    exit 2
    ;;
esac

exit "$status"
GATETAIL
    fi
  } > "$path"
  chmod +x "$path"
}

_boot_inject_import() {
  local file="$1" tmp="$1.bootstrap.$$" raw n=0 heading=0 first=""

  # Read the first line to decide where the block goes: under an existing H1 if there is one, at the
  # very top otherwise. Near the top either way, because an import that sits below a wall of prose
  # reads as an afterthought.
  IFS= read -r first < "$file" || true
  case "$(_boot_trim "${first}")" in
    '#'*) heading=1 ;;
  esac

  {
    if [ ! -s "$file" ]; then
      _boot_import_block
    else
      while IFS= read -r raw || [ -n "$raw" ]; do
        n=$((n + 1))
        if [ "$n" = "1" ]; then
          if [ "$heading" = "1" ]; then
            printf '%s\n\n' "$raw"
            _boot_import_block
          else
            _boot_import_block
            printf '\n%s\n' "$raw"
          fi
          continue
        fi
        printf '%s\n' "$raw"
      done < "$file"
    fi
  } > "$tmp"

  mv "$tmp" "$file"
}

_boot_write_minimal_claude_md() {
  local path="$1" name="$2"
  {
    printf '# %s\n\n' "$name"
    _boot_import_block
    cat <<'CMD1'

## Working here

Add this repo's own engineering conventions below: how it is built, run and tested, what must never
be touched, anything a session should know before it edits a file. Keep per-repo *bindings* (labels,
branch prefixes, paths, commands) in `.claude/PROJECT.md` instead, so the portable skills can read
them by name.
CMD1
  } > "$path"
}

# --- the mode itself -----------------------------------------------------------------------------

bootstrap_repo() {
  local target="" dry_run=0 force=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      --force)   force=1; shift ;;
      -h|--help) usage ;;
      -*)
        echo "bootstrap: unknown option '$1'." >&2
        exit 2
        ;;
      *)
        if [ -n "$target" ]; then
          echo "bootstrap: one target repo at a time (got '$target' and '$1')." >&2
          exit 2
        fi
        target="$1"; shift
        ;;
    esac
  done

  # Default to the current directory, so the owner can run it from inside the repo.
  [ -n "$target" ] || target="."

  if [ ! -d "$target" ]; then
    echo "bootstrap: no such directory: $target" >&2
    echo "  Pass the path to an existing checkout, or cd into it and run with no target at all." >&2
    exit 2
  fi
  if [ ! -d "${PACK_DIR}" ]; then
    echo "bootstrap: no engineering pack at ${PACK_DIR}" >&2
    exit 2
  fi

  local root
  if ! root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)"; then
    echo "bootstrap: '$target' is not a git repository." >&2
    echo "  Everything this writes (a manifest, a gate shim, a CLAUDE.md import, vendored copies) is" >&2
    echo "  reviewed and reverted through git; refusing to write outside it." >&2
    echo "  Run 'git init' in that directory first, then re-run this command." >&2
    exit 2
  fi

  local name today
  name="$(basename "$root")"
  today="$(date -u +%Y-%m-%d)"

  if [ "$dry_run" = "1" ]; then
    echo "==> DRY RUN. Bootstrapping ${root} (nothing will be written)"
  else
    echo "==> Bootstrapping ${root}"
  fi
  echo "    pack source: ${PACK_DIR}"
  echo ""

  # Same guard --vendor uses, run BEFORE anything is written: bootstrap creates files under
  # .claude/, so it must not start on top of someone's in-progress edit there. It then tells
  # vendor_pack to skip its own copy of this check, which would otherwise refuse on bootstrap's own
  # freshly written scaffold.
  local dirty
  dirty="$(git -C "$root" status --porcelain -- .claude 2>/dev/null || true)"
  if [ -n "$dirty" ] && [ "$force" != "1" ]; then
    echo "bootstrap: '$root' has uncommitted changes under .claude/:" >&2
    printf '%s\n' "$dirty" >&2
    echo "" >&2
    echo "  Bootstrap writes into .claude/ and then re-vendors over it, so it would eat an" >&2
    echo "  in-progress edit. Commit or stash them first, or re-run with --force if they are" >&2
    echo "  disposable." >&2
    exit 1
  fi
  if [ -n "$dirty" ] && [ "$force" = "1" ]; then
    echo "    warn: --force, proceeding over uncommitted changes under .claude/"
    echo ""
  fi

  # ---- 1. detect --------------------------------------------------------------------------------
  echo "--> 1. Detecting this repo's facts (each value with the evidence it came from)"

  _boot_detect_slug "$root"
  if [ -n "${BOOT_SLUG}" ]; then
    _boot_detected "repo.slug" "${BOOT_SLUG}" "${BOOT_SLUG_EV}"
  else
    _boot_detected "repo.slug" "TODO (not detected)" "${BOOT_SLUG_EV}"
    _boot_todo "\`repo.slug\` - ${BOOT_SLUG_EV}. Set it to \`owner/repo\`."
  fi

  _boot_detect_default_branch "$root"
  if [ -n "${BOOT_BRANCH}" ]; then
    _boot_detected "repo.default_branch" "${BOOT_BRANCH}" "${BOOT_BRANCH_EV}"
  else
    _boot_detected "repo.default_branch" "TODO (not detected)" "${BOOT_BRANCH_EV}"
    _boot_todo "\`repo.default_branch\` - ${BOOT_BRANCH_EV}. Every freshness check compares against \`origin/<default_branch>\`, so a skill cannot tell a stale checkout from current state without it."
  fi

  if [ -n "${BOOT_TRACKER}" ]; then
    _boot_detected "tracker" "${BOOT_TRACKER}" "${BOOT_TRACKER_EV}"
  else
    _boot_detected "tracker" "TODO (not detected)" "${BOOT_TRACKER_EV}"
    _boot_todo "\`tracker\` - ${BOOT_TRACKER_EV}. Use \`github\`, or \`none\` if there are no issues (then a PR body must drop \`Closes #NN\` rather than invent a number)."
  fi

  _boot_detect_gate "$root"
  case "${BOOT_GATE_STATE}" in
    existing)  _boot_detected "gate delegate" "(left as it is)" "${BOOT_GATE_EV}" ;;
    detected)
      _boot_detected "gate delegate" "${BOOT_GATE}" "${BOOT_GATE_EV}"
      if [ -n "${BOOT_GATE_CI_SKIPPED}" ]; then
        _boot_todo "**the rest of the CI** - \`${BOOT_GATE_CI_FILE}\` declares job(s) this shim could NOT replay: ${BOOT_GATE_CI_SKIPPED}. The gate covers ${BOOT_GATE_CI_JOBS} only, so a green from it is not the verdict CI gives. Add the missing check to \`.claude/scripts/gate.sh\` by hand."
      fi
      if [ -n "${BOOT_GATE_CI_PREREQ}" ]; then
        _boot_todo "\`gate.prereq\` - this gate does not set up: ${BOOT_GATE_CI_PREREQ}. Confirm how those are provided locally, or note in the PR body that the gate does not cover them."
      fi
      ;;
    *)
      _boot_detected "gate delegate" "TODO (NOT DETECTED)" "${BOOT_GATE_EV}"
      if [ -n "${BOOT_GATE_REJECTED}" ]; then
        _boot_todo "**the gate command** - a candidate (\`${BOOT_GATE_REJECTED}\`) was found and REFUSED, so \`.claude/scripts/gate.sh\` exits 2 (COULD NOT RUN) on every call and NO build will open a PR until you fill it in. ${BOOT_GATE_EV}"
      else
        _boot_todo "**the gate command** - nothing matched, so \`.claude/scripts/gate.sh\` exits 2 (COULD NOT RUN) on every call and NO build will open a PR until you fill it in. It never exits 0 by default, deliberately."
      fi
      ;;
  esac
  local gwarn
  if [ "${#BOOT_GATE_WARNS[@]}" -gt 0 ]; then
    for gwarn in ${BOOT_GATE_WARNS[@]+"${BOOT_GATE_WARNS[@]}"}; do
      echo "    !! gate warning: ${gwarn}"
    done
  fi

  _boot_detect_ui "$root"
  _boot_detected "ui.enabled" "${BOOT_UI}" "${BOOT_UI_EV}"
  if [ "${BOOT_UI}" = "true" ]; then
    _boot_todo "\`ui.command\` - a UI was detected (${BOOT_UI_EV}) and an UNWIRED \`.claude/scripts/ui-gate.sh\` was scaffolded for you. It exits 2 until you fill it in. Bind \`ui.command\` only AFTER wiring it: binding an unwired shim turns a safe skip into a hard block on every UI build."
    if [ "${BOOT_UI_PATHS_SURE}" != "1" ]; then
      _boot_todo "\`ui.paths\` - confirm which paths count as a UI diff (guessed from the repo layout)."
    fi
  fi

  local i=0
  while [ "$i" -lt "${#BOOT_KEYS[@]}" ]; do
    printf '    %-22s = %s\n' "${BOOT_KEYS[$i]}" "${BOOT_VALS[$i]}"
    printf '        evidence: %s\n' "${BOOT_EVS[$i]}"
    i=$((i + 1))
  done
  echo ""

  # ---- 2. the manifest --------------------------------------------------------------------------
  echo "--> 2. Project manifest (.claude/PROJECT.md)"
  local manifest="${root}/.claude/PROJECT.md"
  if [ -f "$manifest" ]; then
    echo "    exists already - left completely alone, nothing merged into it."
    echo "    (Re-check by hand that it still binds gate.command, labels.*, branch.*, worktree.*)"
    _boot_skipped ".claude/PROJECT.md (already present, untouched)"
  elif [ "$dry_run" = "1" ]; then
    echo "    would create .claude/PROJECT.md with the detected bindings as MARKDOWN TABLES IN THE BODY"
    echo "    (never frontmatter - the @ import strips it), plus the degrade rules and ${#BOOT_TODOS[@]} TODO(s)."
    _boot_created ".claude/PROJECT.md"
  else
    mkdir -p "${root}/.claude"
    _boot_write_manifest "$manifest" "$name" "$today"
    echo "    created .claude/PROJECT.md (${#BOOT_TODOS[@]} TODO(s) recorded in it)"
    _boot_created ".claude/PROJECT.md"
  fi
  echo ""

  # ---- 3. the CLAUDE.md import ------------------------------------------------------------------
  echo "--> 3. Manifest import in the root CLAUDE.md"
  local claude_md="${root}/CLAUDE.md"
  if [ ! -f "$claude_md" ]; then
    if [ "$dry_run" = "1" ]; then
      echo "    no CLAUDE.md - would create a minimal one carrying the @.claude/PROJECT.md import"
    else
      _boot_write_minimal_claude_md "$claude_md" "$name"
      echo "    created CLAUDE.md with the @.claude/PROJECT.md import"
    fi
    _boot_created "CLAUDE.md (minimal, with the import)"
  elif _boot_has_import "$claude_md"; then
    echo "    already imports @.claude/PROJECT.md - left alone."
    _boot_skipped "CLAUDE.md (import already present)"
  else
    if [ "$dry_run" = "1" ]; then
      echo "    would insert the @.claude/PROJECT.md import near the top of CLAUDE.md (nothing else changes)"
    else
      _boot_inject_import "$claude_md"
      echo "    inserted the @.claude/PROJECT.md import near the top of CLAUDE.md"
    fi
    _boot_created "CLAUDE.md import line"
  fi
  echo ""

  # ---- 4. the gate shim -------------------------------------------------------------------------
  echo "--> 4. Gate shim (.claude/scripts/gate.sh)"
  local gate="${root}/.claude/scripts/gate.sh"
  if [ -f "$gate" ]; then
    echo "    exists already - left completely alone."
    _boot_skipped ".claude/scripts/gate.sh (already present, untouched)"
  elif [ "$dry_run" = "1" ]; then
    if [ "${BOOT_GATE_STATE}" = "detected" ]; then
      echo "    would create .claude/scripts/gate.sh (chmod +x) delegating to: ${BOOT_GATE}"
    else
      echo "    would create .claude/scripts/gate.sh (chmod +x) that EXITS 2 (could-not-run), never 0,"
      echo "    because no gate command was detected. A stub that returned green is the worst failure here."
    fi
    _boot_created ".claude/scripts/gate.sh"
  else
    mkdir -p "${root}/.claude/scripts"
    _boot_write_gate "$gate" "$today"
    if [ "${BOOT_GATE_STATE}" = "detected" ]; then
      echo "    created .claude/scripts/gate.sh (chmod +x) delegating to: ${BOOT_GATE}"
    else
      echo "    created .claude/scripts/gate.sh (chmod +x) - it EXITS 2 (could-not-run) until you fill it in."
    fi
    _boot_created ".claude/scripts/gate.sh"
  fi
  echo ""

  # ---- 5. vendor --------------------------------------------------------------------------------
  # ---- 5. the project-layer scaffold (templates/FILES.tsv) --------------------------------------
  echo "--> 5. Project-layer files (from templates/FILES.tsv)"
  _boot_scaffold_registry "$root" "$name" "$today" "$dry_run"
  echo ""

  echo "--> 6. Vendoring the pack (handing off to --vendor, one implementation)"
  if [ "$dry_run" = "1" ] && [ ! -f "$manifest" ]; then
    echo "    NOTE: on a dry run the manifest does not exist yet, so the vendor step below reports NO"
    echo "          reviewer agents. A real run writes the manifest first and installs the ones it declares."
  fi
  echo ""
  if [ "$dry_run" = "1" ]; then
    vendor_pack "$root" --skip-dirty-check --dry-run
  else
    vendor_pack "$root" --skip-dirty-check
  fi
  echo ""

  # ---- 7. summary -------------------------------------------------------------------------------
  local item
  echo "==> Bootstrap summary"
  if [ "$dry_run" = "1" ]; then
    echo "    DRY RUN - nothing above was written."
  fi
  echo ""
  echo "  1. Detected (value <- evidence)"
  i=0
  while [ "$i" -lt "${#BOOT_KEYS[@]}" ]; do
    printf '       %-22s %s\n' "${BOOT_KEYS[$i]}" "${BOOT_VALS[$i]}"
    printf '       %-22s   <- %s\n' "" "${BOOT_EVS[$i]}"
    i=$((i + 1))
  done
  echo ""

  if [ "${#BOOT_GATE_WARNS[@]}" -gt 0 ]; then
    echo "     GATE WARNINGS - read these before trusting a green from this repo:"
    for gwarn in ${BOOT_GATE_WARNS[@]+"${BOOT_GATE_WARNS[@]}"}; do
      echo "       !! ${gwarn}"
    done
    echo ""
  fi

  if [ "$dry_run" = "1" ]; then
    echo "  2. Would create"
  else
    echo "  2. Created"
  fi
  if [ "${#BOOT_CREATED[@]}" -eq 0 ]; then
    echo "       (nothing - this repo was already set up)"
  else
    for item in ${BOOT_CREATED[@]+"${BOOT_CREATED[@]}"}; do
      echo "       ${item}"
    done
  fi
  echo ""

  echo "  3. Skipped (already present, left exactly as they were)"
  if [ "${#BOOT_SKIPPED[@]}" -eq 0 ]; then
    echo "       (nothing)"
  else
    for item in ${BOOT_SKIPPED[@]+"${BOOT_SKIPPED[@]}"}; do
      echo "       ${item}"
    done
  fi
  echo ""

  echo "  4. TODO - values bootstrap could NOT detect"
  if [ "${#BOOT_TODOS[@]}" -eq 0 ]; then
    echo "       (none - every value came from evidence; still worth reading the manifest once)"
  else
    for item in ${BOOT_TODOS[@]+"${BOOT_TODOS[@]}"}; do
      echo "       - ${item}"
    done
  fi
  echo ""

  echo "  5. Remaining manual steps"
  echo "       a. Fill in every TODO in .claude/PROJECT.md (and in .claude/scripts/gate.sh if the"
  echo "          gate was not detected - it exits 2 until then, and no build will open a PR)."
  echo "       b. Check the assumed values the detector could not read from evidence: the label"
  echo "          names, the branch prefixes and the worktree templates."
  echo "       c. RESTART Claude Code. The agent registry is read at BOOT, so a newly vendored"
  echo "          reviewer is not spawnable in a running session and /clear does not re-read it."
  echo "          Without a restart the first gated build honestly reports that no review ran."
  echo "       d. Commit the scaffold, the vendored copies and .claude/skills/.vendored.lock"
  echo "          together, so the drift check is green in the same commit that carries them."
  echo "       e. Add this repo to consumers.txt upstream, or it never receives a pack fix."
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
  --bootstrap)
    shift
    bootstrap_repo "$@"
    ;;
  --help|-h)
    usage
    ;;
  *)
    setup_project "$@"
    ;;
esac
