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

**Step 3 (optional): vendor the engineering pack.** Five workflow skills (`implement-issue`, `epic`, `triage`, `kickoff`, `quality-gate`) plus three reviewer agents that take work from "an idea someone described" to "a merged PR behind a green gate", with no repo specifics baked in. They read one file in your repo, `.claude/PROJECT.md`, for every label, branch prefix, path and command.

```bash
~/path/to/claude-agents-skills/setup.sh --vendor ~/your-project --dry-run
~/path/to/claude-agents-skills/setup.sh --vendor ~/your-project
```

Files are **copied**, per file, never symlinked and never over a directory you own, and a `.vendored.lock` records a sha256 plus the upstream commit they came from. Full contract, manifest reference and propagation flow: [skills/engineering/README.md](skills/engineering/README.md). Consumer repos are listed in your own `consumers.txt` (gitignored, since it names private repos and local paths -- copy [consumers.txt.example](consumers.txt.example) to start one) so a fix upstream can actually be pushed out to all of them.

## Set up a new repo

`--vendor` copies the pack in but leaves you three things to remember: write `.claude/PROJECT.md`, import it from `CLAUDE.md`, and create `.claude/scripts/gate.sh`. `--bootstrap` does all three and then vendors. Run this **from inside the repo**:

```bash
git clone https://github.com/michaelkeevildown/claude-agents-skills ~/.claude-agents-skills 2>/dev/null || git -C ~/.claude-agents-skills pull --ff-only
~/.claude-agents-skills/setup.sh --bootstrap .
```

Both lines are safe whether or not you already have the clone: the `clone` fails harmlessly when the directory is there and the `pull --ff-only` brings it up to date instead. Add `--dry-run` to the second line to see everything it would do while writing nothing.

It detects your repo's real facts and prints the **evidence** for each one, so a wrong guess is visible rather than silent: `repo.slug` and `tracker` from `git remote get-url origin`, `repo.default_branch` from `origin/HEAD`, and `ui.enabled` only on real evidence of a web UI.

`gate.command` is the one where a wrong answer is dangerous rather than untidy, so it is worked out in a fixed precedence and then checked. **Your CI is read first**, in two forms:

| #   | Evidence                                                                                       | Delegate                                                                         |
| --- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| 1   | `.claude/scripts/gate.sh` already exists                                                       | left alone -- it already owns the delegate                                       |
| 2a  | a workflow CI definition (`.github/workflows/*.yml`, `.gitlab-ci.yml`, `.circleci/config.yml`) | the **union of every required job's** commands, de-duplicated, in workflow order |
| 2b  | a host-build declaration (`netlify.toml` `[build] command`, `vercel.json` `buildCommand`)      | that build -- for a site on Netlify or Vercel it is what every push is judged by |
| 3   | `scripts/verify.sh`                                                                            | `bash scripts/verify.sh`                                                         |
| 4   | a `package.json` script, `verify` > `check` > `ci` > `test:ci` > `test`                        | `npm run <it>`, else lint + the best test script                                 |
| 5-8 | `Makefile` target, `Cargo.toml`, `pyproject.toml`, `pubspec.yaml`                              | that ecosystem's standard gate                                                   |
| 9   | a verify-ish command your `.claude/settings.json` already names                                | that command                                                                     |

Rule 2 is not a guess -- it is your repo writing down what it means by green -- and **it is a union, never a pick**. A workflow with a `verify` job and a `migrations` job has two required checks, and replaying only the first certifies exactly the tree the second exists to reject. Jobs named `deploy`/`release`/`notify` are dropped (and said to be dropped); a workflow that only runs on `workflow_dispatch` or `schedule` is a button or a cron and is passed over entirely. A job that **cannot** be read confidently (a `${{ }}` expression, a heredoc, shell control flow) never disappears quietly: any repo-local `.sh` it invokes is salvaged into the gate, and the job itself comes back as a **loud TODO** naming it and why, in the summary, in the shim header and in `PROJECT.md`. A job that needs a database or a service container is read too -- its infrastructure is recorded as a **prerequisite** rather than pretended into coverage.

