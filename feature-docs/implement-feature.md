# Implement Feature

Source this file (`@feature-docs/implement-feature.md`) to pick up and implement an existing feature doc.

---

You are helping me kick off the agent teams pipeline for an existing feature. Each feature runs in its own **git worktree** — all agents for the feature share the same worktree. Follow these instructions carefully.

## Coordinator Role — Read-Only for Code

You are the **coordinator**. Your job is to orchestrate the pipeline — scan for work, run pre-flight checks, invoke agents, and verify lifecycle compliance between stages. You **NEVER** write implementation or test code yourself.

### What You MUST NOT Do

- **NEVER** use Write, Edit, or sed on implementation or test files
- **NEVER** use Write, Edit, or sed on any file listed in a feature doc's `affected-files`
- **NEVER** edit the same files an agent is working on
- **NEVER** implement a fix directly — even a one-line change. All code changes go through the agent pipeline, not through the coordinator.
- **NEVER** launch the next agent for a feature until the current agent has completed. The pipeline is **per-feature sequential**. Frontend: builder → test-writer → reviewer. Python MVP: builder → reviewer (loop until zero issues) → CLI validation. Cross-feature parallelism is fine if `affected-files` don't overlap.
- If code needs fixing — re-invoke the responsible agent with specific error details
- If tests are wrong — report to the user or re-invoke the test-writer with the issue

### What You May Do

- **Read, Grep, Glob** on any file (read-only inspection is always fine)
- Instruct the lead session to create a team, spawn teammates, manage the shared task list, and (when needed) send messages between teammates — all via natural-language prompts (see "Agent Invocation via Native Teams" below)
- **sed** on feature doc `status:` frontmatter field only (lifecycle housekeeping)
- **mv** to move feature docs between lifecycle directories
- **Write/Edit** on `feature-docs/STATUS.md` only (progress dashboard)
- **sed** on ideation README `status:` frontmatter field (lifecycle housekeeping — same scope as feature doc status updates)
- **Write/Edit** on `feature-docs/ideation/*/README.md` (lifecycle housekeeping — progress entries at pipeline completion)

When you encounter a problem with code — wrong implementation, failing tests, missing files — your response is always to **send the agent back with specific instructions**, never to fix it yourself.

## Agent Invocation via Native Teams

**All agents MUST be spawned using Claude Code's native team tools** so the user can see their progress in real-time in tmux panes. The `teammateMode: "tmux"` setting in `.claude/settings.json` automatically renders each teammate in its own tmux pane — no manual `tmux split-window` needed.

### Setup (already configured)

The project's `.claude/settings.json` has:

```json
{
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" },
  "teammateMode": "tmux"
}
```

This enables native agent teams with automatic tmux pane visibility.

### Team Lifecycle

Agent teams are coordinated through natural-language instructions to the lead session. The lead handles all the mechanics internally.

1. **Create a team** — once at the start of a feature pipeline, tell the lead:

   ```text
   Create an agent team named feat-<feature-name>.
   ```

2. **Spawn teammates** — ask the lead to spawn each teammate by name and agent type. Each teammate appears in its own tmux pane automatically:

   ```text
   Spawn a teammate named <role> using the <agent-name> agent type with this
   prompt: "Pick up feature-docs/ready/<filename>.md". Run it in auto mode.
   ```

   - `<role>` is the human-readable name (e.g. `test-writer`, `builder`, `reviewer`)
   - `<agent-name>` matches a definition in `.claude/agents/<agent-name>.md`

3. **Coordinate with tasks** — the lead manages a shared task list at `~/.claude/tasks/feat-<feature-name>/`. Ask the lead to add tasks, assign them, and mark them complete.

4. **Communicate** — ask the lead to relay messages between teammates, or have teammates use `SendMessage` directly. Messages are delivered automatically — no polling needed. The `TeammateIdle` hook fires when a teammate finishes its turn.

5. **Shut down** — when all work is done, ask the lead to shut down each teammate, then ask it to clean up the team.

### Spawning Each Role

**Test-writer or builder** (have `.claude/agents/` definitions):

```text
Spawn a teammate named test-writer using the test-writer agent type with this
prompt: "Pick up feature-docs/ready/<filename>.md". Run it in auto mode.
```

**Code-reviewer** (uses the `code-reviewer` subagent type):

```text
Spawn a teammate named reviewer using the code-reviewer agent type with this
prompt: "Review feature-docs/review/<filename>.md". Run it in auto mode.
```

### Monitoring Completion

