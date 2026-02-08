# claude-agents-skills

Reusable skills and agents for Claude Code. Install once, get consistent AI-assisted development across every project.

## Why This Exists

Every time you start a new project with Claude Code, you re-teach it the same things — your React patterns, your testing conventions, your Neo4j query style. It forgets between sessions. You paste the same context over and over.

This repo fixes that. It packages technology knowledge as **skills** and development workflows as **agents** that you install globally or per-project with a single command.

## How It Works

**Skills** are deep reference docs for specific technologies (React 19, Tailwind v4, Neo4j Cypher, etc.). Claude reads them automatically and writes code that follows your patterns instead of generic ones.

**Agents** are specialized workflows — a code reviewer that checks security and conventions, a planner that designs before coding, a frontend engineer that knows your component architecture.

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

## What's Included

### Skills

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
| git-workflow | global | Branching, commits, PR workflow, rebase vs merge |
| neo4j-cypher | global | Cypher query patterns, performance, fraud-domain |
| neo4j-data-models | global | Graph modeling, fraud detection schemas |

### Agents

| Agent | Stack | Model | Description |
|---|---|---|---|
| code-reviewer | universal | opus | Security, error handling, convention checks |
| planner | universal | sonnet | Implementation planning before coding |
| frontend-engineer | frontend | opus | UI review, React optimization, component scaffolding |
| component-builder | frontend | sonnet | Investigation workspace components |

## Contributing

Python and Rust stubs exist in `skills/python/` and `skills/rust/` and need real content. The format is documented in [skills/CLAUDE.md](skills/CLAUDE.md) — each skill is a `SKILL.md` with YAML frontmatter, numbered pattern sections, and an anti-patterns table.
