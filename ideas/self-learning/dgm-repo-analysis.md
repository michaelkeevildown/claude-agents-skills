# DGM-Inspired Analysis: Closing the Feedback Loop in claude-agents-skills

**Date:** 2026-02-13
**Reference:** [darwin-godel-machine-summary.md](darwin-godel-machine-summary.md)

**TLDR:** This repo has solid agent definitions, a well-designed verification system, and a disciplined lifecycle. But the feedback arc is open -- agents execute and accumulate local memory, yet nothing flows back to improve the agent definitions or skills themselves. The Darwin Godel Machine paper shows exactly how to close that loop.

---

## 1. What This Repo Does

`claude-agents-skills` is a template repository of reusable Claude Code agent definitions, technology skill documentation, and infrastructure that gets installed into downstream projects via `setup.sh`.

### Core Components

| Component           | Count                | Purpose                                                                               |
| ------------------- | -------------------- | ------------------------------------------------------------------------------------- |
| Agent definitions   | 11                   | Markdown files with YAML frontmatter defining agent roles, processes, and constraints |
| Skill documents     | 12 complete, 5 stubs | Technology reference docs agents consult before starting work                         |
| Hook scripts        | 5 types              | Shell scripts that enforce quality gates at key lifecycle points                      |
| Verify scripts      | 3 stacks             | Stack-specific verification pipelines (format + type check + lint + test)             |
| Feature-docs system | 6 lifecycle stages   | Directory-based state machine for coordinating multi-agent feature development        |

### The Agent-Teams Workflow

The central workflow coordinates three agent roles in a test-first development cycle:

```
test-writer (sonnet)     builder (opus)        code-reviewer (opus)
     |                        |                       |
     | Reads feature doc      | Reads failing tests   | Reviews implementation
     | Writes failing tests   | Implements until green | Flags issues or approves
     | Moves doc to testing/  | Moves doc to review/   | Moves doc to completed/
     |                        |                        | (or back to building/)
     v                        v                        v
  ready/ --> testing/ --> building/ --> review/ --> completed/
```

The physical location of a `.md` file IS the state. Nobody grades their own homework -- test-writers never implement, builders never modify tests, reviewers never fix code.

---

## 2. Repo Architecture Review

### Agent Structure (Consistent 5-Section Pattern)

All 11 agents follow a rigid structure defined in `agents/CLAUDE.md`:

1. **Role Statement** -- single sentence: "You are a [role]. Your job is to [function]."
2. **Before You Start** -- context-gathering: read memory, read CLAUDE.md, read skills, scan code
3. **Process** -- the main operational workflow (single process or multi-workflow selection)
4. **Output Format** -- fenced code block template of what the agent produces
5. **Memory Updates** -- what to persist after each session

Model assignment: `opus` for complex reasoning (code-reviewer, builder, frontend-engineer), `sonnet` for structured throughput (planner, test-writer, component-builder).

### Verification System (2-Tier)

| Tier        | Trigger                                      | What It Checks                         | Speed   |
| ----------- | -------------------------------------------- | -------------------------------------- | ------- |
| Fast verify | Stop hook (every response with file changes) | Type checking only                     | Seconds |
| Full verify | TaskCompleted hook                           | Format + type check + lint + all tests | Minutes |

The Stop hook (`verify-scripts/stop-hook.sh`) includes loop detection -- after 3 consecutive failures, it allows the agent to stop to prevent infinite retry loops. This mirrors Carlini's `--fast` mode from the Anthropic C compiler blog post.

### Memory System

Every agent has `memory: user` in its frontmatter, enabling persistent memory across sessions. Agents read memory before starting work and write structured insights after completing work. This creates a cross-session improvement loop for project-specific knowledge.

### Safety Infrastructure

- `guard-bash.sh` blocks `rm -rf /`, `git push --force`, `DROP TABLE`, and commits on main (when `feature-docs/` exists)
- Completion gates in test-writer and builder agents enforce mandatory verification before marking tasks done
- `task-completed.sh` enforces lifecycle compliance (status/directory sync, feature-id uniqueness) on top of the full verify pipeline

---

## 3. Mapping DGM Concepts to This Repo

The Darwin Godel Machine paper identifies six mechanisms that enable self-improving agents. Here's how each maps to the current state of this repo.

### 3.1 Self-Improvement Loop

**DGM:** Agents iteratively modify their own source code. The agent and meta-agent are the same entity -- improvements to coding ability directly improve self-modification ability.

