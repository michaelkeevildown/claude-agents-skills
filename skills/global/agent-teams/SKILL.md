---
name: agent-teams
description: Agent Teams workflow — parallel multi-agent development with test-first coordination, feature doc lifecycle, file ownership, and quality gates.
---

# Agent Teams Workflow

## When to Use

Use this skill when coordinating multiple Claude Code agents to implement features
in parallel using the Agent Teams feature. Covers:

- Feature doc format and lifecycle (ready → testing → building → review → done)
- Three-role separation: test-writer, builder, reviewer
- File ownership rules to prevent conflicts
- Hook-based quality gates (TaskCompleted, TeammateIdle, Stop)
- Fast verification for rapid feedback, full verification for completion gates
- Progress dashboard (`feature-docs/STATUS.md`) for zero-context recovery
- Stuck detection and time blindness mitigation
- Coordination protocol with kickoff prompts
- Bootstrap and retrofit prompts for new and existing projects

Defer to other skills for:
- **git-workflow skill**: Branch naming, commit message conventions, PR creation
- **testing-playwright skill**: Frontend E2E test patterns (Playwright-specific)
- **testing-pytest skill**: Python test patterns (pytest-specific)
- **testing-rust skill**: Rust test patterns (cargo test-specific)

This workflow is adapted from Anthropic's ["Building a C compiler with a team of
parallel Claudes"](https://www.anthropic.com/engineering/building-c-compiler)
(Feb 2026). The key insight: **the quality of the testing harness determines
the quality of the output**.

## 1. Core Principles

### Tests as Oracle

The test-writer agent reads feature docs and writes **failing** tests. The builder
agent implements code to make those tests pass. Nobody grades their own homework —
the agent that writes tests never writes implementation, and the agent that
implements never modifies tests.

When agents write both tests and code, they optimise for making tests pass rather
than meeting the spec. They write weak tests their implementation trivially
satisfies. Separation prevents this.

### Minimal Context Pollution

LLMs degrade as context fills with irrelevant information. Every hook and agent
instruction is designed to produce minimal, structured output:

- Test results print summary lines only, not full stack traces
- Errors use a consistent format: `ERROR [CATEGORY]: one-line description`
- Verbose output goes to `agent_logs/`, never to stdout
- `scripts/verify.sh` logs full output to `agent_logs/` and pipes through `tail -10`
- Agent test commands use quiet reporters (`-q`, no `--reporter=verbose`)
- Stop hook truncates output to 20 lines

### Fast Verification

The Stop hook runs `scripts/fast-verify.sh` (type check only) on every response
where files changed. This catches type errors quickly without running the full
suite. The full verify pipeline (`scripts/verify.sh`) runs only on TaskCompleted.

This mirrors Carlini's `--fast` mode: quick smoke checks during work,
comprehensive validation only at completion gates.

### Time Blindness Mitigation

LLMs cannot self-regulate time. The `TeammateIdle` hook detects features stuck
in `building/` for over 30 minutes (using file modification time) and warns the
user. This prevents agents from spinning indefinitely on hard problems.

### Progress Dashboard

Agents start each session with zero context. `feature-docs/STATUS.md` is updated
by every agent after each stage transition. It shows what's in flight, what's
blocked, and what's done — enabling any agent to orient quickly.

### File Ownership

Feature docs declare which files each feature affects. No agent touches files
owned by another in-progress feature. This prevents the problem Carlini identified:
agents hitting the same bug, fixing it, and overwriting each other's changes.

Ownership is convention-based (declared in feature doc frontmatter), not
technically enforced. Agents must check `feature-docs/testing/` and
`feature-docs/building/` for overlapping `affected-files` before starting work.

### CI as Regression Gate

The `TaskCompleted` hook runs the full verify pipeline (`scripts/verify.sh`)
before any task can be marked done. An agent cannot ship code that breaks existing
tests. This is enforced at the hook level (deterministic) rather than in prompts
(probabilistic).

### Human-in-the-Loop for Subjective Work

Tests verify functional correctness, but some decisions are subjective. For
frontend projects, visual/style work requires human review loops with screenshots.
The workflow splits into:

- **Feature work**: Fully autonomous. Human writes spec, agents handle
  test → implement → review.