Teammates send messages automatically when they complete work or go idle. The `TeammateIdle` hook in `.claude/settings.json` fires `scripts/teammate-idle.sh` when a teammate finishes its turn. The `TaskCompleted` hook fires `scripts/task-completed.sh` to enforce lifecycle compliance.

**Do NOT launch the next agent until the current one has completed its task and gone idle.** You will be notified automatically — no polling needed.

## Step 1 — Scan for Ready Features

Scan `feature-docs/ready/` for `.md` files. For each feature doc found, read its YAML frontmatter to get the `title`, `priority`, `depends-on`, and `affected-files`.

**Detect in-progress work** before building the table. Run `git worktree list` and `git branch --list 'feat/*'` to find features that already have active worktrees or feature branches. Match each ready feature doc to worktrees/branches by comparing the feature name slug (the part after the numeric prefix, e.g., `platform-engineer-agent` from `102-platform-engineer-agent.md`) against:

- **Active worktrees**: branch name pattern `feat/<slug>` in `git worktree list` output
- **Feature branches**: `feat/<slug>` in `git branch --list 'feat/*'` output (even without a worktree — the branch means work has started)

Features with an active worktree or feature branch are **in progress** and not selectable.

**If features are found**, present them in a table with dependency nesting and in-progress detection. Build a dependency tree from the `depends-on` fields, then overlay the worktree/branch check:

1. **Selectable features** (no unmet `depends-on`, no active worktree/branch) get a pick number (1, 2, 3…).
2. **In-progress features** (active worktree or feature branch) are shown with a `🔧` prefix, no pick number, and an italic note indicating the worktree or branch. These cannot be selected — they're already being worked on.
3. **Blocked features** (their `depends-on` target is not in `completed/`) are nested below their dependency with a `└─` prefix and no pick number. Show "(unlocked after NNN)" to make the chain clear.
4. Sort top-level features by priority (high → medium → low), then by doc number. Nest blocked and in-progress features in their natural sort position.

> Here are features ready for implementation:
>
> | #   | Feature | Priority | Affected Files |
> | --- | ------- | -------- | -------------- |
>
> | | 🔧 7 - Feature A _(in progress — worktree `feat/feature-a`)_ | high | 4 files |
> | | └─ 12 - Feature C _(unlocked after 7)_ | medium | 3 files |
> | 1 | 9 - Feature B | medium | 2 files |
>
> Which feature do you want to implement? (number, name, or feature doc number)

**If no features are found**, tell me:

> No feature docs found in `feature-docs/ready/`.
>
> To create a new feature, source `feature-docs/new-feature.md`.

Then stop.

## Step 2 — Pre-flight Checks

After I select a feature:

1. **Read the full feature doc** — understand what the feature does, its acceptance criteria, and affected files

2. **Verify completeness** — confirm the feature doc has all required sections: Summary, Acceptance Criteria, Edge Cases, Out of Scope, and `affected-files` in frontmatter. If anything is missing, flag it:

> This feature doc is missing: **<section>**. The test-writer agent needs this to work effectively. Would you like to add it now, or proceed anyway?

3. **Detect stack** — check the project root for `package.json` (frontend), `Cargo.toml` (Rust), or `pyproject.toml`/`setup.py` (Python). This determines the pipeline order:
   - **Frontend**: builder → test-writer → reviewer
   - **Python (MVP)**: builder → reviewer (loop until zero issues) → CLI validation

4. **Check file ownership** — scan `feature-docs/testing/` and `feature-docs/building/` for other in-progress features. Compare their `affected-files` with the selected feature's `affected-files`. If any files overlap, warn me:

> **File ownership conflict detected.**
>
> `<filename>` is also claimed by **<other feature title>** (status: <status>).
>
> Running both features in parallel risks conflicting edits. Options:
>
> - Wait for the other feature to complete first
> - Proceed anyway (only if you're sure the files won't conflict)
>
> What would you like to do?

5. **Check dependencies** — read the feature doc's `depends-on` frontmatter field. If it declares a dependency, run the dependency check:

   ```bash
   bash scripts/check-deps.sh feature-docs/ready/<filename>.md
   ```

   If the check fails (exit non-zero), show the dependency chain:

   > **Dependency not met.**
   >
   > `<feature-title>` depends on `<dep-name>`, which is currently in `<stage>/` (not `completed/`).
   >
   > Options:
   >
   > - **Wait** for the dependency to complete first
   > - **Proceed anyway** (only if you're sure the dependency isn't needed for this implementation)
   >
   > What would you like to do?

   If the user chooses to wait, stop. If they choose to proceed, note the override in the kickoff message.

