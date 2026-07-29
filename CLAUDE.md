# claude-agents-skills

Reusable Claude Code agent definitions and technology skill documentation, installed into downstream projects via `setup.sh`.

## Stack

- Shell (Bash 4+) — setup.sh, verify scripts
- Markdown — agent definitions, skill documentation, CLAUDE.md files
- JSON — hook settings templates
- YAML — frontmatter in agent and skill Markdown files

## Directory Structure

```
agents/           Agent definitions (Markdown with YAML frontmatter)
  universal/      Stack-independent agents (installed via --global)
  frontend/       Frontend-specific agents
  flutter/        Flutter-specific agents
  python/         Python-specific agents
  rust/           Rust-specific agents
skills/           Technology skill documentation (SKILL.md files)
  engineering/    Portable engineering pack, VENDORED (copied) into consumer repos via --vendor
                  5 workflow skills + agents/ (3 reviewers) + README.md (manifest contract)
  global/         Stack-independent skills (symlinked to ~/.claude/skills/)
  frontend/       Frontend skills (8 skills)
  flutter/        Flutter skills (1 complete, 3 stubs)
  python/         Python skills (1 complete, 3 stubs)
  rust/           Rust skills (2 stubs)
feature-docs/     Mirrors downstream project structure (copied as-is by setup.sh)
  CLAUDE.md            Lifecycle guide + feature doc format, auto-discovered by Claude
  new-feature.md       Sourceable prompt for ideation and direct feature creation
  implement-feature.md Sourceable prompt to implement an existing feature doc
  ideation/            CLAUDE.md (with README template) + feature exploration folders
  ready/               Example feature doc
hooks/            .claude/settings.json templates per stack
verify-scripts/   Stack-specific verify + fast-verify scripts, hook scripts
consumers.txt     Repos that vendor skills/engineering/ (gitignored, local; see consumers.txt.example)
setup.sh          Installer: ./setup.sh --global | ./setup.sh <stack> [extras]
                             | ./setup.sh --vendor <target> [--dry-run] [--force]
```

## Vendoring vs the other two install modes

Three modes, three mechanics, and the difference matters:

| Mode       | Mechanic                                 | Why                                                                                                                                                         |
| ---------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--global` | **symlink** into `~/.claude/`            | one machine, stays in sync with this checkout                                                                                                               |
| `<stack>`  | **copy** whole skill dirs into a project | per-project customisation is expected                                                                                                                       |
| `--vendor` | **copy per file** + a sha256 lock        | the target may be a CI box that runs `git clone` + `git reset --hard` + `claude -p` with no `~/.claude`, so symlinks, submodules and plugins all fail there |

Two rules `--vendor` must never lose: it copies **per file** and never removes a target directory (a consumer's `.claude/skills/` also holds that project's own skills), and it **preserves `# override:` declarations** in `.vendored.lock` and refuses to overwrite a file declared as one. See `skills/engineering/README.md`.

## Setup

```bash
./setup.sh --global              # Symlink universal agents + global skills to ~/.claude/
./setup.sh frontend              # Copy frontend skills/agents into current project
./setup.sh flutter               # Copy Flutter skills/agents into current project
./setup.sh python neo4j          # Python stack + neo4j extras
```

## Content Inventory

### Agents

| Agent             | Stack     | Model  | Lines | Description                                                                       |
| ----------------- | --------- | ------ | ----- | --------------------------------------------------------------------------------- |
| code-reviewer     | universal | opus   | 75    | Code review with security, error handling, convention checks                      |
| planner           | universal | sonnet | 88    | Implementation planning before coding                                             |
| frontend-engineer | frontend  | opus   | 157   | UI review, React optimization, component scaffolding (3 workflows)                |
| component-builder | frontend  | sonnet | 146   | Investigation workspace components with Zustand/NVL integration                   |
| test-writer       | frontend  | sonnet | 147   | Write failing Vitest/Playwright tests from feature docs                           |
| builder           | frontend  | opus   | 146   | Implement code to make failing tests pass (React/Zustand)                         |
| test-writer       | flutter   | sonnet | 147   | Write Flutter widget tests from feature docs                                      |
| builder           | flutter   | opus   | 146   | Implement Flutter features from acceptance criteria                               |
| test-writer       | python    | sonnet | 163   | Write failing pytest tests from feature docs                                      |
| builder           | python    | opus   | 143   | Implement code to make failing pytest tests pass                                  |
| code-reviewer     | rust      | opus   | 123   | Rust-specific code review — ownership, async safety, error handling, unsafe audit |
| test-writer       | rust      | sonnet | 155   | Write failing cargo tests from feature docs                                       |
| builder           | rust      | opus   | 143   | Implement code to make failing cargo tests pass                                   |