- **Style work** (frontend only): Human-in-the-loop. Agent makes changes,
  generates screenshots, pauses for human feedback. Approved screenshots become
  visual regression baselines.

## 2. Ideation Phase (Pre-Ready)

Before a feature enters the agent pipeline, it goes through an ideation phase where
the human explores, researches, and shapes the idea. Source `feature-docs/new-feature.md`
to start (or resume) the guided workflow.

Ideation happens in `feature-docs/ideation/` with one subfolder per feature:

```
feature-docs/ideation/
  CLAUDE.md               # Auto-discovered guide for all ideation folders
  001-user-auth/
    README.md             # Status tracking + progress log
    code-review.md        # Analysis of existing code to change
    api-research.md       # How other projects solve this
    design-notes.md       # Data flow, component tree, schema
    spike-results.md      # Quick experiments
  002-cart-redesign/
    README.md
    current-analysis.md
    competitor-notes.md
```

### Starting or Resuming Ideation

Source `feature-docs/new-feature.md` — it handles both cases:

- **New feature**: Asks what you want to build, creates the ideation folder, walks
  you through validation (code review, research, design), saves artifacts as you go
- **Resume**: Scans for folders with `status: in-progress`, reads all artifacts,
  summarises where you left off, continues from open questions

### Status Tracking

Each ideation folder's `README.md` has YAML frontmatter:

```yaml
---
feature: user-auth
status: in-progress        # or: complete, shipped
created: 2025-01-15
---
```

The `## Progress` section tracks dated entries across sessions:

```markdown
### 2025-01-15 — Initial exploration
- **What we did**: Reviewed existing auth code, identified session management gap
- **Decisions made**: Use httpOnly cookies, not localStorage
- **Open questions**: Which OAuth provider to use later?

### 2025-01-16 — API design
- **What we did**: Designed login/logout endpoints, drafted store structure
- **Decisions made**: Separate auth store from user profile store
- **Open questions**: How to handle token refresh?
```

### What Goes in an Ideation Folder

There are no format rules — use whatever helps you think:

- **Code reviews** — Analysis of existing code the feature will touch
- **Research notes** — API docs, how other projects solve this, trade-offs
- **Design sketches** — Data flow diagrams, component trees, schema changes
- **Spike results** — Quick experiments to validate an approach
- **Conversation logs** — Key decisions and reasoning from Claude sessions

### Distilling into a Feature Doc

When the feature is clear enough to write testable acceptance criteria, say
"create the feature" during your ideation session. The prompt will:

1. Read all files in the ideation folder
2. Synthesise the summary from across all artifacts
3. Extract testable behaviours as GIVEN/WHEN/THEN acceptance criteria
4. Identify affected files from code reviews and design notes
5. Flag gaps (missing error cases, unresolved decisions, no affected files)
6. Save the final doc to `feature-docs/ready/<feature-name>.md`
7. Set `ideation-ref` in the feature doc frontmatter pointing back to the ideation folder
8. Update the ideation README status to `complete`

The ideation folder stays as an archive. Agents never read ideation folders — only
the distilled feature doc in `ready/`. The `ideation-ref` field lets agents optionally
check the ideation folder for additional context.

When the feature later completes the full pipeline (reviewer approves, doc moves to
`completed/`), the coordinator updates the ideation README status from `complete` to
`shipped` and appends a final progress entry noting pipeline completion. This is handled
by the coordinator's "After reviewer approves" checklist in `implement-feature.md`.

Alternatively, if you already know what you want and want to skip ideation, source
`feature-docs/new-feature.md` and choose "skip to feature doc" when prompted — it
handles both paths (ideation and direct creation) from a single entry point.

## 3. Feature Doc Format

Feature docs live in `feature-docs/` with subdirectories for each lifecycle stage.
Create this directory structure in your project:

```
feature-docs/
  ideation/           # Human explores and shapes ideas here
  ready/              # Distilled feature doc goes here
  testing/            # Test-writer moves doc here
  building/           # Builder moves doc here
  review/             # Builder moves doc here when tests pass
  completed/          # Reviewer moves doc here when done
```

### Template