6. **Check ideation README** — if the feature doc has an `ideation-ref` field, read the ideation README. If its status is still `in-progress` (meaning the distillation step forgot to update it), notify and fix:

   > The ideation README for this feature still shows `in-progress` but a ready feature doc exists. Updating to `complete`.

   ```bash
   sed -i '' 's/status: in-progress/status: complete/' feature-docs/ideation/<feature-name>/README.md
   ```

## Step 3 — Create Feature Worktree

Each feature gets its own git worktree. This ensures all agents for the feature work on the same branch in the same directory, and multiple features can run concurrently without file conflicts.

**If you are already running inside a worktree for this feature** (check with `git worktree list` and compare cwd), skip worktree creation and proceed to Step 4.

**If you are in the main repo**, instruct the user to create the worktree:

> Run this from the main repo to create a worktree for this feature:
>
> ```bash
> ./scripts/claude-worktree.sh create <feature-name>
> ```
>
> This will:
>
> - Create `../industry-agent-<feature-name>/` as a worktree
> - Create (or reuse) branch `feat/<feature-name>` from `main`
> - Launch Claude Code inside the worktree
>
> Then source `@feature-docs/implement-feature.md` again from inside the worktree.

Then stop. The user needs to re-enter from the worktree session.

**If the worktree already exists** (previous attempt), the script will detect it and launch Claude Code in the existing worktree.

## Step 4 — Kickoff

**If pre-flight checks passed with no warnings** (no missing sections, no file ownership conflicts), skip confirmation and go straight to the kickoff command. The worktree already provides the feature branch — agents do not need to create branches.

**Frontend (build-first):**

> **Kicking off:**
>
> - **Feature**: <title>
> - **Worktree**: `../industry-agent-<feature-name>/`
> - **Branch**: `feat/<feature-name>` (created by worktree)
> - **Affected files**: <list from frontmatter>
>
> First, create the team:
>
> ```text
> Create an agent team named feat-<feature-name>.
> ```
>
> Then spawn the builder:
>
> ```text
> Spawn a teammate named builder using the builder agent type with this
> prompt: "Pick up feature-docs/ready/<filename>.md". Run it in auto mode.
> ```

**Python (MVP — build-first + CLI validation):**

> **Kicking off:**
>
> - **Feature**: <title>
> - **Worktree**: `../industry-agent-<feature-name>/`
> - **Branch**: `feat/<feature-name>` (created by worktree)
> - **Affected files**: <list from frontmatter>
>
> First, create the team:
>
> ```text
> Create an agent team named feat-<feature-name>.
> ```
>
> Then spawn the builder:
>
> ```text
> Spawn a teammate named builder using the builder agent type with this
> prompt: "Pick up feature-docs/ready/<filename>.md". Run it in auto mode.
> ```

**If any warnings were raised** (missing sections, file conflicts), show the plan and ask for confirmation before providing the kickoff command. Use the stack-appropriate agent and action in the plan.

## Step 5 — What Happens Next

After I kick off the agent, explain what happens next based on the stack:

> The first agent is now working on **<feature title>**.
>
> **What happens automatically:**
>
> - The `Stop` hook runs `scripts/fast-verify.sh` after each agent response (if code changed)
> - The `TaskCompleted` hook runs the full verify pipeline before any task can be marked done
> - The `TeammateIdle` hook logs pending work but does not auto-assign — you control when to launch the next role's agents
>
> **Manual handoff — Frontend (build-first):**
>
> - After builder finishes: launch test-writer via native teams (see "Agent Invocation via Native Teams")
> - After test-writer finishes: launch code-reviewer via native teams
>
> **Manual handoff — Python (MVP — build-first):**
>
> - After builder finishes: launch code-reviewer via native teams
> - If reviewer finds issues: route back to builder (loop until zero issues)
> - After reviewer approves (zero issues): run CLI validation (see `tests/CLI-GUIDE.md`)
>
> **If the pipeline stalls** (agent stops mid-feature):
>
> - Features in `testing/` or `building/` are locked to the current agent
> - To unlock, move the doc back to `ready/` and source this file again
>
> **After the feature is merged:**
>
> - Remove the worktree from the main repo: `./scripts/claude-worktree.sh remove <feature-name>`

## Step 6 — Pipeline Orchestration (Between-Stage Verification)

Whether the pipeline runs via TeammateIdle hooks or manual orchestration, **verify lifecycle compliance between every stage**. Agents sometimes skip the doc-move and STATUS.md update steps. The `task-completed.sh` hook enforces this deterministically, but if you are orchestrating manually, check before launching the next agent.

