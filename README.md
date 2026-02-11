# claude-agents-skills

Reusable skills, agents, and quality gates for Claude Code. Install once, get consistent AI-assisted development across every project.

## The Problem

Every time you start a new project with Claude Code, you re-teach it the same things. Your React patterns. Your testing conventions. Your Neo4j query style. It forgets between sessions. You paste the same context again. And again.

This repo fixes that.

## How It Works

**Skills** are deep reference docs for specific technologies — React 19, Tailwind v4, Neo4j Cypher, Playwright, and more. Over 7,500 lines of patterns and examples that Claude reads automatically so it writes code your way instead of generic StackOverflow way.

**Agents** are specialized workflows with distinct roles. A code reviewer that checks security and conventions. A planner that designs before coding. A test-writer and builder that coordinate through feature docs using test-first development.

**Hooks** are machine-enforced quality gates. Not suggestions — enforcement. They block `git push --force`, catch type errors on every save, and prevent task completion until the full test suite passes. Conventions you don't have to remember because the system remembers for you.

One command installs everything.

## Quick Start

```bash
# Global — symlinks universal agents + cross-stack skills to ~/.claude/
./setup.sh --global

# Per-project — copies stack-specific skills, agents, hooks, and verify scripts
cd ~/your-project
~/path/to/claude-agents-skills/setup.sh frontend

# Extras — pull in cross-stack skills (e.g., Neo4j for a Python project)
~/path/to/claude-agents-skills/setup.sh python neo4j
```

After setup, your project gets:

```
.claude/skills/       Technology reference docs Claude reads automatically
.claude/agents/       Agent definitions (test-writer, builder, reviewer, etc.)
.claude/settings.json Hooks for formatting, verification, and agent coordination
scripts/              Verify, guard, and agent teams hook scripts
feature-docs/         Lifecycle directories, CLAUDE.md guides, and example feature doc
```

## Skills

12 complete skills across frontend and global stacks, plus 5 stubs waiting for content.

| Skill | Stack | Description |
|---|---|---|
| react | frontend | Components, hooks, TypeScript, state, performance |
| testing-playwright | frontend | E2E testing, page objects, fixtures, ARIA snapshots |
| shadcn-ui | frontend | Component library, composition, theming, forms |
| nvl | frontend | Neo4j graph visualization, styling, layout |
| tailwind | frontend | Tailwind v4 CSS-first config, responsive, animations |
| zustand-state | frontend | Stores, selectors, middleware, multi-view sync |
| react-patterns | frontend | React 19 patterns, TypeScript strict, architecture |
| neo4j-driver-js | frontend | Neo4j JS driver, sessions, transactions |
| agent-teams | global | Agent Teams workflow, feature doc lifecycle, test-first coordination |
| git-workflow | global | Branching, commits, PR workflow, rebase vs merge |
| neo4j-cypher | global | Cypher query patterns, performance, fraud-domain |
| neo4j-data-models | global | Graph modeling, fraud detection schemas |

## Agents

10 agents spanning universal, frontend, Python, and Rust stacks.

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

This is the interesting part. Directly inspired by Nicholas Carlini's ["Building a C compiler with a team of parallel Claudes"](https://www.anthropic.com/engineering/building-c-compiler), Agent Teams enables parallel multi-agent development with the same core insight: **the quality of your test harness determines the quality of your output.**

Three agents coordinate through feature docs. Each has a strict role:

- **Test Writer** (sonnet) reads acceptance criteria and writes failing tests. Never touches implementation.
- **Builder** (opus) implements code until tests pass. Never modifies tests.
- **Reviewer** (code-reviewer) validates quality and conventions after all tests are green.

The separation is deliberate. When the same agent writes both tests and implementation, it writes tests its own code trivially satisfies. Splitting the roles creates genuine verification — the tests become an oracle, not a rubber stamp.

### Feature Doc Lifecycle

Features move through directories. The directory *is* the status.

```
Human explores idea      →  feature-docs/ideation/<name>/   (research, code reviews, notes)
Human distills doc       →  feature-docs/ready/             (GIVEN/WHEN/THEN criteria)
Test-writer picks up     →  feature-docs/testing/           (failing tests committed)
Builder picks up         →  feature-docs/building/          (implements until green)
Builder finishes         →  feature-docs/review/            (all tests pass)
Reviewer validates       →  feature-docs/completed/         (PR ready)
```

Source `feature-docs/new-feature.md` to start. It walks you through the full flow and can resume where you left off.

### Quality Gates

Hooks enforce conventions that humans forget. Each one maps to a lesson from autonomous agent development:

| Hook | Carlini Principle | What It Does |
|---|---|---|
| `task-completed.sh` | Testing as oracle | Blocks task completion until full verify passes (type check + lint + test) |
| `stop-hook.sh` | Fast feedback (`--fast` mode) | Runs type-check only after each response — fast iteration without waiting for full suite |
| `teammate-idle.sh` | Time blindness mitigation | Detects features stuck in `building/` for >30 min and warns you. Redirects idle agents to pending work |
| `guard-bash.sh` | Task isolation | Blocks `rm -rf /`, `git push --force`, `DROP DATABASE`. When feature-docs exist, blocks commits to main |

File ownership prevents conflicts: features declare their `affected-files`, and no agent touches files owned by another in-progress feature. Same idea as Carlini's file-locking for parallel Docker containers, applied to feature branches.

Progress lives in `feature-docs/STATUS.md`, updated by every agent after each stage. When an agent starts a new session with zero context, it reads STATUS.md and knows exactly where things stand.

## Contributing

Python and Rust skill stubs need real content. Five stubs (`fastapi`, `testing-pytest`, `neo4j-driver-python`, `testing-rust`, `neo4j-driver-rust`) are waiting in `skills/python/` and `skills/rust/`.

Skill format: [skills/CLAUDE.md](skills/CLAUDE.md) — YAML frontmatter, numbered pattern sections, anti-patterns table, copy-pasteable code examples.

Agent format: [agents/CLAUDE.md](agents/CLAUDE.md) — YAML frontmatter, role statement, process, output format, memory updates.