```markdown
---
title: User Authentication
status: ready
priority: high
affected-files:
  - src/auth/authenticate.ts
  - src/auth/session.ts
  - src/stores/auth-store.ts
  - src/components/login-form.tsx
---

# User Authentication

## Summary

Add email/password login with session management. Users can log in, stay
authenticated across page reloads, and log out.

## Acceptance Criteria

1. GIVEN a valid email and password WHEN `authenticate(email, password)` is called
   THEN it returns a `Session` with a non-null `token` and `expiresAt` > now
2. GIVEN an email with no matching user WHEN `authenticate(email, password)` is
   called THEN it throws `AuthenticationError` with code `"INVALID_CREDENTIALS"`
3. GIVEN `authStore.getState().isAuthenticated` is `true` WHEN `logout()` is called
   THEN `authStore.getState().session` is `null` and the session cookie is cleared
4. GIVEN a session cookie with a valid token WHEN `restoreSession()` is called
   THEN `authStore.getState().isAuthenticated` is `true`
5. GIVEN a session cookie with an expired token WHEN `restoreSession()` is called
   THEN `authStore.getState().session` is `null` and the cookie is cleared

## Edge Cases

- Empty email or password to `authenticate()` — throws `ValidationError` with
  code `"EMPTY_FIELD"` before any network request
- Session cookie with malformed JSON — `restoreSession()` clears the cookie
  silently without throwing

## Out of Scope

- OAuth/social login (separate feature) — do NOT add OAuth types to `Session`
- Do NOT touch `src/api/client.ts` interceptor (has a `TODO: add auth` comment;
  leave as-is to avoid breaking existing API calls)

## Technical Notes

- Session token uses httpOnly cookie, not localStorage
- **Rejected**: localStorage with encryption wrapper — XSS-accessible, no real
  protection. httpOnly cookies are invisible to JS entirely.
```

### Acceptance Criteria Rules

Every acceptance criterion must be:

1. **Testable** — can be verified by an automated test
2. **Specific** — names exact functions, fields, error types, and return values
3. **Independent** — does not depend on other criteria passing first
4. **Complete** — covers the happy path, error cases, and edge cases

Vague criteria produce vague tests produce wrong implementations.

| Vague (agent has to guess) | Precise (agent can write a test) |
|---|---|
| THEN the login works | THEN `authenticate()` returns a `Session` with non-null `token` |
| THEN an error is shown | THEN it throws `AuthenticationError` with code `"INVALID_CREDENTIALS"` |
| THEN the data is saved | THEN `authStore.getState().session` contains the `Session` |
| THEN the field is removed | THEN the returned object does NOT include a `legacyField` key |

## 4. Agent Roles

### Test Writer

**Purpose**: Read feature docs and produce failing tests that serve as the
implementation oracle.

**Reads**: Feature doc from `feature-docs/ready/`

**Produces**: Test files that fail (all tests must fail before handing off to builder)

**Constraints**:
- Never writes implementation code — only test files
- Tests must import from the implementation path even though the file may not exist yet
- Each acceptance criterion produces at least one test
- Edge cases from the feature doc produce additional tests
- Commits tests with `test(<scope>): add failing tests for <feature-name>`

**Stack-specific patterns**:
- Frontend: Vitest for unit/integration, Playwright for E2E
- Python: pytest with fixtures and parametrize
- Rust: `#[test]` in module, integration tests in `tests/`

### Builder

**Purpose**: Write implementation code that makes all failing tests pass.

**Reads**: Feature doc from `feature-docs/testing/`, failing test files

**Produces**: Implementation code that makes all tests pass

**Constraints**:
- Never modifies test files — if tests are wrong, stop and report to the user
- Must run `scripts/verify.sh` after each significant implementation step
- Only touches files listed in the feature doc's `affected-files`
- Commits implementation with `feat(<scope>): implement <feature-name>`

**Stack-specific patterns**:
- Frontend: React components, Zustand stores, API handlers
- Python: FastAPI routes, services, Pydantic models, database queries
- Rust: Modules, traits, impls, error types

### Reviewer

**Purpose**: Catch what tests cannot — code quality, convention adherence,
design system consistency, and qualitative issues.

**Maps to**: The existing `code-reviewer` universal agent, extended with
agent-teams awareness.

**Checks**:
- Code follows project conventions (CLAUDE.md rules)
- No duplicate logic introduced
- Error handling is complete
- Types are correct and specific (no `any`, no `unwrap` in production paths)
- Component library used correctly (shadcn for frontend, idiomatic patterns for backend)
- Feature doc acceptance criteria all have corresponding tests
- Tests actually validate the criteria (not just trivially passing)

