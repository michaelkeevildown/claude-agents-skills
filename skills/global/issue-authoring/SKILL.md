---
name: create-issue
description: Writing GitHub Issues an autonomous agent can implement without guessing — GIVEN/WHEN/THEN acceptance criteria, the issue body structure, actionable Out-of-Scope and Rejected-approach notes, and the two-way epic ↔ sub-issue linkage that GitHub's UI and body-scanning scripts both depend on. Tracker-agnostic core; the project supplies its own scripts, labels, board, and design-system path.
---

# Issue Authoring

## When to Use

Load this whenever you are turning an idea, a bug report, or an epic line item
into one or more **GitHub Issues that an agent pipeline will implement**. It
covers the portable discipline — what makes an issue implementable, how to write
criteria a builder turns straight into code, and how to wire an issue into an
epic so both GitHub's UI and the project's own scripts can see it.

It does **not** know your project's scripts, label taxonomy, project-board field
names, stack-detection rules, or design-system file. Those are **project
bindings** — the slash command or `feature-docs/*.md` that loads this skill
supplies them. Keep them out of here so this skill stays true across every repo.

## The Bright Line: Implementable vs. Aspirational

An issue is implementable when an agent can read it and start writing code
without asking the author a single clarifying question. The test: **could two
different builders read this and produce the same observable behaviour?** If the
answer is no, the issue is aspirational and will produce divergent work.

Everything below exists to push issues across that line.

## Investigate from the canonical remote, not a stale checkout

Every section below is only as true as the code you read to write it. In a repo
with concurrent worktrees or an un-pulled branch, the local working tree
routinely lags (or diverges from) the canonical remote branch — usually
`origin/main` — so prior art, current behaviour, real file paths, and the "does
this already exist" judgement taken from the checkout can be a **stale-checkout
false negative**: you describe a world that has already moved, and the builder
inherits acceptance criteria that contradict the merged code.

Before the codebase due-diligence, **fetch and reconcile against the remote**:

```bash
git fetch origin
git rev-list --left-right --count HEAD...origin/main   # how far behind / ahead the canonical branch
```

If the checkout is behind, read the real state via `git show origin/main:<path>`
and `git diff HEAD...origin/main` (or branch/rebase onto `origin/main`), and cite
line numbers / symbols from there — not the lagging tree. Re-check mid-task: a
sibling process can advance your local branch underneath you and flip an earlier
"missing" finding. When the gap is large, add a one-line "branch from
`origin/main`" note to the issue so the implementer doesn't rebuild what already
merged. (If the project's canonical branch isn't `origin/main`, the project layer
names it.)

## Issue Body Structure

Use these sections, in this order. Omit a section only when it genuinely does
not apply (and say so — "no UI surface", "none", not silence).

```markdown
## Summary

One paragraph: what this does and why it needs to exist. Not how.

## Acceptance Criteria

1. GIVEN [exact precondition] WHEN [exact action] THEN [exact observable result]
2. ...

## Edge Cases

- [specific input or state] — [exact expected behaviour]

## Out of Scope

- [the specific temptation] — [why excluding it, and the risk if someone does it anyway]

## Technical Notes

- Constraints, patterns to follow, libraries to use
- **Rejected**: [approach considered] — [the specific failure mode that ruled it out]

## Affected Files

- `path/to/file` — what changes here

## Design Spec

> Only for issues with a visible UI surface. Omit (or "no UI changes in scope")
> otherwise. The project layer defines which design-system doc to cite.

## Dependencies

Depends on #NNN, or "none".
```

## Writing Acceptance Criteria

Name the functions, fields, error types, and return shapes. A criterion the
builder can turn directly into a test is worth ten that "describe the feature."

| Vague (agent guesses)     | Precise (agent implements)                                      |
| ------------------------- | --------------------------------------------------------------- |
| THEN the login works      | THEN `authenticate()` returns a `Session` with non-null `token` |
| THEN an error is shown    | THEN it throws `AuthError` with code `"INVALID_CREDENTIALS"`    |
| THEN the data is saved    | THEN `store.getState().session` contains the new `Session`      |
| THEN the field is removed | THEN the returned object has no `legacyField` key               |

Every criterion must be:

1. **Testable** — an automated test can verify it.
2. **Specific** — exact names, not categories.
3. **Independent** — does not require another criterion to pass first.
4. **Observable** — asserts a result a user or a test can see, not an internal
   intention ("THEN the component is well-structured" is not a criterion).

### Negative and edge criteria are first-class

The happy path is the easy half. For each criterion, ask: what is the failure
mode, the empty input, the already-in-that-state case? A feature whose ACs only
describe success will ship something that crashes on the first odd input. Put
those in **Edge Cases** with the exact expected behaviour — silently swallow,
throw a named error, no-op — never "handles gracefully".

## Writing Out of Scope That Actually Prevents Scope Creep

Name the specific temptation and the risk, not a vague boundary:

> Do NOT remove the deprecated `validateLegacy()` — it is still called by the
> admin module; removing it breaks `AdminAuthProvider`.

A bare "out of scope: legacy cleanup" tells the builder nothing about _which_
legacy code is load-bearing.

## Writing Technical Notes That Prevent Wrong Turns

When a non-obvious design decision was made, record the road not taken and _why_:

> **Rejected**: localStorage with an encryption wrapper. **Why**: XSS-accessible,
> no real protection — httpOnly cookies are invisible to JS entirely.