Whatever it lands on is then put through a **completeness check** against the checks your repo evidently has. A repo with a `tsconfig.json` must compile inside its gate. A repo that produces a build artefact -- a `build` script plus a framework config (astro/next/nuxt/vite/sveltekit) -- must **build** inside it, because a gate that type-checks but never builds is not a gate for a site that has to build. Missing legs are composed on, and where that cannot be done safely the whole candidate is **thrown away** in favour of a TODO. That is the point: a gate that never compiles reports **green on a tree with a type error**, and every caller downstream reads a 0 as proof. It also refuses watch-mode commands (a gate that never exits is a hang, not a gate), and warns when your delegate script uses `exit 2`, which collides with the pack's could-not-run code.

One exit code is normalised rather than warned about: **`tsc`'s 2**. `tsc --noEmit` exits 2 on a cold run of an incremental project (writing the `.tsbuildinfo` counts as generating output) and 1 once that cache is warm -- and the cache is gitignored, so cold is the default state of a fresh clone. Both mean diagnostics were present, i.e. red, so any leg bootstrap can see _is_ tsc gets its 2 folded onto 1 in the generated shim. Only those legs: a third-party delegate's 2 is left alone, because there it may really mean it could not run.

Anything it cannot detect becomes a loud **TODO** rather than a guess, and if it cannot work out your gate command the scaffolded `gate.sh` **exits 2 (could-not-run), never 0** -- a stub that reported green would be the worst possible failure here. Every step is idempotent: an existing `PROJECT.md`, `gate.sh` or `CLAUDE.md` import is left exactly as it is and reported as skipped.

Then **restart Claude Code**: the agent registry is read at boot, so a freshly vendored reviewer agent is not spawnable until you do.

## What You Get: Day-to-Day Usage

### Skills make Claude write code your way

Without skills, Claude writes generic React. With the `react` skill loaded, it writes React 19 with your TypeScript patterns, your hook conventions, your error handling style. Same for Tailwind v4, Playwright testing, Zustand stores, shadcn/ui components — 12 skills, over 7,000 lines of patterns and examples.

You don't reference skills manually. Claude reads them automatically when they're relevant.

<details>
<summary>All 12 skills (+ 5 stubs)</summary>

| Skill              | Stack    | What it teaches Claude                                     |
| ------------------ | -------- | ---------------------------------------------------------- |
| react              | frontend | Components, hooks, TypeScript, state, performance          |
| testing-playwright | frontend | E2E testing, page objects, fixtures, ARIA snapshots        |
| shadcn-ui          | frontend | Component composition, theming, forms                      |
| nvl                | frontend | Neo4j graph visualization, styling, layout                 |
| tailwind           | frontend | Tailwind v4 CSS-first config, responsive, animations       |
| zustand-state      | frontend | Stores, selectors, middleware, multi-view sync             |
| react-patterns     | frontend | React 19 patterns, TypeScript strict, architecture         |
| neo4j-driver-js    | frontend | Neo4j JS driver, sessions, transactions                    |
| agent-teams        | global   | Multi-agent workflow, feature doc lifecycle                |
| issue-authoring    | global   | Implementable GitHub Issues, GIVEN/WHEN/THEN, epic linkage |
| git-workflow       | global   | Branching, commits, PR workflow, rebase vs merge           |
| neo4j-cypher       | global   | Cypher query patterns, performance, fraud-domain           |
| neo4j-data-models  | global   | Graph modeling, fraud detection schemas                    |

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

| What happens                           | Why                                                                                                       |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Fast type-check after every response   | Same idea as Carlini's `--fast` flag — quick feedback during iteration without waiting for the full suite |
| Full verify on task completion         | Tests are the oracle. No agent finishes until type check + lint + tests all pass                          |
| Stuck detection after 30 min           | LLMs can't track time. If a feature is stuck in building, you get a warning                               |
| Idle agents redirected to pending work | When an agent finishes, it picks up the next feature doc automatically                                    |
| File ownership per feature             | Like Carlini's file-locking for parallel Docker containers — agents don't step on each other's files      |

Progress lives in `feature-docs/STATUS.md`, updated after every stage. When an agent starts fresh with zero context, it reads STATUS.md and knows exactly where things stand.

Already have a feature doc from a previous session? Source `feature-docs/implement-feature.md` to pick it up and resume.

## Contributing

Five skill stubs need real content — `fastapi`, `testing-pytest`, `neo4j-driver-python`, `testing-rust`, `neo4j-driver-rust` in `skills/python/` and `skills/rust/`.

Skill format: [skills/CLAUDE.md](skills/CLAUDE.md). Agent format: [agents/CLAUDE.md](agents/CLAUDE.md).
