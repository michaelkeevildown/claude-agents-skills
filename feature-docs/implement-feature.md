# Implement Feature

Source this file (`@feature-docs/implement-feature.md`) to pick up and implement an existing feature doc.

---

You are helping me kick off the agent teams pipeline for an existing feature. Follow these instructions carefully.

## Coordinator Role — Read-Only for Code

You are the **coordinator**. Your job is to orchestrate the pipeline — scan for work, run pre-flight checks, invoke agents, and verify lifecycle compliance between stages. You **NEVER** write implementation or test code yourself.

### What You MUST NOT Do

- **NEVER** use Write, Edit, or sed on implementation or test files
- **NEVER** use Write, Edit, or sed on any file listed in a feature doc's `affected-files`
- **NEVER** edit the same files an agent is working on
- **NEVER** implement a fix directly — even a one-line change. All code changes go through the agent pipeline, not through the coordinator.
- **NEVER** launch the next agent for a feature until the current agent has completed. The pipeline is **per-feature sequential**. Frontend: builder → test-writer → reviewer. Python/Rust: test-writer → builder → reviewer. Cross-feature parallelism is fine if `affected-files` don't overlap.
- If code needs fixing — re-invoke the responsible agent with specific error details
- If tests are wrong — report to the user or re-invoke the test-writer with the issue

### What You May Do