### Skills — Complete

| Skill              | Stack    | Lines | Description                                                                          |
| ------------------ | -------- | ----- | ------------------------------------------------------------------------------------ |
| react              | frontend | 940   | Components, hooks, TypeScript, state, performance, error handling                    |
| testing-playwright | frontend | 881   | E2E testing, page objects, fixtures, ARIA snapshots                                  |
| shadcn-ui          | frontend | 733   | Component library, composition, theming, forms                                       |
| nvl                | frontend | 685   | Neo4j Visualization Library, graph rendering, styling, layout                        |
| tailwind           | frontend | 659   | Tailwind v4 CSS-first config, responsive, animations                                 |
| agent-teams        | global   | 719   | Agent Teams workflow, ideation phase, feature doc lifecycle, test-first coordination |
| git-workflow       | global   | 579   | Branching, commits, PR workflow, rebase vs merge                                     |
| zustand-state      | frontend | 521   | Stores, selectors, middleware, multi-view sync                                       |
| react-patterns     | frontend | 472   | React 19 patterns, TypeScript strict, architecture                                   |
| neo4j-driver-js    | frontend | 444   | Neo4j JS driver, sessions, transactions, type handling                               |
| neo4j-cypher       | global   | 433   | Cypher query patterns, performance, fraud-domain queries                             |
| neo4j-data-models  | global   | 428   | Graph modeling, fraud detection schemas, best practices                              |
| material3          | flutter  | 778   | Material 3 theming, ColorScheme, component catalog, forms, accessibility             |
| langgraph          | python   | 902   | State graphs, tool orchestration, reasoning loops, HITL, memory, streaming           |

### Skills — Stubs (need content)

| Skill               | Stack   | Lines |
| ------------------- | ------- | ----- |
| flutter             | flutter | 23    |
| testing-flutter     | flutter | 23    |
| riverpod            | flutter | 23    |
| fastapi             | python  | 18    |
| testing-pytest      | python  | 18    |
| neo4j-driver-python | python  | 18    |
| testing-rust        | rust    | 18    |
| neo4j-driver-rust   | rust    | 18    |

## Conventions

### Shell Scripts

- Shebang: `#!/usr/bin/env bash`
- First executable line: `set -euo pipefail`
- All `.sh` files must be executable (`chmod +x`)
- Quote all variables: `"$var"` not `$var`

### Naming

- Directories and files: `lowercase-kebab-case`
- Agent files: `<name>.md` in `agents/<stack>/`
- Skill files: `SKILL.md` inside `skills/<stack>/<name>/`
- Hook settings: `<stack>-settings.json` in `hooks/`
- Verify scripts: `verify-<stack>.sh` in `verify-scripts/`

### Frontmatter

- Agents require: `name`, `description`, `tools`, `model`
- Skills require: `name`, `description`
- See `agents/CLAUDE.md` and `skills/CLAUDE.md` for full format specifications

### Stacks

Five stack categories: `frontend`, `flutter`, `python`, `rust`, `global` (universal)

## Do NOT

- Add runtime dependencies — this is a template repo, not an application
- Create config files (tsconfig, eslint, vite, etc.) — those belong in downstream projects
- Use non-POSIX shell features that break on macOS (`readarray`, GNU-only `sed` flags)
- Put stack-specific content in `global/` or vice versa
- Write pseudocode in skill examples — all code blocks must be copy-pasteable
- Use `model: haiku` in agents — only `opus` and `sonnet` are valid