**Produces**: Review report. If issues found, status stays at `review`.
If approved, reviewer moves doc to `feature-docs/completed/`.

**Constraints**:
- Strictly read-only — never edits implementation or test files
- Never uses Bash to modify files (`sed -i`, `echo >`, etc.)
- Reports issues to the coordinator; the coordinator routes fixes to the appropriate agent
- Independence is the reviewer's value — if the reviewer fixes code, it cannot objectively review it

### Coordinator

**Purpose**: Orchestrate the pipeline — scan for work, run pre-flight checks,
invoke agents, verify lifecycle compliance between stages, and manage the
progress dashboard. The coordinator never writes implementation or test code.

**Identity**: The main Claude Code session that sources `implement-feature.md`.
Unlike the other roles, the coordinator is not a named agent with restricted
tools — it has full tool access by default. These constraints are self-imposed
through prompt instructions.

**Reads**: Feature docs (all directories), STATUS.md, verify output, agent reports

**Produces**: Agent invocations, feature doc lifecycle moves, STATUS.md updates

**Allowed operations**:
- Read, Grep, Glob, and read-only Bash on any file
- Task invocations to launch agents (@test-writer, @builder, @code-reviewer)
- `sed` on feature doc frontmatter (`status:` field only)
- `mv` to move feature docs between lifecycle directories
- Write/Edit on `feature-docs/STATUS.md` only

**Constraints**:
- Never uses Write, Edit, or sed on files listed in `affected-files`
- Never uses Write, Edit, or sed on test files
- Never uses Write, Edit, or sed on any implementation/source file
- When code needs fixing, re-invokes the responsible agent with specific error details
- When tests are wrong, reports to the user or re-invokes the test-writer

## 5. Feature Doc Lifecycle

```
Human explores idea      →  (feature-docs/ideation/<name>/)
  └─ Code reviews, research, design notes, spikes
Human distills doc       →  status: ready       (feature-docs/ready/)
Test-writer picks up     →  status: testing     (feature-docs/testing/)
  └─ Failing tests committed on feature branch
Builder picks up         →  status: building    (feature-docs/building/)
  └─ Implements until all tests pass
Builder finishes         →  status: review      (feature-docs/review/)
  └─ All tests + verify pass
Reviewer validates       →  status: done        (feature-docs/completed/)
  └─ PR ready for merge
```

### Status Transitions

| From | To | Who | Action |
|---|---|---|---|
| ready | testing | test-writer | Move doc, write failing tests, commit |
| testing | building | builder | Move doc, begin implementation |
| building | review | builder | Move doc, all tests pass, verify clean |
| review | completed | reviewer | Move doc, approve quality |
| review | building | reviewer | Move doc back, issues found (re-work) |

The status field in the feature doc frontmatter and the directory location must
stay in sync. Moving the file IS the status transition.

### Branch Strategy

Each feature gets its own branch: `feat/<feature-name>` (following git-workflow
skill conventions).

- Test-writer creates the branch and commits tests
- Builder commits implementation on the same branch
- Reviewer reviews the branch, then the branch is PR'd to main

### Naming Convention

Feature doc filenames use a 3-digit numeric prefix: `NNN-feature-name.md`
(e.g., `001-user-auth.md`, `002-cart-redesign.md`). The prefix is assigned at
creation time by running `scripts/next-feature-number.sh`, which scans all
lifecycle directories and ideation folders for existing prefixes and returns
the next available number. Ideation folders use the same prefix (e.g.,
`ideation/001-user-auth/`). The numeric prefix carries through the entire
lifecycle — the same file that starts as `ready/001-user-auth.md` becomes
`testing/001-user-auth.md`, then `building/`, `review/`, and `completed/`.

This prevents confusion between similarly-named features. `001-user-auth.md`
can never be mistaken for `002-user-auth-v2.md`.

## 6. Coordination Protocol

### Automated Kickoff

Source `feature-docs/implement-feature.md` to scan `ready/` for available
features, run pre-flight checks (section completeness, file ownership conflicts),
and kick off the test-writer. The `TeammateIdle` hook handles all subsequent
handoffs automatically. This is the recommended way to start implementation.

