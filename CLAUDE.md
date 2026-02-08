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
  python/         Python-specific agents (empty — needs contributors)
  rust/           Rust-specific agents (empty — needs contributors)
skills/           Technology skill documentation (SKILL.md files)
  global/         Stack-independent skills (symlinked to ~/.claude/skills/)
  frontend/       Frontend skills (8 skills)
  python/         Python skills (3 stubs)
  rust/           Rust skills (2 stubs)
hooks/            .claude/settings.json templates per stack
verify-scripts/   Stack-specific verify scripts (type-check → lint → test)
setup.sh          Installer: ./setup.sh --global | ./setup.sh <stack> [extras]
```

## Setup

```bash
./setup.sh --global              # Symlink universal agents + global skills to ~/.claude/
./setup.sh frontend              # Copy frontend skills/agents into current project
./setup.sh python neo4j          # Python stack + neo4j extras
```

## Content Inventory

### Agents

| Agent | Stack | Model | Lines | Description |
|---|---|---|---|---|
| code-reviewer | universal | opus | 75 | Code review with security, error handling, convention checks |
| planner | universal | sonnet | 88 | Implementation planning before coding |
| frontend-engineer | frontend | opus | 157 | UI review, React optimization, component scaffolding (3 workflows) |
| component-builder | frontend | sonnet | 146 | Investigation workspace components with Zustand/NVL integration |

### Skills — Complete

| Skill | Stack | Lines | Description |
|---|---|---|---|
| react | frontend | 940 | Components, hooks, TypeScript, state, performance, error handling |
| testing-playwright | frontend | 881 | E2E testing, page objects, fixtures, ARIA snapshots |
| shadcn-ui | frontend | 733 | Component library, composition, theming, forms |
| nvl | frontend | 685 | Neo4j Visualization Library, graph rendering, styling, layout |
| tailwind | frontend | 659 | Tailwind v4 CSS-first config, responsive, animations |
| git-workflow | global | 579 | Branching, commits, PR workflow, rebase vs merge |
| zustand-state | frontend | 521 | Stores, selectors, middleware, multi-view sync |
| react-patterns | frontend | 472 | React 19 patterns, TypeScript strict, architecture |
| neo4j-driver-js | frontend | 444 | Neo4j JS driver, sessions, transactions, type handling |
| neo4j-cypher | global | 433 | Cypher query patterns, performance, fraud-domain queries |
| neo4j-data-models | global | 428 | Graph modeling, fraud detection schemas, best practices |

### Skills — Stubs (need content)

| Skill | Stack | Lines |
|---|---|---|
| fastapi | python | 18 |
| testing-pytest | python | 18 |
| neo4j-driver-python | python | 18 |
| testing-rust | rust | 18 |
| neo4j-driver-rust | rust | 18 |

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
Four stack categories: `frontend`, `python`, `rust`, `global` (universal)

## Do NOT

- Add runtime dependencies — this is a template repo, not an application
- Create config files (tsconfig, eslint, vite, etc.) — those belong in downstream projects
- Use non-POSIX shell features that break on macOS (`readarray`, GNU-only `sed` flags)
- Put stack-specific content in `global/` or vice versa
- Write pseudocode in skill examples — all code blocks must be copy-pasteable
- Use `model: haiku` in agents — only `opus` and `sonnet` are valid
