---
name: quality-gate
description: Run the project's canonical quality gate, the single command a human, the pre-commit hook and CI all call, then read its exit code honestly. Use before committing, before opening a PR, and whenever asked to "run the gate", "run the checks", "lint+tests", "run the tests", "is it green", "verify the tree is green", "gate it", "check this before I push", "did the gate pass".
---

# quality-gate: run the project's canonical gate

One command is the single source of truth for "is this tree green". A human, the git pre-commit hook
and CI all call the same thing, so the gate is defined in exactly one place and cannot drift between
them. This skill runs that command and reads the result honestly.

**Bind to the project.** The manifest at `.claude/PROJECT.md` is already in context via the
`CLAUDE.md` import, and its bindings live in the **`## Bindings` tables in its prose body**: read
`gate.command` and `gate.prereq` from there by dotted key name. If the manifest is genuinely absent,
do not guess a gate command and do not stop to ask for one: say plainly that the gate is
unresolvable and apply the could-not-run rule below (no PR, blocker on the issue, exit non-zero).

## Run it

1. **Satisfy `gate.prereq` first**, if the bindings table declares one. It is the dependency the gate needs
   but will not start for itself (a database container, a service, a build step). Skip it only when
   the environment already provides it: a headless runner often hands the gate its dependency
   ready-made, and re-running the prereq there is noise at best and a conflict at worst.
2. **Run `gate.command`.** Do not substitute the underlying tool it wraps, even when you know exactly
   what that is. The wrapper is what makes this instruction mean the right thing in every repo, and
   it is what carries the exit-code contract below. Arguments you pass are handed straight through.

`gate` is a required binding. If the bindings table carries no `gate` row there is no way to prove
the tree is green, and per the manifest's degrade rules that is fatal: do not open a PR.

## The exit-code contract

Judge on the exit status. Never judge on how the output looks.

| Exit               | Meaning                                           | What it demands                                                           |
| ------------------ | ------------------------------------------------- | ------------------------------------------------------------------------- |
| `0`                | **GREEN.** The gate ran, in full, and passed.     | Proceed. Cite the run in the PR body.                                     |
| `2`                | **COULD NOT RUN.** Nothing was proved either way. | Treat as **UNSATISFIED**. Not a pass, and not an ordinary failure either. |
| any other non-zero | **RED.** The gate ran and failed.                 | Fix the code, re-run, keep the failing output visible.                    |

**Exit 2 is the one that gets misread.** It means the gate never reached a verdict: a missing
delegate, a tool absent from PATH, an environment variable that short-circuits the run before a
single leg fires. The dangerous misreading is treating it as a pass. The second most dangerous is
treating it as a red and "fixing the failing test" that never ran. It is neither. Restore the
environment and get a real verdict.

**If you cannot get a real verdict, do not stop and wait for a human.** Headless there is nobody to
answer, and a driver's resume directive will override the stop anyway. The terminal action is: **do
not open the PR, post the blocker as a comment on the issue, and exit non-zero.**

**Honest limit.** Not every could-not-run can be told apart from a red. A missing prerequisite
usually surfaces as ordinary failing tests, which is exit 1 rather than exit 2. That direction fails
closed, which is safe, but do not read a 1 as proof your diff is at fault: satisfy `gate.prereq`,
re-run, and only then blame the code.

## Reporting

- **Never claim a green you did not see.** "The gate should pass" is not a gate run. If you did not
  run it in this session, say that.
- **On red, show the failing output**, not a paraphrase of it. The next reader needs the actual lines.
- **A bypassed gate is not a green gate.** `git commit --no-verify` skips a pre-commit hook that
  calls this same command. That is a legitimate escape hatch for a deliberate offline commit and it
  proves nothing about the tree. Say plainly that the gate did not run.
- **Fixers come from the gate's own output.** A failing lint or format leg names the command that
  fixes it. Run that, then re-run the **whole** gate: a partial re-run is not a verdict.