### Manual Workflow (Single Feature)

For one feature at a time, the user drives each handoff manually:

```
# Step 1: Human creates feature doc (with numeric prefix)
# Place the doc in feature-docs/ready/

# Step 2: Invoke test-writer
@test-writer Pick up feature-docs/ready/001-user-auth.md

# Step 3: Wait for test-writer to finish, then invoke builder
@builder Pick up feature-docs/testing/001-user-auth.md

# Step 4: Wait for builder to finish, then invoke reviewer
@code-reviewer Review feature-docs/review/001-user-auth.md
```

### Parallel Workflow (Multiple Features)

For multiple features in parallel, ensure no `affected-files` overlap:

```
# Two features with non-overlapping files — numeric prefix prevents name confusion
@test-writer Pick up feature-docs/ready/001-user-auth.md
@test-writer Pick up feature-docs/ready/002-cart.md

# After both test-writers finish
@builder Pick up feature-docs/testing/001-user-auth.md
@builder Pick up feature-docs/testing/002-cart.md
```

If features share files, run them **sequentially** to avoid conflicts.

### TeammateIdle Hook

When a teammate finishes work and goes idle, the `TeammateIdle` hook scans
`feature-docs/` for pending work in this priority order:

1. `feature-docs/testing/` — Failing tests exist, needs a builder
2. `feature-docs/ready/` — Feature doc waiting, needs a test-writer
3. `feature-docs/review/` — Implementation done, needs a reviewer

If work is found, the hook sends a directive to the idle teammate. If nothing
is pending, the teammate goes idle.

### TaskCompleted Hook

When any teammate tries to mark a task as done, the `TaskCompleted` hook runs
two checks:

**1. Lifecycle compliance** — Scans all feature docs in `ready/`, `testing/`,
`building/`, `review/`, and `completed/`. For each doc with a `status:` field,
verifies the value matches the directory name. If any feature doc is in the wrong
directory (e.g., still in `ready/` when it should be in `testing/`), the task is
blocked. This prevents agents from skipping the doc-move step.

**2. Full verify pipeline**:
- Type checking (tsc / mypy / cargo check)
- Linting (eslint / ruff / clippy)
- Tests (vitest / pytest / cargo test)

If either check fails, the task cannot be marked done. The agent sees the error
output and must fix the issue before trying again.

## 7. File Ownership Rules

### Claiming Files

When an agent picks up a feature doc, the `affected-files` list in the
frontmatter declares which files that agent may modify. Before starting:

1. Read all feature docs in `feature-docs/testing/` and `feature-docs/building/`
2. Collect their `affected-files` lists
3. Check for overlap with the current feature's `affected-files`
4. If overlap exists, report to the user and wait — do not proceed

### Resolving Conflicts

If two features must touch the same file:
- Run them sequentially (feature A completes fully before feature B starts)
- Or split the shared file into separate modules first

### Test File Ownership

Test files are owned exclusively by the test-writer. The builder must never
modify them. If a test is wrong:

1. Builder stops and reports the issue
2. User or test-writer fixes the test
3. Builder resumes

## 8. Style Work (Frontend Only)

Style refinement cannot be fully automated because "looks right" is subjective.

### Style Doc Format

Style docs follow the same template as feature docs but live in `styles/`
instead of `feature-docs/`:

```markdown
---
title: Dashboard Cards Redesign
status: ready
affected-files:
  - src/components/dashboard/stat-card.tsx
  - src/components/dashboard/chart-card.tsx
---

# Dashboard Cards Redesign

## Visual Direction

- Cards should use subtle shadows instead of borders
- Stat numbers should use the display font at 2xl
- Charts should fill the card width with 16px padding

## Reference

- See designs in figma: [link]
- Similar to the pattern in src/components/existing-card.tsx
```

### Iteration Loop

1. Human writes a style doc with visual direction
2. Style agent applies changes and generates screenshots to
   `styles/reviews/<name>/iteration-N/`
3. Agent sets status to `awaiting-review` and **stops**
4. Human reviews screenshots, writes feedback in the style doc
5. Agent reads feedback, applies another iteration
6. When human approves, screenshots become Playwright visual regression baselines

Approved screenshots are locked in as automated tests. Future agents cannot drift
from the approved design without failing a visual regression test.

