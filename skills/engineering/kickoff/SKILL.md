---
name: kickoff
description: Capability-audit gate before substantial new work. Map the task to the skills, agents, tools and CLAUDE.md instructions that already exist, flag any risk of rebuilding something the repo already has, then propose a plan and wait for go. Use before building a feature, asset, refactor or multi-file change, and when the person says "kickoff", "before we start", "plan this first", "scope this", "how should we approach this", "does this already exist", "check for prior art", "audit before we build". Skip for one-line fixes and quick questions.
---

# Kickoff: capability audit before building

A gate before substantial new work. It exists for one reason: make sure you stand on the shoulders of
past sessions rather than rebuilding something that already exists as a skill, an agent, a CLAUDE.md
instruction or a tool. It pairs with the review and retro habit, which leaves the shoulders a bit
higher each time.

This gate runs **once you know the task** and before you write anything. It is not a session-opening
orientation routine and it does not gather data; it audits what the repo can already do against what
you are about to build.

**Bind to the project.** The manifest at `.claude/PROJECT.md` is already in context via the
`CLAUDE.md` import, and its bindings live in the **`## Bindings` tables in its prose body**: resolve
`repo.default_branch` and every other dotted key below from there by name. If the manifest is
genuinely absent, do not guess a value: name the binding you could not resolve, audit only what you
can establish without it, and never invent a repo slug, label or branch name to fill the hole.

## When to skip

If the task is trivial (a one-line fix, a quick question, a single-file edit), say so and just do it.
Do not run the full gate for a variable rename. Use judgement. The escape hatch is what keeps this
useful rather than ceremonial.

## What you already have for free

Do not re-read files the harness already loaded. Every session already gives you:

- **CLAUDE.md** (root plus nested) loaded into context, and with it the project manifest, whose
  `## Bindings` tables you read by dotted key name.
- The **skills list** in a system reminder.
- Any **standing preference or convention document** the project names in its CLAUDE.md. Read it
  before generating anything, from wherever that CLAUDE.md says it lives.

So skip the "report everything" inventory. Name only the assets **relevant to this task**.

## Step 1: restate the task

State back, in your own words:

1. The objective as you understand it.
2. Any constraints or success criteria you have inferred, reconciled against the project's stated
   conventions (its CLAUDE.md files, its contributing guide, its preference document).
3. Anything ambiguous that needs clarifying before starting.

Wait for confirmation or correction.

## Step 2: map task to existing capabilities

**First, make the audit current: fetch the canonical remote branch.** The "does this already exist"
judgement is only valid against the canonical remote branch, `origin/<repo.default_branch>` from the
manifest. Concurrent worktrees and an un-pulled branch routinely leave the local branch behind the
remote, so a skill, agent, tool or feature can exist on the remote yet be absent from a stale local
tree, and concluding "gap, build it" from that is the exact duplication this gate exists to prevent.
Run `git fetch origin`, check the gap:

```bash
git rev-list --left-right --count HEAD...origin/<repo.default_branch>
```

and when behind read the prior art via `git show origin/<repo.default_branch>:<path>` or
`git diff HEAD...origin/<repo.default_branch>` before mapping. A sibling process can move the local
branch mid-session, so do not trust a "missing" read taken before the fetch.

Given the task, identify:

1. **Direct hits**: skills, agents (whatever is registered in `.claude/agents/`) or tools clearly
   designed for this exact work. Name them and confirm you will use them.
2. **Partial hits**: assets that cover part of it and could be combined or extended.
3. **Gaps**: parts where nothing existing applies and you work from first principles.
4. **Risk of duplication**: any temptation to build something new that overlaps an existing asset.
   **Flag it explicitly.** This is the highest-value check: building new feels productive even when
   extending the existing thing is correct. Surface it so the person can decide.

## Step 3: propose a plan

Proportionate to the task. A small task gets a small plan; do not pad.

1. The sequence of steps.
2. Which existing capability you lean on at each step.
3. Where the hard parts are.
4. Any decisions needed from the person (scope boundaries, output format, library choices).

For anything substantial or parallelisable, prefer parallel multi-agent execution, per the root
CLAUDE.md. When ultracode is on, implement the fan-out as a **Workflow**, naming the specialists via
`agentType` from `.claude/agents/`, one task per specialist. Reserve `TeamCreate` for interactive,
long-running collaboration (tmux panes). Either way the wait-for-go gate below still holds: the
fan-out only starts after the person approves the plan in Step 4.

## Step 4: wait for go

Stop and wait for "go", "proceed", or amendments. Do not start until confirmed.

**Unless a caller has suspended this gate.** An autonomous issue or epic driver runs kickoff as a
**self-audit, not an approval gate**: record the plan where the work is logged (a comment on the
issue), then proceed. Never sit waiting for a human who is not there, and never treat "I would like a
decision" as a reason to halt: the only legitimate interrupt is a genuine owner-only design question,
and even that gets posted to the issue rather than held in a stalled session.

## Rules

- British English. No em-dashes or en-dashes.
- Be honest if the audit turns up nothing relevant. Do not invent connections.
- If a direct hit exists, use it. Do not freestyle a parallel solution out of preference.

## Output format

Shape the restate, the plan and the proposal for the reader. Where the project states its own
output-format preference, that document is canonical and wins; these are the defaults:

- **Lead with the answer**: one **bold** line first, then the support.
- **Short paragraphs**: two or three short sentences at most, blank line between.
- **Bullets over prose**, each starting with a **bold keyword**, around seven per list at most.
- **Numbers in small tables**, never woven into sentences.
- **Long answers get predictable headings**: Answer, Why, What to do, Want more?
- **Never a wall of text**: depth stays on tap ("want the detail?"), not dumped.
