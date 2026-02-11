# claude-agents-skills

Reusable skills and agents for Claude Code. Install once, get consistent AI-assisted development across every project.

## Why This Exists

Every time you start a new project with Claude Code, you re-teach it the same things — your React patterns, your testing conventions, your Neo4j query style. It forgets between sessions. You paste the same context over and over.

This repo fixes that. It packages technology knowledge as **skills** and development workflows as **agents** that you install globally or per-project with a single command.

## How It Works

**Skills** are deep reference docs for specific technologies (React 19, Tailwind v4, Neo4j Cypher, etc.). Claude reads them automatically and writes code that follows your patterns instead of generic ones.

**Agents** are specialized workflows — a code reviewer that checks security and conventions, a planner that designs before coding, a test-writer and builder that coordinate via feature docs.

**Agent Teams** enables parallel multi-agent development. A test-writer writes failing tests from feature docs, a builder implements until tests pass, and a reviewer validates quality. Hook-based quality gates prevent broken code from shipping.

**One command** installs everything. Global content is symlinked (updates propagate). Project content is copied (customizable per-project).

## Quick Start

```bash
# Global — installs universal agents + cross-stack skills to ~/.claude/
./setup.sh --global

# Per-project — installs stack-specific skills, agents, hooks, and verify script
cd ~/your-project
~/path/to/claude-agents-skills/setup.sh frontend

# Extras — add cross-stack skills (e.g., Neo4j for a Python project)
~/path/to/claude-agents-skills/setup.sh python neo4j
```

After setup, your project gets:
- `.claude/skills/` — technology reference docs
- `.claude/agents/` — agent definitions (test-writer, builder, etc.)
- `.claude/settings.json` — hooks for formatting, verification, and agent teams
- `scripts/` — verify, guard, and agent teams hook scripts
- `feature-docs/` — lifecycle directories with CLAUDE.md guides, `new-feature.md` entry point, and example feature doc

## What's Included

### Skills

| Skill | Stack | Description |
|---|---|---|
| agent-teams | global | Agent Teams workflow, feature doc lifecycle, test-first coordination |
| git-workflow | global | Branching, commits, PR workflow, rebase vs merge |
| neo4j-cypher | global | Cypher query patterns, performance, fraud-domain |
| neo4j-data-models | global | Graph modeling, fraud detection schemas |
| react | frontend | Components, hooks, TypeScript, state, performance |
| testing-playwright | frontend | E2E testing, page objects, fixtures, ARIA snapshots |
| shadcn-ui | frontend | Component library, composition, theming, forms |
| nvl | frontend | Neo4j graph visualization, styling, layout |
| tailwind | frontend | Tailwind v4 CSS-first config, responsive, animations |
| zustand-state | frontend | Stores, selectors, middleware, multi-view sync |
| react-patterns | frontend | React 19 patterns, TypeScript strict, architecture |
| neo4j-driver-js | frontend | Neo4j JS driver, sessions, transactions |

### Agents

| Agent | Stack | Model | Description |
|---|---|---|---|
| code-reviewer | universal | opus | Security, error handling, convention checks |
| planner | universal | sonnet | Implementation planning before coding |
| frontend-engineer | frontend | opus | UI review, React optimization, component scaffolding |
| component-builder | frontend | sonnet | Investigation workspace components |
| test-writer | frontend | sonnet | Write failing Vitest/Playwright tests from feature docs |
| builder | frontend | opus | Implement code to make failing tests pass |
| test-writer | python | sonnet | Write failing pytest tests from feature docs |
| builder | python | opus | Implement code to make failing pytest tests pass |
| test-writer | rust | sonnet | Write failing cargo tests from feature docs |
| builder | rust | opus | Implement code to make failing cargo tests pass |

## Agent Teams

A parallel multi-agent workflow adapted from Anthropic's ["Building a C compiler with a team of parallel Claudes"](https://www.anthropic.com/engineering/building-c-compiler). Three roles coordinate via feature docs:

1. **Test Writer** (sonnet) — reads feature doc acceptance criteria, writes failing tests
2. **Builder** (opus) — implements code until all tests pass, never modifies tests
3. **Reviewer** (code-reviewer) — validates code quality, conventions, and completeness

### Feature Doc Lifecycle

```
Human explores idea      →  feature-docs/ideation/<name>/   (research, code reviews, notes)
Human distills doc       →  feature-docs/ready/             (GIVEN/WHEN/THEN criteria)
Test-writer picks up     →  feature-docs/testing/           (failing tests committed)
Builder picks up         →  feature-docs/building/          (implements until green)
Builder finishes         →  feature-docs/review/            (all tests pass)
Reviewer validates       →  feature-docs/completed/         (PR ready)
```

Source `feature-docs/new-feature.md` to start — it walks you through the full flow, tracks progress, and can resume where you left off. If you already know what you want, choose "skip to feature doc" when prompted to go straight to `ready/`.

### Hooks

| Hook | Event | Purpose |
|---|---|---|
| guard-bash.sh | PreToolUse | Block dangerous commands + branch protection on main |
| prettier/black/rustfmt | PostToolUse | Auto-format after every edit |
| verify.sh | Stop | Type-check + lint + test after every response |
| task-completed.sh | TaskCompleted | Block task completion until verify passes |
| teammate-idle.sh | TeammateIdle | Redirect idle agents to pending feature docs |

See the [agent-teams skill](skills/global/agent-teams/SKILL.md) for the full workflow documentation, coordination protocol, and anti-patterns.

## Contributing

Python and Rust skill stubs exist in `skills/python/` and `skills/rust/` and need real content. The format is documented in [skills/CLAUDE.md](skills/CLAUDE.md) — each skill is a `SKILL.md` with YAML frontmatter, numbered pattern sections, and an anti-patterns table.

Agent definitions follow the format in [agents/CLAUDE.md](agents/CLAUDE.md) — YAML frontmatter with name, description, tools, and model, followed by role statement, process, output format, and memory updates.