This stops a well-meaning builder from "improving" the design back into the
failure mode you already ruled out.

## One Issue or Several?

Split when the work crosses these seams — each becomes its own issue so it can
be reviewed, tested, and reverted independently:

- **Different surfaces** — a backend behaviour change and the UI that consumes it
  are two issues, linked by `Depends on`.
- **Independently shippable** — if half the work could merge today and add value
  with the other half unbuilt, it is two issues.
- **Different `Affected Files` with no overlap** — these can run in parallel; keep
  them separate so they can.

Keep together when splitting would create an issue that cannot be tested on its
own (a pure-internal helper with no observable behaviour belongs with its caller).

When one request fans out into several issues, the **first** thing to settle is
the dependency order — write the `Depends on #NNN` chain before drafting bodies,
because it determines which issue owns which file.

## Epic ↔ Sub-Issue Linkage (two-way, both required)

When an issue belongs to an epic, it must be linked **two ways**, because two
different consumers read two different things:

1. **Native sub-issue link** — what GitHub's UI renders (the parent's progress
   bar and the child's "Tracked by"). This is the _only_ thing the UI tracks.
2. **Epic body inline reference** — what humans and body-scanning scripts read: the
   sub-issue's `#NNN` inline in its `## Planned Sub-Issues` line (a numbered list, **no
   checkboxes**). GitHub strikes the reference through once the issue closes, so the body
   shows completion on its own — nothing to tick by hand.

Neither replaces the other. A child with only the body reference is invisible in the
UI tracker; a child with only the native link is invisible to scripts that parse
the epic body. Do both, every time.

### Native link — mind the gh version

`gh issue edit --add-parent` exists only in newer `gh`. On **gh 2.83.x and
earlier it is not available** — and `--json parent` returns empty unreliably, so
don't trust it to confirm the link either. Use the GraphQL `addSubIssue`
mutation directly, which works regardless of `gh` version:

```bash
# Resolve both node IDs, then link child under parent.
PARENT_ID=$(gh issue view <epic> --json id -q .id)
CHILD_ID=$(gh issue view <child> --json id -q .id)
gh api graphql -f query='
  mutation($parent:ID!, $child:ID!) {
    addSubIssue(input:{issueId:$parent, subIssueId:$child}) {
      issue { number }
    }
  }' -F parent="$PARENT_ID" -F child="$CHILD_ID"
```

Confirm the link with the `subIssues` query (not `--json parent`):

```bash
gh issue view <epic> --json id -q .id | xargs -I{} gh api graphql -f query='
  query($id:ID!){ node(id:$id){ ... on Issue {
    subIssues(first:50){ nodes { number title } } } } }' -F id={}
```

### Body line (inline `#NNN`, never a checkbox)

The `## Planned Sub-Issues` list is a **numbered list whose every item carries its
sub-issue's `#NNN` inline**. Do not use a task-list checkbox: an inline `#NNN`
auto-renders the issue's live state — GitHub strikes it through when it closes — so the
epic shows completion with zero upkeep. A checkbox has to be hand-ticked on merge and
silently drifts.

Fetch the epic body, rewrite the whole `## Planned Sub-Issues` section so each line is
`N. #<child> — **Title** — description`, write the whole body back (fetch, modify,
replace — never hand-edit a fragment):

```bash
gh issue view <epic> --json body -q .body   # then edit, then:
gh issue edit <epic> --body "<full updated body>"
```

```markdown
## Planned Sub-Issues

1. #<child> — **Sub-Item Title** — description
2. #<child> — **Sub-Item Title** — description (depends on #<earlier-child>)
```

## Self-Check Before Filing

- [ ] Could a second builder produce the same behaviour from these ACs alone?
- [ ] Does every AC name exact functions / fields / errors / return shapes?
- [ ] Are failure and edge cases covered, not just the happy path?
- [ ] Does Out of Scope name the _specific_ temptation and its risk?
- [ ] If a design decision was non-obvious, is the rejected alternative recorded?
- [ ] If part of an epic: native link **and** the inline `#NNN` body reference both done?
- [ ] Dependencies stated as `Depends on #NNN` or explicitly "none"?

## Anti-Patterns

| Anti-Pattern                               | Why it fails                                        | Fix                                            |
| ------------------------------------------ | --------------------------------------------------- | ---------------------------------------------- |
| "THEN it works correctly"                  | Two builders implement two different things         | Name the exact observable result               |
| ACs cover only the happy path              | Ships something that crashes on the first odd input | Add a failure/edge criterion per path          |
| Out of Scope: "no cleanup"                 | Builder can't tell which code is load-bearing       | Name the specific code and the breakage risk   |
| One mega-issue spanning backend + UI       | Can't review, test, or revert independently         | Split on surface; link with `Depends on`       |
| Sub-issue linked only via body reference   | Invisible in GitHub's UI tracker                    | Add the native `addSubIssue` link too          |
| Sub-issue linked only via native link      | Invisible to epic-body scanning scripts             | Add the inline `#NNN` body reference too       |
| Task-list checkbox in the epic list        | Drifts — must be hand-ticked on merge, often stale  | Use an inline `#NNN`; it auto-strikes on close |
| `gh issue edit --add-parent` on gh ≤2.83   | Silently unavailable; link never made               | Use the GraphQL `addSubIssue` mutation         |
| Trusting `--json parent` to confirm a link | Returns empty unreliably                            | Confirm via the `subIssues` GraphQL query      |
