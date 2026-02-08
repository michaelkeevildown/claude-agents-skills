# Agent Conventions

## File Format

Agents are Markdown files with YAML frontmatter, placed in a stack subdirectory:
`agents/<stack>/<name>.md`

## Required Frontmatter

```yaml
---
name: kebab-case-name          # Must match filename without .md
description: Role sentence. Triggers on keyword1, keyword2, keyword3.
tools: Read, Grep, Glob, Bash  # Comma-separated Claude Code tools
model: opus                    # opus or sonnet (see guidance below)
---
```

### Optional Frontmatter

```yaml
memory: user                   # Persistent memory across sessions
```

### Field Details

**name** — lowercase-kebab-case, matches the filename (e.g., `code-reviewer` for `code-reviewer.md`)

**description** — One sentence stating the role, followed by trigger phrases. Format:
`<Role description>. Triggers on <comma-separated keywords>.`
Triggers tell Claude when to invoke this agent. Include action verbs users would say.

**tools** — Comma-separated list of Claude Code tools the agent needs:
- Read-only agents: `Read, Grep, Glob, Bash`
- Write agents: `Read, Grep, Glob, Bash, Write, Edit`
- Research agents may add: `WebFetch, WebSearch`

**model** — Which Claude model to use:
- `opus` — Complex review, analysis, multi-step reasoning, quality-critical tasks
- `sonnet` — Planning, scaffolding, checklist-driven work, high-throughput tasks

## Body Structure

Every agent body follows this order:

### 1. Role Statement
One sentence: "You are a [role]. Your job is to [primary function]."

### 2. Before You Start
Context-gathering steps the agent runs before its main task:
1. Check agent memory for patterns from previous sessions
2. Read the project's root CLAUDE.md
3. Read subdirectory CLAUDE.md files relevant to the task
4. Scan `.claude/skills/` for relevant skills
5. Read `scripts/verify.sh` if it exists

### 3. Process / Workflow
The main operational section. Single-workflow agents use `## Process`. Multi-workflow agents use:
- `## Workflow Selection` — how to choose which workflow
- `## Workflow N: Name` — each workflow with its own process and checklist

### 4. Output Format
What the agent produces. Use a fenced code block to show the format template.

### 5. Memory Updates
What to persist after each task. Always include:
- Patterns discovered
- Common issues found
- Project-specific conventions not in CLAUDE.md
Keep entries concise — one line per pattern, deduplicate with existing entries.

## Directory Placement

| Directory | When to use | Installed by |
|---|---|---|
| `universal/` | Stack-independent agents | `./setup.sh --global` |
| `frontend/` | Frontend-specific agents | `./setup.sh frontend` |
| `python/` | Python-specific agents | `./setup.sh python` |
| `rust/` | Rust-specific agents | `./setup.sh rust` |

## Existing Agents

| File | Model | Tools | Workflows |
|---|---|---|---|
| `universal/code-reviewer.md` | opus | Read, Grep, Glob, Bash | 1 (review checklist) |
| `universal/planner.md` | sonnet | Read, Grep, Glob, Bash | 1 (structured plan) |
| `frontend/frontend-engineer.md` | opus | Read, Grep, Glob, Bash, Write, Edit | 3 (UI review, optimize, scaffold) |
| `frontend/component-builder.md` | sonnet | Read, Grep, Glob, Bash, Write, Edit | 1 (investigation components) |