## 9. Hook Configuration

### TaskCompleted

Blocks task completion until lifecycle compliance and the full verify pipeline pass.

```json
{
  "event": "TaskCompleted",
  "command": "bash scripts/task-completed.sh"
}
```

The script runs two checks. First, it scans feature docs for status/directory
mismatches (e.g., a doc in `ready/` with `status: testing`) and blocks if any are
found. Second, it runs `scripts/verify.sh` (full pipeline) and blocks (exit 2) on
any failure. Output is truncated to 30 lines to avoid context pollution. Verbose
logs are available in `agent_logs/` for debugging.

**Lifecycle-aware**: During the `testing` stage, only lifecycle compliance is
checked — the verify pipeline is skipped because tests are expected to fail.
The builder runs full verify when it completes.

### TeammateIdle

Redirects idle teammates to pending feature docs.

```json
{
  "event": "TeammateIdle",
  "command": "bash scripts/teammate-idle.sh"
}
```

The script first checks for stuck features (in `building/` for over 30 minutes)
and warns if found. Then it scans `feature-docs/` directories and outputs a
directive if work is found (exit 2 to keep the teammate working). If no work is
found, exits 0 to let the teammate go idle.

### Stop (Fast Verify on Change)

Runs fast verification (type check only) after each Claude response when files
have changed. Full verification is deferred to TaskCompleted to avoid spending
agent time on the full suite during iterative development.

```json
{
  "event": "Stop",
  "command": "bash scripts/stop-hook.sh"
}
```

The script checks `git diff` and `git ls-files` for modifications. If the working
tree is clean, it exits 0 (skips verify). If files have changed, it runs
`scripts/fast-verify.sh` (type check only) for quick feedback. If no fast-verify
script exists, it falls back to `scripts/verify.sh`. It reads `stop_hook_active`
from stdin to prevent recursive loops. Output is truncated to 20 lines.

**Lifecycle-aware**: During the `testing` stage, verification is skipped entirely
because test-writer code references unimplemented APIs that will always fail type
checking.

### Branch Protection

The `guard-bash.sh` PreToolUse hook blocks direct commits on `main`/`master`,
forcing agents to work on feature branches. This complements the branch-per-feature
strategy described in the coordination protocol.

## 10. Bootstrap Prompt (New Project)

Use this prompt to set up the agent teams workflow in a new project:

```
Set up the agent teams workflow for this project:

1. Create the feature-docs/ directory structure:
   feature-docs/ideation/, feature-docs/ready/, feature-docs/testing/,
   feature-docs/building/, feature-docs/review/, feature-docs/completed/

2. Create an agent_logs/ directory for verbose output
   Add agent_logs/ to .gitignore

3. Verify that scripts/verify.sh and scripts/fast-verify.sh both exist:
   - verify.sh: full pipeline (type check + lint + tests) with output to agent_logs/
   - fast-verify.sh: type check only for quick feedback

4. Verify that .claude/settings.json includes TaskCompleted,
   TeammateIdle, and Stop hooks

5. Create a sample feature doc in feature-docs/ready/ based on the
   Feature Doc Format section in feature-docs/CLAUDE.md

6. Create an empty feature-docs/STATUS.md for the progress dashboard

7. Run the full verify pipeline once to confirm everything works

Report what you created and any issues found.
```

## 11. Retrofit Prompt (Existing Project)

Use this prompt to add the workflow to a project that already has code and tests:

```
Retrofit the agent teams workflow into this existing project:

1. Discovery — report the following:
   - Package manager and framework
   - Test runner and test directory structure
   - Component library and state management
   - Directory structure and naming conventions
   - Existing .claude/ configuration

2. Create the feature-docs/ directory structure alongside existing code

3. Verify scripts/verify.sh works with the existing toolchain:
   - Type checking command
   - Lint command
   - Test command

4. Check .claude/settings.json for existing hooks and add
   TaskCompleted and TeammateIdle hooks without replacing
   existing configuration

5. Identify migration needs:
   - Test files not in a separate directory (need restructuring?)
   - Missing test coverage for critical paths
   - Files without clear ownership boundaries

Write a discovery report to agent_logs/discovery-report.md and
list any recommended changes (without acting on them).
```

## 12. Token Cost Expectations