**This repo:** There is no self-improvement loop. Agent definitions are static Markdown files authored by humans. The `memory: user` system captures project-specific knowledge (e.g., "this project uses tab-isolated Zustand stores"), not meta-knowledge about how to be a better agent (e.g., "when acceptance criteria mention store mutations, always check the existing selector pattern first").

Memory is project-local and agent-instance-local. It never flows back to improve the agent definition itself in this template repo. The code-reviewer never says "I keep finding the same issue; the builder's prompt should mention this."

**Gap:** HIGH. The framework evolves only when a human reads memory files and manually updates agent definitions.

### 3.2 Open-Ended Archive

**DGM:** Maintain a diverse archive of agent variants. Temporarily worse mutations can serve as stepping stones. The paper shows cases where an agent's score temporarily fell below its parent at iteration 4, but exploration along that path produced the best agent at iteration 56+.

**This repo:** One canonical version of each agent per stack. No versioning, no variant archive, no A/B testing of different prompt strategies. `setup.sh` copies a single version into downstream projects.

**Gap:** MEDIUM. The single-version approach works for a template repo used by a small team, but there's no room for task-specialized variants.

### 3.3 Empirical Validation

**DGM:** Replace formal proofs with empirical validation on benchmarks. Measure performance, not just correctness.

**This repo:** The verification system is binary pass/fail. It answers "did this agent succeed?" not "how well did this agent perform?" There is no tracking of:

- Token consumption per feature
- Number of rework cycles (the circuit breaker exists at 3 round-trips in `feature-docs/implement-feature.md`, but the count is ephemeral)
- Time per lifecycle stage
- Frequency and reasons for reviewer rejections
- Frequency of stuck detection triggers (30-minute threshold in `verify-scripts/teammate-idle.sh`)

**Gap:** HIGH. Without measurement, you cannot close the feedback loop. This is the foundation for everything else.

### 3.4 Staged Evaluation

**DGM:** Stage 1 (10 tasks) verifies basic editing functionality. Stage 2 (50 tasks) measures performance. Stage 3 (200 tasks, only top performers) is full evaluation.

**This repo:** The 2-tier verification maps well:

| DGM Stage                                | Repo Equivalent                                           |
| ---------------------------------------- | --------------------------------------------------------- |
| Stage 1 (basic functionality)            | Stop hook / fast-verify (type checking only)              |
| Stage 2 (performance)                    | TaskCompleted / full verify (format + type + lint + test) |
| Stage 3 (full eval, top performers only) | Code reviewer (quality judgment)                          |

**Gap:** LOW-MEDIUM. The staged verification is well-designed. The gap is that it measures correctness, not quality. A third stage measuring code complexity, reviewer rejection rate, or pattern adherence would complete the mapping.

### 3.5 Transfer Learning

**DGM:** Agents trained on Python achieved comparable performance on C++, Rust, etc. Skills transfer across languages and benchmarks.

**This repo:** Cross-stack sharing is done via copy-paste with minor edits. The builder and test-writer agents are ~70% identical across frontend, Python, and Rust -- roughly 100 lines of shared lifecycle process and 40-50 lines of stack-specific content. If the process changes (e.g., adding a step between verification and review), three files must be updated manually.

The universal agents (code-reviewer, planner) demonstrate a better pattern -- they exist once in `agents/universal/` and work across all stacks. But test-writer and builder can't be universal because they contain stack-specific tool commands.

**Gap:** MEDIUM. The structural duplication works but creates maintenance burden and drift risk.

### 3.6 Tool Enhancement Discovery

**DGM:** Without human guidance, agents independently invented fine-grained file viewing, precise file editing, code search, integrated test runners, multi-attempt strategies, and peer review.

**This repo:** Agents are given a fixed set of Claude Code tools via their frontmatter `tools` field. They cannot discover, compose, or create new tools. Interestingly, the framework has already manually implemented several patterns DGM agents discovered independently:

- Peer review (code-reviewer agent)
- Integrated test runners (verify scripts and hooks)
- Multiple solution attempts with evaluation (rework cycle: builder -> reviewer -> builder, up to 3 cycles)
- Previous failures as context (builder reads failing test output; rework cycle passes reviewer issues back)

**Gap:** MEDIUM. Agents can't record effective tool compositions. A builder that discovers a useful grep pattern for finding store access patterns can't codify it into a reusable reference.

---

