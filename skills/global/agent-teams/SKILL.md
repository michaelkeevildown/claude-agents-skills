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
- Hook-based quality gates (TaskCompleted, TeammateIdle)
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
- The `scripts/verify.sh` script captures output and pipes through `tail -30`

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
  user-auth/
    README.md             # Status tracking + progress log
    code-review.md        # Analysis of existing code to change
    api-research.md       # How other projects solve this
    design-notes.md       # Data flow, component tree, schema
    spike-results.md      # Quick experiments
  cart-redesign/
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
status: in-progress        # or: complete
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
  - src/auth/login.ts
  - src/auth/session.ts
  - src/stores/auth-store.ts
  - src/components/login-form.tsx
---

# User Authentication

## Summary

Add email/password login with session management. Users can log in, stay
authenticated across page reloads, and log out.

## Acceptance Criteria

1. GIVEN a valid email and password WHEN the user submits the login form
   THEN a session token is stored and the user is redirected to the dashboard
2. GIVEN an invalid email or password WHEN the user submits the login form
   THEN an error message is displayed and the form is not cleared
3. GIVEN a logged-in user WHEN they reload the page
   THEN they remain authenticated (session persists)
4. GIVEN a logged-in user WHEN they click logout
   THEN the session is cleared and they are redirected to the login page
5. GIVEN an expired session token WHEN any authenticated request is made
   THEN the user is redirected to the login page with an expiry message

## Edge Cases

- Empty email or password fields — show validation errors before submission
- Network failure during login — show a connection error, allow retry
- Multiple rapid login attempts — debounce to prevent duplicate requests

## Out of Scope

- OAuth/social login (separate feature)
- Password reset flow (separate feature)
- Rate limiting (backend concern)

## Technical Notes

- Follow the existing store pattern in `src/stores/` for the auth store
- Session token goes in httpOnly cookie (not localStorage)

## Style Requirements (frontend only)

- Login form matches existing shadcn Card + Form patterns
- Error messages use destructive variant of Alert component
```

### Acceptance Criteria Rules

Every acceptance criterion must be:

1. **Testable** — can be verified by an automated test
2. **Specific** — uses GIVEN/WHEN/THEN format with concrete values
3. **Independent** — does not depend on other criteria passing first
4. **Complete** — covers the happy path, error cases, and edge cases

Vague criteria produce vague tests produce wrong implementations. "The login
should work" is not an acceptance criterion. "GIVEN valid credentials WHEN the
user submits THEN a session token is stored" is.

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

## 6. Coordination Protocol

### Sequential Workflow (Single Feature)

For one feature at a time, the user drives each handoff:

```
# Step 1: Human creates feature doc
# Place the doc in feature-docs/ready/

# Step 2: Invoke test-writer
@test-writer Pick up feature-docs/ready/user-auth.md

# Step 3: Wait for test-writer to finish, then invoke builder
@builder Pick up feature-docs/testing/user-auth.md

# Step 4: Wait for builder to finish, then invoke reviewer
@code-reviewer Review feature-docs/review/user-auth.md
```

### Parallel Workflow (Multiple Features)

For multiple features in parallel, ensure no `affected-files` overlap:

```
# Two features with non-overlapping files
@test-writer Pick up feature-docs/ready/user-auth.md
@test-writer Pick up feature-docs/ready/cart.md

# After both test-writers finish
@builder Pick up feature-docs/testing/user-auth.md
@builder Pick up feature-docs/testing/cart.md
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
the full verify pipeline:

1. Type checking (tsc / mypy / cargo check)
2. Linting (eslint / ruff / clippy)
3. Tests (vitest / pytest / cargo test)

If any step fails, the task cannot be marked done. The agent sees the error
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

Blocks task completion until the full verify pipeline passes.

```json
{
  "event": "TaskCompleted",
  "command": "bash scripts/task-completed.sh"
}
```

The script runs `scripts/verify.sh` and blocks (exit 2) on any failure. Output
is truncated to 30 lines to avoid context pollution.

### TeammateIdle

Redirects idle teammates to pending feature docs.

```json
{
  "event": "TeammateIdle",
  "command": "bash scripts/teammate-idle.sh"
}
```

The script scans `feature-docs/` directories and outputs a directive if work is
found (exit 2 to keep the teammate working). If no work is found, exits 0 to
let the teammate go idle.

### Stop (Verify on Change)

Runs the verify pipeline after each Claude response, but only when files have
actually changed. This prevents infinite loops on pre-existing failures during
conversational workflows (e.g. ideation via `feature-docs/new-feature.md`).

```json
{
  "event": "Stop",
  "command": "bash scripts/stop-hook.sh"
}
```

The script checks `git diff` and `git ls-files` for modifications. If the working
tree is clean, it exits 0 (skips verify). If files have changed, it runs
`scripts/verify.sh` and returns its exit code. It also reads `stop_hook_active`
from stdin to prevent recursive loops.

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

3. Verify that scripts/verify.sh exists and runs clean:
   - Type checking passes
   - Linting passes with zero warnings
   - All existing tests pass

4. Verify that .claude/settings.json includes TaskCompleted and
   TeammateIdle hooks

5. Create a sample feature doc in feature-docs/ready/ based on the
   Feature Doc Format section in feature-docs/CLAUDE.md

6. Run the full verify pipeline once to confirm everything works

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