Agent teams use roughly 5x the tokens of a single session per teammate. A team
of 3 (test-writer, builder, reviewer) working on a single feature uses
approximately 15x a normal session's tokens. This is justified when:

- The feature has clear, testable acceptance criteria
- Files can be cleanly owned by one feature at a time
- Quality gates (hooks) prevent wasted rework
- The alternative is sequential context degradation in a single long session

For simple features (one file, clear spec), use a single Claude Code session.
Reserve agent teams for features touching multiple files across stores,
components, services, and tests.

## Anti-Patterns

| Anti-Pattern | Why It Fails | Fix |
|---|---|---|
| Builder modifies test files | Grading your own homework — tests lose independence as the oracle | Builder must never touch files created by test-writer |
| Skipping the test-writer step | Builder writes both tests and code; tests are weak and trivially satisfied | Always have test-writer produce failing tests first |
| No file ownership declaration | Two agents edit the same file; merge conflicts and lost work | Feature docs must list `affected-files`; check for overlaps |
| Running parallel features on same branch | Merge conflicts, unclear ownership, broken bisect history | One branch per feature; merge to main sequentially |
| Passing full test output to agents | Context pollution fills the window with stack traces | Pass summary only: X passed, Y failed, first failure message |
| Feature doc without testable criteria | Test-writer cannot produce meaningful tests; builder has no target | Every acceptance criterion must use GIVEN/WHEN/THEN format |
| Skipping the reviewer step | Qualitative issues (conventions, duplication, design) go undetected | Reviewer validates what tests cannot catch |
| Using agent teams for trivial changes | 15x token cost for a one-line fix is wasteful | Single session for changes touching fewer than 3 files |
| Running full test suite on every save | Agent wastes time waiting for slow tests during iteration | Use fast-verify.sh (type check only) on Stop; full suite on TaskCompleted |
| Tests that check truthiness not values | Wrong implementation passes — `toBeTruthy()` accepts any non-null | Assert specific return values, error types, and state changes |
| No progress dashboard | Agents start with zero context and waste time re-discovering state | Update `feature-docs/STATUS.md` after every stage transition |
| Ignoring stuck features | Agent spins for hours on a hard problem without human awareness | TeammateIdle warns after 30 minutes in building/; check agent_logs/ |
| Skipping feature doc lifecycle steps | Next agent never finds the feature doc; pipeline stalls indefinitely | `task-completed.sh` enforces status/directory sync; Completion Gate checklist in agent definitions |
| Coordinator edits implementation or test files | Violates role separation — coordinator and agent edit the same files, causing conflicts and undermining the test-as-oracle principle | Coordinator re-invokes the responsible agent with specific error details; never uses Write/Edit/sed on code |
| Coordinator fixes follow-up issues directly | Bypasses TDD — no failing test, no builder, no review; defeats the entire workflow even for "small" fixes | Route follow-ups through the full pipeline: test-writer → builder → reviewer; create a new feature doc or amend the existing one |
| Unbounded review → building loop | Builder and reviewer cycle indefinitely, burning tokens on issues the builder cannot resolve alone | Auto-loop up to 3 cycles; after 3, escalate to the user with remaining issues |
| Launching next agent before current one finishes | Both agents edit the same feature's files simultaneously, causing conflicts and lost work | Per-feature sequential: wait for each agent to complete before launching the next; cross-feature parallelism is fine with non-overlapping `affected-files` |
| Reviewer fixes code directly | Defeats independence — reviewer can't objectively review code it wrote; bypasses TDD pipeline | Reviewer reports issues only; coordinator routes to test-writer (for test gaps) or builder (for implementation issues) |
| Ideation README never updated after pipeline | Feature appears incomplete in ideation folder; scanning for shipped features requires reading `completed/` instead of ideation metadata | Coordinator updates ideation README to `shipped` in "After reviewer approves" step |
| Feature docs without numeric prefix | Similarly-named features (user-auth.md vs user-auth-v2.md) cause agents to read the wrong doc from completed/ or other directories | Always use `scripts/next-feature-number.sh` to get a unique NNN- prefix at creation time |
| Running verify on test-writer output | Type errors on unresolved imports fire on every response; test failures block task completion | Hooks detect `testing` stage via `lifecycle-stage.sh` and skip verification |