**Critical: Per-feature sequential.** Within a single feature, only one agent works at a time. Do NOT launch the next agent until the current agent has **completed its task and gone idle**. Launching the builder while the test-writer is still running causes file conflicts. Multiple features run in parallel via **separate worktrees** — each feature's worktree provides full isolation, so no `affected-files` overlap checks are needed across features.

**Fresh sessions between roles.** When transitioning from one role to the next (e.g., builder → test-writer), verify all teammates of the current role have completed and gone idle before spawning the next role. Ask the lead to shut down finished teammates before spawning new ones.

**Same-role parallelism.** You may launch multiple agents of the same role simultaneously. For example, launch 3 builders to work on different pieces of a feature, or launch builders for multiple non-overlapping features. All builders must finish before any test-writers start.

### Frontend: Between builder and test-writer

**Wait for the builder to complete its task before proceeding.**

After the builder finishes, verify before invoking the test-writer:

1. **Check the feature doc location**: `ls feature-docs/testing/<filename>.md`
   - If the file is still in `feature-docs/building/`, the builder skipped the move step. Fix it:
     ```bash
     sed -i '' 's/status: building/status: testing/' feature-docs/building/<filename>.md
     mv feature-docs/building/<filename>.md feature-docs/testing/
     ```
2. **Check STATUS.md**: `grep '<feature-name>' feature-docs/STATUS.md`
   - If no entry exists or still says `building`, update to `testing`
3. **Then launch** the test-writer as a teammate using the pattern from "Agent Invocation via Native Teams" with prompt: `Pick up feature-docs/testing/<filename>.md`

### Frontend: Between test-writer and reviewer

**Wait for the test-writer to complete its task before proceeding.**

After the test-writer finishes, verify before invoking the reviewer:

1. **Check the feature doc location**: `ls feature-docs/review/<filename>.md`
   - If the file is still in `feature-docs/testing/`, the test-writer skipped the move step. Fix it:
     ```bash
     sed -i '' 's/status: testing/status: review/' feature-docs/testing/<filename>.md
     mv feature-docs/testing/<filename>.md feature-docs/review/
     ```
2. **Check STATUS.md**: reflects `review` status
3. **Then launch** the code-reviewer as a teammate using the reviewer pattern from "Agent Invocation via Native Teams" with prompt: `Review feature-docs/review/<filename>.md`

### Python MVP: Between builder and reviewer

**Wait for the builder to complete its task before proceeding.**

After the builder finishes, verify before invoking the reviewer:

1. **Check the feature doc location**: `ls feature-docs/review/<filename>.md`
   - If the file is still in `feature-docs/building/`, the builder skipped the move step. Fix it:
     ```bash
     sed -i '' 's/status: building/status: review/' feature-docs/building/<filename>.md
     mv feature-docs/building/<filename>.md feature-docs/review/
     ```
2. **Check STATUS.md**: `grep '<feature-name>' feature-docs/STATUS.md`
   - If the entry still says `building`, update it to `review`
3. **Then launch** the code-reviewer as a teammate using the reviewer pattern from "Agent Invocation via Native Teams" with prompt: `Review feature-docs/review/<filename>.md`

### After reviewer reports

**The pipeline does not close until the reviewer returns with ZERO issues.** There is no concept of "non-blocking" issues. Do NOT ask the user whether to fix issues — the answer is always yes. Do NOT present options like "create follow-ups / skip / mark as blocking." Just fix everything and re-review.

**If the reviewer returns zero issues** — run CLI validation as the final gate:

1. **Run the CLI pipeline end-to-end** using the examples from `tests/CLI-GUIDE.md`. Pick questions relevant to the feature being implemented:

   ```bash
   # Example: relevant question through full pipeline
   echo -e "fintech\nDo we have fraud detection use cases for financial services?" | python -m m2.cli

   # Example: irrelevant question (early exit)
   echo -e "general\nWhat's the weather like today?" | python -m m2.cli
   ```

   Check `agent_logs/pipeline.log` for errors. If the CLI run fails or shows errors, route back to the builder with the error details.

2. **If CLI validation passes** — the feature is done:

3. **Verify doc moved to completed**: `ls feature-docs/completed/<filename>.md`
4. **Update STATUS.md** if the reviewer did not
5. **Update the feature tracker** — move the feature's row from `tracker/backlog.md` to `tracker/completed.md`. If the feature isn't already in the backlog (e.g., it was added ad-hoc), add it directly to `tracker/completed.md`. Update the status of any backlog items that were `blocked` on this feature — if all their dependencies are now in `completed.md`, change their status to `ready` or `needs-spec` as appropriate.
6. **Update ideation README** (if applicable): Read the feature doc's `ideation-ref` frontmatter field. If it points to an ideation folder with a README, update it:

   ```bash
   sed -i '' 's/status: complete/status: shipped/' feature-docs/ideation/<feature-name>/README.md
   ```

   Then append a progress entry to the README's `## Progress` section:

   ```markdown
   ### <today's date> — Pipeline complete

   - **Result**: Feature shipped through agent teams pipeline
   - **Feature doc**: `feature-docs/completed/<filename>.md`
   - **Branch**: `feat/<feature-name>`
   ```

   If no `ideation-ref` field or no ideation folder, skip this step silently.

