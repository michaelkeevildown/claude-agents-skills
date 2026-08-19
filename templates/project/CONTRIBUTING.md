# Contributing to {{REPO_NAME}}

Scaffolded by `setup.sh --bootstrap` on {{TODAY}}. The two sections below are **bound by
`.claude/PROJECT.md`** (`checklist.path` / `checklist.section` and `tier.path` / `tier.section`),
which means the vendored skills read them by their exact heading text. Edit the content freely;
**if you rename a heading, update the binding in the same commit** — a binding that resolves
nowhere is a could-not-run, not a pass, and `/create-issue` degrades to a floor-only check.

## 1 · Workflow

Work is tracked as issues and built through branch → gate → PR. Never commit straight to the
default branch. The vendored `implement-issue` skill does this end-to-end in a worktree.

## 2 · Issues

Every issue body follows the vendored `create-issue` skill. Read that skill for the authoring rules
— they are not restated here, because a rule living in two places drifts. This file holds only what
is specific to **this repo**.

### Requirement-quality checklist (CHK)

Bound as `checklist.section`. `/create-issue` runs this before filing and posts the result. Each
item is pass/fail on the issue as written, not on intent.

| ID     | Check                                                                                                                                                 |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| CHK-1  | The title names the defect or capability and its consequence, not the area.                                                                           |
| CHK-2  | Every acceptance criterion is GIVEN/WHEN/THEN and names exact functions, fields, errors, or return shapes.                                            |
| CHK-3  | At least one criterion is an **outcome** at production configuration — not a mechanism that could be fully satisfied while the feature does not work. |
| CHK-4  | A bug fix carries a criterion that reverting it makes a **named** test fail, behaviourally.                                                           |
| CHK-5  | For a localised fix: the seam, the placement, the do-not-touch list, and the failure direction are stated.                                            |
| CHK-6  | Failure and edge cases are covered, each with exact expected behaviour — never "handles gracefully".                                                  |
| CHK-7  | Out of Scope names the specific temptation and the risk of doing it anyway.                                                                           |
| CHK-8  | `## Security Implications` is filled in — what it touches, or "none" **with the reason**.                                                             |
| CHK-9  | Every behavioural claim in Technical Notes was checked against the implementation, and anything unconfirmed is marked unverified.                     |
| CHK-10 | Dependencies are stated as `Depends on #NNN` or explicitly "none".                                                                                    |
| CHK-11 | If part of an epic: the native sub-issue link **and** the inline `#NNN` body reference both exist.                                                    |
| CHK-12 | The body stands alone — no comment contradicts it.                                                                                                    |

**Version this list.** When you add or reword an item, say so in the commit: a skill citing "CHK-7"
in a posted comment must mean the same thing next month.

### Build tier — every issue declares its model AND its effort

Bound as `tier.section`. Two labels resolve how an autonomous build fires an issue: a `model:`
label and an `effort:` label.

- **`model:`** ∈ `haiku` | `sonnet` | `opus`
- **`effort:`** ∈ `low` | `medium` | `high` | `xhigh`
- **Default when neither is present: `sonnet` / `medium`.**

That default is the point of the rule: an issue filed without labels is not blocked, it is quietly
**cheapened** — the right failure direction for a docs fix and the wrong one for a security or
production-data-path change. So set both deliberately and justify the choice in the body.

| Class       | Signal                                          | Model    | Effort   |
| ----------- | ----------------------------------------------- | -------- | -------- |
| Mechanical  | docs, config only, no logic                     | `haiku`  | `low`    |
| Standard    | one subsystem, clear ACs, established pattern   | `sonnet` | `medium` |
| Substantive | multi-file, new seam, revert-pin demanded       | `sonnet` | `high`   |
| Hard        | cross-cutting, security, production data path   | `opus`   | `high`   |
| Exceptional | genuinely novel, needs adversarial verification | `opus`   | `xhigh`  |

**Push UP** on: a non-trivial `## Security Implications`; the production data path; a demanded
revert-pin; a cross-tier change; a fix for a control that failed _silently_. **Push DOWN** on:
docs-only; a single file; a well-precedented or mechanical change.

**An unrecognised value must be refused, never forwarded.** A CLI that silently ignores an
`--effort` it does not know will run the build at the wrong tier while the record asserts otherwise.

## 3 · The gate

`bash .claude/scripts/gate.sh` is the one command a human, the hook, and CI all call. Exit `0` is
green, `2` is **could not run** (never a pass), anything else is red. A change that cannot prove the
tree is green does not open a PR.
