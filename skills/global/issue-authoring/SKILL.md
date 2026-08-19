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

### The bright line is behaviour — for a FIX, that is not enough

"Same observable behaviour" is the right test for new capability. Dictating the
implementation there is its own anti-pattern: it spends the builder's judgement,
and it ages badly the moment the surrounding code moves.

A **fix to a defect you have already localised is different.** Two builders can
land identical observable behaviour through different seams, and the seam is not
a free choice — one can be correct-but-costly, correct-but-fragile, or correct
only until the next caller appears. If your investigation already found the exact
call site, withholding it does not preserve the builder's judgement; it just
makes them redo the investigation and gamble on the answer.

So when the defect is localised, the issue must say **where the fix goes**:

- the **function and the seam** — which parameter, which predicate, which caller
- the **placement**, when order matters (before an expensive lookup, after a
  cheap guard) and _why_ that position
- the **explicit do-not-touch list** — the neighbouring call sites, guards, and
  thresholds that must stay byte-for-byte unchanged
- the **failure direction** — on an unreadable or error state, which way does it
  fail, and what breaks if it fails the other way

Absent that, "no ambiguity" is only true of the outcome, not of the change.

**Where it goes:** in `## Technical Notes` (and the do-not-touch items in
`## Out of Scope`) — never in `## Summary`, which stays "what and why, not how".
The criteria still describe observable behaviour; the seam is the note that stops
a builder reaching it through the wrong call site.

### Cite code so the citation survives

A bare line number rots on the next merge. Anchor on the **symbol plus a short
verbatim snippet**, and give the line number only as a hint alongside it:

> in `resolveCandidate`, immediately before the `const deps = parseDeps(body)`
> line (~line 430)

If the issue prescribes an exact code block — a declared reversion, a patch
anchor, a find/replace — reproduce it at the **exact indentation** of the target
file and say which file it must match. An anchor that is one space out is a
could-not-run, not a near miss.

## An issue is its body, not its comment thread

Investigation lands in comments. Left there, it becomes a **second, competing
spec**, and the builder has no way to know which one won — most will read the
body and act on it.

When a later finding supersedes the body, **rewrite the body.** Comments are for
evidence, reproduction, and the audit trail; the body is the only normative text.
Before filing or handing off, re-read the body against every comment and resolve
each contradiction in the body itself.

Where a comment carries evidence worth keeping — a reproduction, a measurement —
reference it from the body rather than duplicating it, so there is one statement
of the requirement and one place the evidence lives.

## Verify what you assert — a wrong Technical Note is worse than none

The builder trusts the issue. An unverified claim about how the code behaves does
not degrade to "no information"; it actively steers the work wrong, and it steers
it past the point where anyone re-checks.

Before writing any behavioural claim into **Technical Notes** or a rationale —
_this function is cheap_, _makes no network call_, _is cached_, _is already
covered by that test_, _runs on every request_ — open the implementation and
confirm it. Cheap claims are the ones to distrust most, because they are the ones
nobody re-derives: a helper that short-circuits on a fast path may take a slow one
in exactly the case the issue is about.