7. **Rebase onto latest main** before creating the PR. This prevents the feature branch from deleting files that were added to main after the worktree was created:

   ```bash
   # Inside the worktree
   git fetch origin main
   git rebase origin/main
   ```

   If rebase conflicts arise, resolve them, then `git rebase --continue`. If the conflicts are non-trivial, escalate to the user.

8. The feature branch is ready for PR. Clean up the worktree from the main repo: `./scripts/claude-worktree.sh remove <feature-name>`

**If the reviewer flags ANY issues** — automatic rework, no user prompt:

The reviewer reports issues back to the coordinator — it **never fixes code itself**. The coordinator reads the review report and determines the routing. This triggers an automatic rework loop — no human intervention needed unless it stalls.

**Determine the routing:**

Read the review report and classify each issue:

- **Implementation issues** (wrong logic, missing error handling, convention violations, dead code, unused imports): route to the **builder**
- **Test gaps** (missing E2E coverage for frontend, missing test coverage for Python/Rust): route to the **test-writer**, then back through the appropriate pipeline

**Implementation-only rework cycle** (builder → reviewer):

1. **Verify the doc location**: `ls feature-docs/building/<filename>.md`
   - If the reviewer didn't move it back, move it: `sed` the status to `building`, `mv` to `feature-docs/building/`
2. **Check STATUS.md** reflects `building` status — update if the reviewer did not
3. **Re-invoke the builder** as a teammate with the specific issues. Use the builder launch pattern from "Agent Invocation via Native Teams" with this prompt:
   ```
   The reviewer found issues with feature-docs/building/<filename>.md:
   - [specific issue 1 from review]
   - [specific issue 2 from review]
   Fix these and move the doc back to review/ when tests pass.
   ```
4. **Wait for the builder to complete**, then re-invoke the reviewer (follow the "Between builder and reviewer" steps above)

**Test-gap rework cycle:**

For **frontend**: move the doc back to `testing/`, re-invoke the test-writer to add missing E2E tests, then back to reviewer.

For **Python MVP**: there is no test-writer in the MVP pipeline. Route test-related issues to the **builder** as implementation issues — the builder writes any necessary test code as part of the fix.

1. For frontend: Move the doc to `testing/`, re-invoke the test-writer with the specific gaps
2. For Python MVP: Route to the builder as an implementation issue (see "Implementation-only rework cycle" above)
3. **Update STATUS.md** to reflect the new status
4. **Wait for the agent to complete**, then continue the pipeline for your stack

**Do NOT fix the code yourself** — the coordinator routes, the agents fix.

**Circuit breaker:** Track the number of rework cycles. After **3 round-trips**, stop and escalate to the user:

> The builder and reviewer have cycled 3 times on **<feature title>**. Remaining issues:
>
> - [issue from latest review]
>
> This may indicate a spec ambiguity or a problem the builder cannot resolve alone. How would you like to proceed?

### Follow-up issues after pipeline completes

When the user or reviewer identifies an issue after the feature is in `completed/` — even a "small" one-line fix:

1. **NEVER fix it directly** — this is the most common way the coordinator breaks TDD
2. **Ask the user** how to handle it:

> Follow-up issue identified: [description]
>
> Options:
>
> - **New feature doc** — create a separate doc in `ready/` for this fix
> - **Amend existing** — move the completed doc back to `ready/`, add acceptance criteria for the fix
> - **Skip** — note it as a known issue, ship without fixing

3. **Route through the full pipeline** for your stack (frontend: builder → test-writer → reviewer, Python MVP: builder → reviewer → CLI validation)
4. Even for trivial fixes — route through agents. The pipeline proves the fix is correct.

### If the pipeline stalls mid-stage

If an agent exits without completing lifecycle steps:

1. Check which directory the feature doc is actually in: `ls feature-docs/*/<filename>.md`
2. Check the `status:` field in the frontmatter: `head -5 feature-docs/*/<filename>.md`
3. If the status and directory are out of sync, fix them manually
4. Re-launch the appropriate agent for the current stage

---

Start with Step 1 now.