- **Read, Grep, Glob** on any file (read-only inspection is always fine)
- **TeamCreate**, **Agent**, **SendMessage**, **TeamDelete** for team lifecycle
- **TaskCreate**/**TaskUpdate** for tracking work items
- **sed** on feature doc `status:` frontmatter field only (lifecycle housekeeping)
- **mv** to move feature docs between lifecycle directories
- **Write/Edit** on `feature-docs/STATUS.md` only (progress dashboard)
- **sed** on ideation README `status:` frontmatter field (lifecycle housekeeping — same scope as feature doc status updates)
- **Write/Edit** on `feature-docs/ideation/*/README.md` (lifecycle housekeeping — progress entries at pipeline completion)

When you encounter a problem with code — wrong implementation, failing tests, missing files — your response is always to **send the agent back with specific instructions**, never to fix it yourself.

## Step 1 — Scan for Ready Features

Scan `feature-docs/ready/` for `.md` files. For each feature doc found, read its YAML frontmatter to get the `title`, `priority`, and `affected-files`.

**If features are found**, present them in a table:

> Here are features ready for implementation:
>
> | #   | Feature       | Priority | Affected Files |
> | --- | ------------- | -------- | -------------- |
> | 1   | Feature Title | high     | 4 files        |
> | 2   | Feature Title | medium   | 2 files        |
>
> Which feature do you want to implement? (number or name)

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
   - **Python/Rust**: test-writer → builder → reviewer

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

## Step 3 — Check Branch

Check if a feature branch `feat/<feature-name>` already exists (run `git branch --list "feat/<feature-name>"`).

- If the branch doesn't exist, the first agent will create it (builder for frontend, test-writer for Python/Rust)
- If the branch exists, note this — it may be from a previous attempt

## Step 4 — Kickoff

**If pre-flight checks passed with no warnings** (no missing sections, no file ownership conflicts, no existing branch from a previous attempt), skip confirmation and go straight to creating the team and spawning the first agent.

**If any warnings were raised** (missing sections, file conflicts, or branch already exists), show the plan and ask for confirmation before proceeding.

**Create the team:**

```
TeamCreate { team_name: "feat-<feature-name>" }
```

**Frontend (build-first):**

> **Kicking off:**
>
> - **Feature**: <title>
> - **First agent**: builder (builds first, then test-writer writes E2E tests)
> - **Branch**: `feat/<feature-name>` (will be created by builder)
> - **Affected files**: <list from frontmatter>

```
Agent {
  team_name: "feat-<feature-name>",
  name: "builder",
  subagent_type: "builder",
  prompt: "Pick up feature-docs/ready/<filename>.md",
  mode: "auto"
}
```

**Python/Rust (TDD):**

> **Kicking off:**
>
> - **Feature**: <title>
> - **First agent**: test-writer (writes failing tests first)
> - **Branch**: `feat/<feature-name>` (will be created by test-writer)
> - **Affected files**: <list from frontmatter>

```
Agent {
  team_name: "feat-<feature-name>",
  name: "test-writer",
  subagent_type: "test-writer",
  prompt: "Pick up feature-docs/ready/<filename>.md",
  mode: "auto"
}
```

## Step 5 — What Happens Next

After spawning the first agent, explain what happens next based on the stack:

> The first agent is now working on **<feature title>**.
>
> **What happens automatically:**
>
> - The `Stop` hook runs `scripts/fast-verify.sh` after each agent response (if code changed)
> - The `TaskCompleted` hook runs the full verify pipeline before any task can be marked done
> - The `TeammateIdle` hook fires when a teammate finishes — logs pending work for your awareness
>
> **Handoff between stages:**
>
> When the current agent finishes (TeammateIdle fires), shut it down and spawn the next:
>
> ```
> SendMessage { type: "shutdown_request", recipient: "<current-agent>" }
> ```
>
> Then verify lifecycle compliance (Step 6), and spawn the next agent with `Agent`.
>
> **Frontend (build-first):** builder → test-writer → reviewer
>
> **Python/Rust (TDD):** test-writer → builder → reviewer
>
> **After the reviewer approves**, clean up:
>
> ```
> SendMessage { type: "shutdown_request", recipient: "reviewer" }
> TeamDelete {}
> ```
>
> **If the pipeline stalls** (agent stops mid-feature):
>
> - Features in `testing/` or `building/` are locked to the current agent
> - To unlock, move the doc back to `ready/` and source this file again

## Step 6 — Pipeline Orchestration (Between-Stage Verification)

Whether the pipeline runs via TeammateIdle hooks or manual orchestration, **verify lifecycle compliance between every stage**. Agents sometimes skip the doc-move and STATUS.md update steps. The `task-completed.sh` hook enforces this deterministically, but if you are orchestrating manually, check before launching the next agent.

**Critical: Per-feature sequential.** Within a single feature, only one agent works at a time. Do NOT launch the next agent until the current agent has **completed its task and gone idle**. Launching the builder while the test-writer is still running causes file conflicts. Multiple features may run in parallel if their `affected-files` don't overlap.

**Clean shutdown between roles.** When transitioning from one role to the next (e.g., builder → test-writer), send `shutdown_request` to all agents of the current role and verify they have fully terminated before spawning the next role. The Exit Protocol in agent definitions ensures agents stop after their report, but confirm they are no longer active before proceeding.

**Same-role parallelism.** You may spawn multiple `Agent` calls of the same role simultaneously. For example, launch 3 builders to work on different pieces of a feature, or launch builders for multiple non-overlapping features. All builders must finish before any test-writers start.

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
3. **Then spawn**:
   ```
   Agent {
     team_name: "feat-<feature-name>",
     name: "test-writer",
     subagent_type: "test-writer",
     prompt: "Pick up feature-docs/testing/<filename>.md",
     mode: "auto"
   }
   ```

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
3. **Then spawn**:
   ```
   Agent {
     team_name: "feat-<feature-name>",
     name: "reviewer",
     subagent_type: "code-reviewer",
     prompt: "Review feature-docs/review/<filename>.md",
     mode: "auto"
   }
   ```

### Python/Rust: Between test-writer and builder

**Wait for the test-writer to complete its task before proceeding.** If the test-writer is still running, do not launch the builder — both agents will edit overlapping files and cause conflicts.

After the test-writer finishes, verify before invoking the builder:

1. **Check the feature doc location**: `ls feature-docs/testing/<filename>.md`
   - If the file is still in `feature-docs/ready/`, the test-writer skipped the move step. Fix it:
     ```bash
     sed -i '' 's/status: ready/status: testing/' feature-docs/ready/<filename>.md
     mv feature-docs/ready/<filename>.md feature-docs/testing/
     ```
2. **Check STATUS.md**: `grep '<feature-name>' feature-docs/STATUS.md`
   - If no entry exists, add one showing `testing` status
3. **Then spawn**:
   ```
   Agent {
     team_name: "feat-<feature-name>",
     name: "builder",
     subagent_type: "builder",
     prompt: "Pick up feature-docs/testing/<filename>.md",
     mode: "auto"
   }
   ```

### Python/Rust: Builder Bounce-Back Detection

After the builder finishes (TeammateIdle or manual check), check whether it bounced back defective tests instead of completing implementation.

1. **Check where the feature doc is**: `ls feature-docs/testing/<filename>.md`
   - If the doc is in `testing/` (not `review/`), the builder may have bounced
   - If the doc is in `review/`, the builder completed normally — skip to "Between builder and reviewer"
2. **Check for a bounce file**: `ls feature-docs/testing/<filename>.bounce.md`
   - If NO bounce file exists, the builder stalled mid-work — see "If the pipeline stalls mid-stage"

**If a bounce file exists:**

1. Read the bounce file to understand what tests are defective
2. Check the `bounce-count` field in the feature doc frontmatter. If >= 3, escalate:

   > The builder has bounced tests back **<N>** times for **<feature title>**.
   > This likely indicates an ambiguity in the feature doc's acceptance criteria,
   > not just a test mechanics issue. Remaining defects:
   >
   > - [defects from bounce file]
   >
   > Options:
   >
   > - **Revise the feature doc** — clarify the acceptance criteria and restart
   > - **Override** — tell the builder to proceed despite the defects
   > - **Abandon** — move the doc back to `ready/` and revisit later

3. If bounce-count < 3, re-invoke the test-writer in fix mode:

   ```
   Agent {
     team_name: "feat-<feature-name>",
     name: "test-writer",
     subagent_type: "test-writer",
     prompt: "Fix defective tests per feature-docs/testing/<filename>.bounce.md",
     mode: "auto"
   }
   ```

4. After the test-writer completes, verify the bounce file was deleted:
   `ls feature-docs/testing/<filename>.bounce.md` should fail (file deleted)

5. Re-invoke the builder:

   ```
   Agent {
     team_name: "feat-<feature-name>",
     name: "builder",
     subagent_type: "builder",
     prompt: "Pick up feature-docs/testing/<filename>.md — tests have been fixed after bounce-back.",
     mode: "auto"
   }
   ```

6. Continue with normal "Between builder and reviewer" flow

### Python/Rust: Between builder and reviewer

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
3. **Then spawn**:
   ```
   Agent {
     team_name: "feat-<feature-name>",
     name: "reviewer",
     subagent_type: "code-reviewer",
     prompt: "Review feature-docs/review/<filename>.md",
     mode: "auto"
   }
   ```

### After reviewer approves

1. **Verify doc moved to completed**: `ls feature-docs/completed/<filename>.md`
2. **Update STATUS.md** if the reviewer did not
3. **Check for non-blocking issues** in the review report. If the reviewer flagged follow-ups, present them to the user:

> The reviewer approved the feature but flagged these non-blocking issues:
>
> 1. [issue from review report]
> 2. [issue from review report]
>
> Would you like to:
>
> - **Create follow-ups** — route each through the TDD pipeline
> - **Skip** — ship as-is and track them separately
> - **Mark as blocking** — move the doc back to `ready/` and route through the full TDD pipeline

4. **Update ideation README** (if applicable): Read the feature doc's `ideation-ref` frontmatter field. If it points to an ideation folder with a README, update it:

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

5. **Clean up the team**:

   ```
   SendMessage { type: "shutdown_request", recipient: "reviewer" }
   TeamDelete {}
   ```

6. The feature branch is ready for PR (unless the user chose to fix follow-ups first)

### If the reviewer flags blocking issues

The reviewer reports issues back to the coordinator — it **never fixes code itself**. The coordinator reads the review report and determines the routing. This triggers an automatic rework loop — no human intervention needed unless it stalls.

**Determine the routing:**

Read the review report and classify each issue:

- **Implementation issues** (wrong logic, missing error handling, convention violations, dead code, unused imports): route to the **builder**
- **Test gaps** (missing E2E coverage for frontend, missing test coverage for Python/Rust): route to the **test-writer**, then back through the appropriate pipeline

**Implementation-only rework cycle** (builder → reviewer):

1. **Verify the doc location**: `ls feature-docs/building/<filename>.md`
   - If the reviewer didn't move it back, move it: `sed` the status to `building`, `mv` to `feature-docs/building/`
2. **Check STATUS.md** reflects `building` status — update if the reviewer did not
3. **Spawn the builder** with the specific issues:
   ```
   Agent {
     team_name: "feat-<feature-name>",
     name: "builder",
     subagent_type: "builder",
     prompt: "The reviewer found issues with feature-docs/building/<filename>.md:\n- [specific issue 1]\n- [specific issue 2]\nFix these and move the doc back to review/ when tests pass.",
     mode: "auto"
   }
   ```
4. **Wait for the builder to complete**, then re-spawn the reviewer (follow the "Between builder and reviewer" steps above)

**Test-gap rework cycle:**

For **frontend**: move the doc back to `testing/`, re-invoke the test-writer to add missing E2E tests, then back to reviewer.

For **Python/Rust**: move the doc back to `ready/`, re-invoke the test-writer to add failing tests, then builder, then reviewer — full TDD cycle.

1. Move the doc to the appropriate directory (`testing/` for frontend, `ready/` for Python/Rust)
2. **Update STATUS.md** to reflect the new status
3. **Spawn the test-writer** with the specific gaps:
   ```
   Agent {
     team_name: "feat-<feature-name>",
     name: "test-writer",
     subagent_type: "test-writer",
     prompt: "The reviewer found test gaps in feature-docs/<dir>/<filename>.md:\n- [missing test coverage for X]\n- [wrong expectation in Y test]\nAdd or fix tests for these issues.",
     mode: "auto"
   }
   ```
4. **Wait for the test-writer to complete**, then continue the pipeline for your stack

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

3. **Route through the full pipeline** for your stack (frontend: builder → test-writer → reviewer, Python/Rust: test-writer → builder → reviewer)
4. Even for trivial fixes — route through agents. The pipeline proves the fix is correct.

### If the pipeline stalls mid-stage

If an agent exits without completing lifecycle steps:

1. Check which directory the feature doc is actually in: `ls feature-docs/*/<filename>.md`
2. Check the `status:` field in the frontmatter: `head -5 feature-docs/*/<filename>.md`
3. If the status and directory are out of sync, fix them manually
4. Re-launch the appropriate agent for the current stage

---

Start with Step 1 now.