Where the claim is load-bearing for the design, prove it rather than read it — run
the function, run the test, and state what you observed. If you cannot confirm it,
write the uncertainty into the issue ("unverified — confirm before relying on
this") instead of asserting it flat.

The same duty applies to a claim you already published: if a comment or an earlier
body asserted something you later find false, **correct it in place**, because the
builder will read it either way.

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

### Search the tracker before you write a line

The cheapest issue to write is the one that already exists. Before drafting,
search **open and closed** issues for the same symptom, the same file, and the
same feature name — closed matters, because a closed issue tells you the work was
done, rejected, or duplicated, and each of those changes what you file.

```bash
gh issue list --state all --search "<symptom or symbol>" --limit 30
```

On a hit: extend or reopen that issue rather than filing a near-duplicate. Two
issues covering one defect split the evidence, and whichever gets built first
leaves the other looking unfinished forever. If you file anyway because the scope
genuinely differs, say so in the body and link the neighbour — the builder must
not have to rediscover the relationship.

## The title is a queue-triage surface, not a heading

An autonomous queue is read as a **list of titles**. Priority ordering, duplicate
spotting, and the owner's "what is this?" all happen before anyone opens the body.

A title states **the defect or the capability, not the area**:

| Weak                     | Strong                                                                  |
| ------------------------ | ----------------------------------------------------------------------- |
| `Fix the job runner`     | `fix(runner): a cancelled job is retried forever, saturating the queue` |
| `Improve error handling` | `fix(api): the freshness handler swallows a fault with no log`          |
| `Auth work`              | `feat(auth): rotate refresh tokens on every use`                        |

Lead with the consequence where there is one — "saturating the queue" is what makes
someone read it today rather than next month. If the project binds a commit or
title convention, follow that; absent a binding, a short `type(scope):` prefix
plus the observable problem reads well in every tracker.

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

## Security Implications

> What this touches: authz and tenant isolation, untrusted input, secrets,
> new or bumped dependencies, new HTTP/RPC surface, outbound calls. Never
> blank — a genuinely neutral change says so _with its reason_.

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

### At least one criterion must be an OUTCOME, not a mechanism

A criterion that names a **mechanism** — "add `retryWithBackoff()`", "install the
timer", "add the dedup marker" — can be satisfied in full while the feature does
not work. This is the most expensive failure in this document, because it passes
every check: the code exists, the test is green, the box is ticked, and the thing
the issue existed to produce never happens.

It is not hypothetical. One epic shipped thirteen mechanism criteria across its
sub-issues, ticked every one, passed the gate — and the alert they existed to add
**could never fire**. Nothing in the criteria had ever asserted that it did.

So every issue carries at least one criterion of the shape:

> GIVEN [a real scenario] WHEN [the system runs] THEN [the observable outcome the
> > issue exists to produce]

and it must hold **at production configuration** — the real thresholds, the real
config resolution, the deployed surface. A test that lowers a threshold to make
the path reachable, or stubs out the very component it is meant to prove, does
**not** satisfy an outcome criterion: it proves the feature works in a
configuration that does not exist.

Three that look fine and are not:

| Looks satisfied                                          | Why it proves nothing                              |
| -------------------------------------------------------- | -------------------------------------------------- |
| Alert page proven with the threshold dropped 4 → 1       | Production runs at 4; the page was never reachable |
| Ledger proven with its recorder monkeypatched inert      | The thing under test was replaced by a stub        |
| Count asserted against a value that is 1 by construction | The assertion cannot fail, so it tests nothing     |

Ask of each criterion: **if I implemented exactly this and nothing else, would
the feature actually work?** If yes for the whole set, the outcome criterion is
present. If not, you have specified a mechanism and hoped.

### A bug fix must be pinned by a test that fails without it

For an issue whose job is to fix a defect, "the tests pass" is not evidence — the
tests passed before the fix too, which is why the bug shipped. Require, as a
criterion, that **reverting the fix makes a named test fail**:

> GIVEN the fix is reverted WHEN `<named test>` runs THEN it fails

Without it the fix is unheld: re-introducing the original defect leaves the suite
green, and the next rebase or refactor silently restores the bug. One review found
a fix whose removal left the entire suite passing.

Two things make such a pin worthless, so state them in the issue:

- **The red must be behavioural.** A test that fails with `ImportError` /
  `AttributeError` because a symbol is missing proves nothing about behaviour —
  assert through a pre-existing entry point, not the new symbol's existence.
- **Pin each severable arm separately.** If two branches produce the same answer,
  deleting one leaves the test green. Assert through the value the reverted branch
  **uniquely** controls.

The sibling **`regression-proof-red-green`** skill is how a builder demonstrates
the red without `git stash`; this criterion is what makes it non-optional. If the
project also has a mechanical pin format, its bindings name it.

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

## Writing Security Implications That Aren't Theatre

The section exists to make someone _look_, once, at the moment they still
understand the change. Two failure modes, both common:

- **Blank or "N/A"** — indistinguishable from "nobody checked".
- **Boilerplate** — "no security impact" pasted onto a change that adds a route.

Name what the change actually touches, and if it touches nothing, say so **with
the reason** so a reviewer can check the reasoning rather than the verdict:

> No security impact — presentational change to an existing component; no new
> input, route, dependency, or auth path.

Re-analyse it whenever scope materially changes. A criterion added late that
introduces a route, an input, a dependency, or an auth path invalidates the
section written against the original scope — the same discipline as re-checking
`Depends on #NNN` when the dependency graph shifts.

Where the change _is_ security-relevant, state the direction of failure, not just
the surface: which way an unreadable or error state resolves, and what an attacker
or a transient fault gains if it resolves the other way.

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

## Build Tier Labels (`model:`/`effort:`) — only when the project binds one

Some projects run an autonomous build loop that fires each issue at a chosen model and effort
level, resolved from two labels: a `model:` label and an `effort:` label. That vocabulary — the
label prefixes, the allowed values, the default, and the signals that push an issue up or down — is
a **project binding**, never something this skill invents. Look for it wherever the project keeps
its other bindings (typically a `tier.path` + `tier.section` pointer alongside `labels.*`, read the
same way as every other dotted-key binding).

- **Bound:** select exactly one `model:` value and one `effort:` value from the vocabulary the
  binding names, and record the choice — the class and the specific signal that decided it — in the
  issue body (a short `## Build Tier` note, or a line in `## Technical Notes` when the project's own
  template has no dedicated section). Never leave the decision unstated: an unlabelled issue looks
  identical to an issue nobody thought about, and on a project that defaults an unlabelled issue to a
  cheap tier, that silence is a silent downgrade.
- **Unbound:** the project has no tier vocabulary to read. Stamp no tier label and don't guess a
  model name — this is a silent, safe degrade, never a gap to call out in the issue.

## Self-Check Before Filing

- [ ] Did you search open **and closed** issues for a duplicate before drafting?
- [ ] Does the title name the defect or capability (and its consequence), not the area?
- [ ] Could a second builder produce the same behaviour from these ACs alone?
- [ ] Is at least one criterion an OUTCOME at production configuration — not a
      mechanism that could be fully satisfied while the feature does not work?
- [ ] If this is a bug fix: is there a criterion that reverting it makes a NAMED
      test fail, behaviourally, on the arm the fix uniquely controls?
- [ ] If this is a FIX to a localised defect: does the issue name the seam, the
      placement, the do-not-touch list, and the failure direction — so two
      builders would change the same code, not just reach the same behaviour?
- [ ] Does every AC name exact functions / fields / errors / return shapes?
- [ ] Does the BODY stand alone — no comment contradicting it, every superseding
      finding folded back in?
- [ ] Has every behavioural claim in Technical Notes been checked against the
      implementation (not assumed), with anything unconfirmed marked unverified?
- [ ] Are code citations anchored on a symbol + verbatim snippet, and any exact
      block reproduced at the target file's real indentation?
- [ ] Are failure and edge cases covered, not just the happy path?
- [ ] Does Out of Scope name the _specific_ temptation and its risk?
- [ ] Is Security Implications filled in — what it touches, or "none" **with the
      reason** — and re-checked if scope moved since it was written?
- [ ] If a design decision was non-obvious, is the rejected alternative recorded?
- [ ] If part of an epic: native link **and** the inline `#NNN` body reference both done?
- [ ] Dependencies stated as `Depends on #NNN` or explicitly "none"?
- [ ] If the project binds a build-tier vocabulary: does the issue carry both a `model:` and an
      `effort:` label, with the choice justified in the body? (No such binding ⇒ n/a, not a fail.)

## Anti-Patterns

| Anti-Pattern                                                  | Why it fails                                                                    | Fix                                                            |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| "THEN it works correctly"                                     | Two builders implement two different things                                     | Name the exact observable result                               |
| Fix issue names the behaviour, not the seam                   | Same behaviour reached via a worse call site; builder re-does the investigation | Name function, placement, do-not-touch list, failure direction |
| A comment contradicts the body                                | Two competing specs; the builder cannot tell which won                          | Rewrite the BODY; comments hold evidence only                  |
| Unverified "this is cheap / not cached"                       | Trusted and acted on; steers the fix wrong past the point anyone re-checks      | Read the implementation; prove it or mark it unverified        |
| Citing a bare line number                                     | Rots on the next merge; anchor lands in the wrong place                         | Symbol + verbatim snippet, line number as a hint               |
| ACs cover only the happy path                                 | Ships something that crashes on the first odd input                             | Add a failure/edge criterion per path                          |
| Every AC names a mechanism to add                             | All tick, gate passes, feature still does not work                              | Add a GIVEN/WHEN/THEN outcome AC at production config          |
| Outcome proven with a lowered threshold or a stubbed recorder | Proves the feature works in a config that does not exist                        | Assert at production settings, against the real component      |
| Bug fix with no revert-pin criterion                          | Re-introducing the defect leaves the suite green; the fix is unheld             | Require a named test that fails when the fix is reverted       |
| Filing without searching closed issues                        | Splits evidence across duplicates; one always looks unfinished                  | Search `--state all` first; extend or link the neighbour       |
| Title names the area (`Fix the loop`)                         | Unreadable as a queue; no triage or dedup possible from the list                | Name the defect and its consequence                            |
| Security Implications blank or boilerplate                    | Indistinguishable from nobody having looked                                     | Name what it touches, or "none" **with the reason**            |
| Out of Scope: "no cleanup"                                    | Builder can't tell which code is load-bearing                                   | Name the specific code and the breakage risk                   |
| One mega-issue spanning backend + UI                          | Can't review, test, or revert independently                                     | Split on surface; link with `Depends on`                       |
| Sub-issue linked only via body reference                      | Invisible in GitHub's UI tracker                                                | Add the native `addSubIssue` link too                          |
| Sub-issue linked only via native link                         | Invisible to epic-body scanning scripts                                         | Add the inline `#NNN` body reference too                       |
| Task-list checkbox in the epic list                           | Drifts — must be hand-ticked on merge, often stale                              | Use an inline `#NNN`; it auto-strikes on close                 |
| `gh issue edit --add-parent` on gh ≤2.83                      | Silently unavailable; link never made                                           | Use the GraphQL `addSubIssue` mutation                         |
| Trusting `--json parent` to confirm a link                    | Returns empty unreliably                                                        | Confirm via the `subIssues` GraphQL query                      |
