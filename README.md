# claude-agents-skills

You know how every new project with Claude Code starts the same way? You re-explain your React patterns. Re-paste your testing conventions. Re-describe how you like your Neo4j queries. Session after session, project after project.

This repo is a portable brain for Claude Code. Install it once and Claude already knows your stack, follows your conventions, and coordinates multi-agent workflows — across every project.

## Setup (2 minutes)

**Step 1: Install the global stuff.** Universal agents (code-reviewer, planner) and cross-stack skills (git workflow, Neo4j, agent teams) get symlinked to `~/.claude/` so they're available everywhere and stay in sync with this repo.

```bash
./setup.sh --global
```

**Step 2: Set up a project.** Stack-specific skills, agents, hooks, and verify scripts get copied into your project (so you can customize them per-project).

```bash
cd ~/your-project
~/path/to/claude-agents-skills/setup.sh frontend    # or python, or rust
```

Need Neo4j skills in a Python project? Add extras:

```bash
~/path/to/claude-agents-skills/setup.sh python neo4j
```

That's it. Your project now has skills in `.claude/skills/`, agents in `.claude/agents/`, hooks in `.claude/settings.json`, and verify scripts in `scripts/`. Open Claude Code and everything is loaded automatically.

## What You Get: Day-to-Day Usage

### Skills make Claude write code your way

Without skills, Claude writes generic React. With the `react` skill loaded, it writes React 19 with your TypeScript patterns, your hook conventions, your error handling style. Same for Tailwind v4, Playwright testing, Zustand stores, shadcn/ui components — 12 skills, over 7,000 lines of patterns and examples.

You don't reference skills manually. Claude reads them automatically when they're relevant.

<details>
<summary>All 12 skills (+ 5 stubs)</summary>

| Skill | Stack | What it teaches Claude |
|---|---|---|
| react | frontend | Components, hooks, TypeScript, state, performance |
| testing-playwright | frontend | E2E testing, page objects, fixtures, ARIA snapshots |
| shadcn-ui | frontend | Component composition, theming, forms |
| nvl | frontend | Neo4j graph visualization, styling, layout |
| tailwind | frontend | Tailwind v4 CSS-first config, responsive, animations |
| zustand-state | frontend | Stores, selectors, middleware, multi-view sync |
| react-patterns | frontend | React 19 patterns, TypeScript strict, architecture |
| neo4j-driver-js | frontend | Neo4j JS driver, sessions, transactions |
| agent-teams | global | Multi-agent workflow, feature doc lifecycle |
| git-workflow | global | Branching, commits, PR workflow, rebase vs merge |
| neo4j-cypher | global | Cypher query patterns, performance, fraud-domain |
| neo4j-data-models | global | Graph modeling, fraud detection schemas |

Stubs waiting for content: `fastapi`, `testing-pytest`, `neo4j-driver-python`, `testing-rust`, `neo4j-driver-rust`

</details>

### Agents give Claude specialized roles

Instead of one Claude doing everything, agents split the work:

- **code-reviewer** (opus) — reviews your code for security issues, error handling gaps, and convention violations
- **planner** (sonnet) — designs implementation before anyone writes code
- **test-writer** (sonnet) — writes failing tests from feature doc acceptance criteria
- **builder** (opus) — implements code until those tests pass

These exist for frontend (Vitest/Playwright), Python (pytest), and Rust (cargo test).

### Hooks enforce your conventions automatically

This is where it gets interesting. Hooks aren't reminders — they're gates. They run automatically and block bad things from happening:

- **Every file you edit** gets auto-formatted (Prettier, Black, or rustfmt)
- **Every response** triggers a fast type-check so you catch errors immediately
- **Every task completion** runs the full suite — type check, lint, tests. If anything fails, the task doesn't complete
- **Dangerous commands** like `rm -rf /`, `git push --force`, and `DROP DATABASE` are blocked before they execute

You never have to remember to run the linter. The system runs it for you.

## Agent Teams: The Interesting Part

This is directly inspired by Nicholas Carlini's ["Building a C compiler with a team of parallel Claudes"](https://www.anthropic.com/engineering/building-c-compiler). The core insight: **the quality of your test harness determines the quality of your output.** If the same agent writes both tests and implementation, it writes tests its own code trivially satisfies. Split the roles and the tests become a real oracle.

Here's the full flow:

### 1. You describe what you want

Source the entry point and describe your feature. You can start with rough exploration (ideation) or jump straight to a structured feature doc with GIVEN/WHEN/THEN acceptance criteria.

```bash
# In Claude Code:
# Source feature-docs/new-feature.md
```

Your feature doc lands in `feature-docs/ready/`.

### 2. Test-writer writes failing tests

A sonnet agent picks up your feature doc, reads the acceptance criteria, and writes tests that fail. It commits them and moves the doc to `feature-docs/testing/`. This agent never touches implementation code.

### 3. Builder makes the tests pass

An opus agent picks up the failing tests and implements until everything is green. It moves the doc to `feature-docs/review/`. This agent never modifies tests.

### 4. Reviewer checks the work

The code-reviewer agent validates quality, conventions, and completeness. If it passes, the doc moves to `feature-docs/completed/` and you've got a PR-ready feature.

### 5. Hooks keep everyone honest

Behind the scenes, quality gates from the Carlini playbook are running:

| What happens | Why |
|---|---|
| Fast type-check after every response | Same idea as Carlini's `--fast` flag — quick feedback during iteration without waiting for the full suite |
| Full verify on task completion | Tests are the oracle. No agent finishes until type check + lint + tests all pass |
| Stuck detection after 30 min | LLMs can't track time. If a feature is stuck in building, you get a warning |
| Idle agents redirected to pending work | When an agent finishes, it picks up the next feature doc automatically |
| File ownership per feature | Like Carlini's file-locking for parallel Docker containers — agents don't step on each other's files |

Progress lives in `feature-docs/STATUS.md`, updated after every stage. When an agent starts fresh with zero context, it reads STATUS.md and knows exactly where things stand.

Already have a feature doc from a previous session? Source `feature-docs/implement-feature.md` to pick it up and resume.

## Contributing

Five skill stubs need real content — `fastapi`, `testing-pytest`, `neo4j-driver-python`, `testing-rust`, `neo4j-driver-rust` in `skills/python/` and `skills/rust/`.

Skill format: [skills/CLAUDE.md](skills/CLAUDE.md). Agent format: [agents/CLAUDE.md](agents/CLAUDE.md).