## 4. Consistency Issues Found

These are quick wins that resolve asymmetries the team review uncovered.

### 4.1 Rust Code-Reviewer Missing Constraints Section

The universal code-reviewer (`agents/universal/code-reviewer.md:67-73`) has an explicit `## Constraints` section enforcing read-only behavior. The Rust code-reviewer (`agents/rust/code-reviewer.md`) lacks this entirely. While the tool restriction (`Read, Grep, Glob, Bash`) implicitly prevents editing, the explicit constraints section is a useful prompt-level reinforcement.

**Fix:** Add a `## Constraints` section to `agents/rust/code-reviewer.md` between `## Output Format` and `## Memory Updates`, mirroring the universal reviewer's pattern.

### 4.2 Universal Code-Reviewer Missing Verdict Line

The Rust code-reviewer (`agents/rust/code-reviewer.md:103-112`) includes a summary with a verdict line (`APPROVE / REQUEST CHANGES / NEEDS DISCUSSION`). The universal code-reviewer has no verdict in its output format. The `feature-docs/implement-feature.md` coordinator expects to read a verdict from the reviewer to determine routing, so this is a functional gap.

**Fix:** Add a summary block with severity counts and verdict line to `agents/universal/code-reviewer.md`, after the output format section.

### 4.3 Verify Scripts Documentation Behind Reality

`verify-scripts/CLAUDE.md` documents "Three Stages" (type check, lint, test) and shows a 3-stage template. But all actual verify scripts have **four stages** -- format checking runs first:

- Frontend: `npx prettier --check .`
- Python: `ruff format --check .`
- Rust: `cargo fmt -- --check`

**Fix:** Update `verify-scripts/CLAUDE.md` to document four stages, update the template, and add a Format column to the existing scripts table.

### 4.4 Tail Line Count Inconsistency

Rust agents use `tail -30` while all other agents use `tail -20`:

| File                           | Current    | Expected   |
| ------------------------------ | ---------- | ---------- |
| `agents/rust/builder.md`       | `tail -30` | `tail -20` |
| `agents/rust/test-writer.md`   | `tail -30` | `tail -20` |
| `agents/rust/code-reviewer.md` | `tail -30` | `tail -20` |

**Fix:** Normalize to `tail -20` across all three Rust agent files.

### 4.5 Five Stub Skills

Agents in the Python and Rust stacks reference skills that are stubs (18 lines, just TODOs):

| Stub Skill                                   | Referenced By                      |
| -------------------------------------------- | ---------------------------------- |
| `skills/python/fastapi/SKILL.md`             | Python test-writer, Python builder |
| `skills/python/testing-pytest/SKILL.md`      | Python test-writer, Python builder |
| `skills/python/neo4j-driver-python/SKILL.md` | Python builder                     |
| `skills/rust/testing-rust/SKILL.md`          | Rust test-writer, Rust builder     |
| `skills/rust/neo4j-driver-rust/SKILL.md`     | Rust builder                       |

This means Python and Rust agents operate with significantly less contextual knowledge than frontend agents (which have 8 complete skills, 400-940 lines each).

**Fix:** Deferred -- each stub requires 400-900 lines of domain content. The retrospective agent (proposed in section 5.3) will surface these as skill gaps once metrics show higher failure rates on those stacks, providing natural prioritization.

---

## 5. Proposed Improvements

### Phase 1: Consistency Fixes

Apply the fixes from section 4.1-4.4. These are small, targeted edits with no dependencies between them.

**Files modified:**

- `agents/rust/code-reviewer.md` -- add Constraints section, normalize tail count
- `agents/universal/code-reviewer.md` -- add verdict/summary to output format
- `verify-scripts/CLAUDE.md` -- document 4 stages instead of 3
- `agents/rust/builder.md` -- normalize tail count
- `agents/rust/test-writer.md` -- normalize tail count

### Phase 2: Metrics Collection

**DGM parallel:** "Empirical validation on benchmarks" -- you can't improve what you don't measure.

#### New file: `verify-scripts/emit-metric.sh`

A POSIX-compatible shell function that appends JSON Lines to `agent_logs/metrics.jsonl`. Uses only `printf` and `>>` -- no `jq` dependency for writing. Sourced by other scripts.

#### Event Schema

Six event types, all sharing an envelope:

```json
{
  "timestamp": "ISO 8601 UTC",
  "event": "event_type",
  "feature_id": "feat-xxxx",
  "feature_title": "Feature Name",
  "agent": "emitter identity",
  "data": {}
}
```

| Event               | Emitted By        | When                                      |
| ------------------- | ----------------- | ----------------------------------------- |
| `stage_transition`  | coordinator       | Feature doc moves between lifecycle dirs  |
| `verify_result`     | task-completed.sh | After verify pipeline runs (pass or fail) |
| `review_verdict`    | coordinator       | After code-reviewer produces a verdict    |
| `rework_cycle`      | coordinator       | Feature sent back from review             |
| `stuck_warning`     | teammate-idle.sh  | Feature in building/ > 30 minutes         |
| `pipeline_complete` | coordinator       | Feature reaches completed/                |

#### Hook Instrumentation

- `verify-scripts/task-completed.sh`: Source `emit-metric.sh`, emit `verify_result` after verify pipeline runs (both success and failure paths)
- `verify-scripts/teammate-idle.sh`: Source `emit-metric.sh`, emit `stuck_warning` when the 30-minute threshold fires

#### Coordinator Metrics

Add a "Metrics Capture" section to `feature-docs/implement-feature.md` instructing the coordinator to emit `stage_transition`, `review_verdict`, `rework_cycle`, and `pipeline_complete` events. The coordinator is the right place for these because it orchestrates all stage transitions and routing decisions.

**Design choice -- JSONL over SQLite or CSV:**

- No runtime dependencies (only `printf` and `>>` to write)
- Append-only (concurrent agents writing from different hooks won't corrupt the file)
- Self-describing (each line is a complete JSON object)
- Greppable (one event per line)

### Phase 3: Retrospective Agent

**DGM parallel:** "Analyzes its own benchmark evaluation logs" and "proposes the next feature to implement." This is the step that closes the feedback loop.

#### New file: `agents/universal/retrospective.md`

A read-only analysis agent (~120 lines, model: `opus`) that:

1. **Gathers data** -- reads `agent_logs/metrics.jsonl`, computes rework cycles, verify failure rates, stuck features, rejection patterns
2. **Reads context** -- completed feature docs, verbose verify output logs, current agent definitions and skills
3. **Identifies patterns** -- recurring verify failures, frequent review rejections, stuck features, skill gaps, rework patterns
4. **Produces ranked suggestions** -- specific, actionable changes to agent definitions or skill docs, each citing specific metrics as evidence, ranked HIGH/MEDIUM/LOW by impact

The retrospective agent is strictly read-only. It reports -- it never modifies files. Every suggestion must cite specific metrics or log entries. Speculation without evidence is prohibited.

**Why human-in-the-loop for applying suggestions:**

Agent definitions are high-leverage files. A bad change to a builder definition affects every future feature. The DGM paper uses staged evaluation (10 -> 50 -> 200 tasks) before accepting changes. Without that evaluation infrastructure, human review is the safety gate. This maps to the DGM paper's "constitutional safety" concept -- unmodifiable system components that evaluate the rest.

#### Output Format

The retrospective produces a structured report:

```
## Retrospective Report
**Period**: date range
**Features analyzed**: N completed, N in progress

### Key Metrics
- Rework cycles: avg per feature
- Verify failure rate: %
- Most common failure stage
- Stuck features: count
- Review rejection rate: %

### Patterns Identified
(each with evidence, impact, root cause)

### Suggestions (ranked by impact)
- HIGH: changes that would have prevented 3+ issues
- MEDIUM: changes that would have prevented 1-2 issues
- LOW: nice to have

### Comparison to Previous Retrospective
(what improved, what stayed the same, which suggestions were adopted)
```

**Recommended cadence:** Run after every 3-5 completed features, or when the pipeline feels inefficient.

### Phase 4: Agent-Teams Skill Update

Add a `## 13. Pipeline Metrics` section to `skills/global/agent-teams/SKILL.md` documenting:

- The event types and schema
- The `emit-metric.sh` utility
- When to run retrospective analysis
- Healthy metric ranges:

| Metric                        | Healthy Range | Warning Sign                         |
| ----------------------------- | ------------- | ------------------------------------ |
| Rework cycles per feature     | 0-1           | >2 consistently                      |
| Verify failure rate           | <30%          | >50%                                 |
| Same stage failing repeatedly | Varies        | Missing guidance in agent definition |
| Stuck features                | 0             | >1 means specs are ambiguous         |
| Review rejection rate         | <40%          | >60%                                 |

Add anti-patterns:

- "No metrics collection" -- pipeline runs blind, improvements are guesswork
- "Running retrospective without data" -- need 3-5 completed features minimum
- "Retrospective suggestions never adopted" -- analysis happens but definitions never change

---

## 6. The DGM Loop Applied

Here's how the current and proposed systems compare to the DGM iteration loop:

### Current State

```
Human writes agent definition
    |
    v
Agent executes (test-writer -> builder -> reviewer)
    |
    v
Verification (pass/fail)
    |
    v
Agent memory captures project-specific patterns
    |
    v
(nothing) -- human must manually read memory and update definitions
```

### Proposed State

```
Human writes agent definition
    |
    v
Agent executes (test-writer -> builder -> reviewer)
    |
    v
Verification (pass/fail) + Metrics collection (structured JSONL)
    |
    v
Agent memory captures project-specific patterns
    |
    v
Retrospective agent reads metrics + logs + completed features
    |
    v
Retrospective produces ranked suggestions with evidence
    |
    v
Human reviews and applies suggestions to agent definitions
    |
    v
Improved agent definition (loop restarts)
```

The key difference: the proposed system adds the **measurement** (Phase 2) and **analysis** (Phase 3) steps that convert the open feedback arc into a closed loop. The human remains in the loop for applying changes -- this is the safety gate until staged evaluation infrastructure exists.

---

## 7. Future Work

These are real gaps the analysis identified but that warrant separate planning:

### Stub Skill Content

Five skills are stubs (18 lines each). Each needs 400-900 lines of domain content. The retrospective agent will surface these as skill gaps once metrics show higher failure rates on those stacks, providing evidence-based prioritization.

### Cross-Stack Deduplication

The builder and test-writer agents are ~70% identical across 3 stacks. A template/composition system (shared lifecycle + stack-specific overrides) would reduce duplication from 3x to 1x+overrides. This is a significant architectural change -- the current structure at `agents/{frontend,python,rust}/builder.md` has roughly 100 lines of shared process and 40-50 lines of stack-specific content.

### Python Code-Reviewer

Rust has a stack-specific code-reviewer with deep checks (ownership, async safety, unsafe audit). Python has no equivalent for Python-specific concerns (asyncio, type hints, Pydantic, import patterns). Retrospective data will show if this causes measurable quality gaps.

### Agent Variant Archive

DGM's archive of agent variants with selection. Instead of one canonical `builder.md` per stack, maintain a directory of variants. The coordinator selects a variant based on task characteristics. Requires metrics infrastructure to compare variant performance.

### Auto-Application of Retrospective Suggestions

The full DGM loop modifies agent code automatically. This analysis stops at human review. A future phase could add "shadow evaluation" -- run a modified agent on a test feature, compare metrics to the baseline, and adopt the change only if metrics improve. This requires the evaluation infrastructure from Phase 2 to be mature.

---

## 8. Files Summary

### Modified (Phases 1-4)

| File                                 | Change                                             |
| ------------------------------------ | -------------------------------------------------- |
| `agents/rust/code-reviewer.md`       | Add Constraints section; normalize tail -30 to -20 |
| `agents/universal/code-reviewer.md`  | Add verdict/summary to output format               |
| `verify-scripts/CLAUDE.md`           | Document 4 stages instead of 3                     |
| `agents/rust/builder.md`             | Normalize tail -30 to -20                          |
| `agents/rust/test-writer.md`         | Normalize tail -30 to -20                          |
| `verify-scripts/task-completed.sh`   | Source emit-metric.sh, emit verify_result          |
| `verify-scripts/teammate-idle.sh`    | Emit stuck_warning metric                          |
| `feature-docs/implement-feature.md`  | Add metrics capture + retrospective trigger        |
| `setup.sh`                           | Copy emit-metric.sh to scripts/                    |
| `skills/global/agent-teams/SKILL.md` | Add metrics section + anti-patterns                |
| `agents/CLAUDE.md`                   | Add retrospective to agents table                  |
| `CLAUDE.md`                          | Add retrospective to content inventory             |

### Created (Phases 2-3)

| File                                | Purpose                                                               |
| ----------------------------------- | --------------------------------------------------------------------- |
| `verify-scripts/emit-metric.sh`     | POSIX shell function for emitting structured JSONL metrics            |
| `agents/universal/retrospective.md` | Read-only analysis agent that reads metrics and suggests improvements |
