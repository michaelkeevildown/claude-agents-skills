---
name: epic
description: Author a NEW epic (a high-level piece of functionality broken into ordered sub-issues) or EXTEND an existing one, as tracker issues an autonomous agent can implement without guessing. Use when someone describes global or cross-cutting functionality ("I want the app to do X", "big feature", "let's plan out Y", "add a proper notifications system", "rework onboarding", "add a web dashboard"), or says "epic", "break this down", "break this into issues", "plan this feature", "plan this out", "what are the sub-issues", "sequence this work", "split this up". A BARE epic number with nothing else ("/epic 42") is NOT authoring — it means RUN the epic, so hand straight off to `/implement-issue 42`'s autonomous epic loop (every ready sub-issue onto one shared epic integration branch, each green sub-PR auto-merging into it, then one final epic-to-default-branch PR); a number PLUS described additions ("/epic 42 add a foo step", "/epic 42 needs a CSV export") EXTENDS it.
allowed-tools: Read, Glob, Grep, Bash, Skill
---

# /epic — plan a feature as an epic + ordered sub-issues

This is how a high-level piece of functionality becomes _implementable_ tracker work: one **epic**
issue (the tracking container) broken into **ordered sub-issues**, each small enough to review, test,
and revert on its own, wired so both the tracker's UI and any body-scanning script can see the
structure. Execution is a separate step — `/implement-issue` walks the sequence the epic defines.

## Bind to the project

The manifest at `.claude/PROJECT.md` is already in context via the root `CLAUDE.md` import. Its
**`## Bindings` section is a set of markdown tables in the manifest's prose body**, and every
`repo.*`, `labels.*`, `board.*`, `branch.*`, `gate.*`, `checklist.*`, `ui.*` name below is read out
of those tables **by dotted key name**. Never hardcode a repo slug, a label, a branch prefix or a
command.

> The bindings live in the manifest's **body**, not in YAML frontmatter, on purpose: the `@`-import
> that puts the manifest in context strips frontmatter, so a binding written up there would not be in
> context at all. Look for the `## Bindings` tables; do not go hunting for a frontmatter block.

If the manifest is genuinely absent, do **not** guess a label, a branch prefix or a gate command.
Name the bindings you could not resolve, **file nothing**, and stop non-zero. When you were extending
an existing epic, post that blocker as a comment on the epic issue first. Do not wait for a human to
supply the value: headless there is nobody to answer.

`gh` infers the repository from the working directory, so no call below needs a `--repo` flag; use
`repo.slug` only where you must name it explicitly. Prose says "the default branch" for
`repo.default_branch`, and **the epic branch** for the epic's integration branch,
`<branch.epic_prefix>/<N>`.

## When to use

- The person talks at a **high level** about global functionality and it clearly fans out into
  several steps ("I want a proper notifications system", "rework onboarding", "add a web dashboard").
- They say **"epic"**, "break this down", "plan this feature", "what are the sub-issues".
- They give an **epic number**: **bare = run it** (see the routing table below); **plus described
  additions** = extend it ("/epic 42 add a sub-issue for X").

For a single, self-contained change, don't make an epic — author one issue (apply the
`create-issue` discipline) or just go straight to `/implement-issue`.

## `/epic <N>` with nothing else → RUN it (don't author)

A **bare epic number with no described additions is not an authoring request** — there's nothing to
draft. Route by what follows the number:

| Invocation                                   | Meaning                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/epic <N>` **and nothing else**             | **Run the epic.** Hand straight off to **`/implement-issue <N>`** (call the `implement-issue` skill with that number), which drives the whole epic autonomously — every ready sub-issue, in dependency order, on one shared worktree, building each onto **the epic branch** and **auto-merging every green sub-PR into that branch**, then opening + resolving ONE final **epic-branch → default-branch** PR (whose `Closes` closes every sub + the epic). Do **not** author anything here. |
| `/epic <N> <new work described>`             | **Extend** epic N — author the new sub-issue(s) (the "EXTEND an existing epic" procedure below).                                                                                                                                                                                                                                                                                                                                                                                             |
| `/epic <high-level description>` (no number) | **Author a NEW epic** (the "NEW epic" procedure below).                                                                                                                                                                                                                                                                                                                                                                                                                                      |

So `/epic 274` on its own _implements_ epic 274; `/epic 274 add a CSV-export step` _extends_ it. The
authoring discipline and procedures below apply to the **extend** and **new** rows only — the **run**
row is a one-line handoff.

> **Resolve the leading number before routing.** A leading integer only means "run/extend epic N" if
> it actually resolves to an existing **open issue carrying `labels.epic`** — verify with
> `gh issue view <N> --json state,labels`. If it doesn't (no such issue, closed, or not epic-labelled),
> the number is part of the prose, not an epic ref: treat the **whole** input as a NEW-epic
> description (`/epic 3 new dashboards` → author a new epic for "3 new dashboards", don't extend
> issue #3). This also makes the bare-number **run** row safe — a bare number that isn't a live epic
> falls through to new/standalone authoring, not a broken handoff.

## Load the authoring discipline first

Read the **`create-issue`** skill (load it with the Skill tool) and follow it for **every** body you
write — the GIVEN/WHEN/THEN acceptance criteria, the section order, the Out-of-Scope /
Rejected-approach notes, the "one issue or several" seams, and the **two-way epic ↔ sub-issue
linkage**. This skill supplies the _project bindings_ it asks for (below); it does not restate the
portable discipline.

> **If `create-issue` is not installed here, carry on rather than hard-stopping.** A missing skill is
> not a reason to file nothing, and there may be no human to install it. Say plainly in your report
> that `create-issue` was unavailable and that you applied its essentials inline, then enforce those
> essentials yourself on every body you write:
>
> - **Acceptance Criteria as GIVEN/WHEN/THEN**, each one an observable result a test could assert,
>   naming the exact functions / fields / files / errors rather than an aspiration.
> - **A mandatory `## Security Implications` section, never blank**: an explicit "no impact" plus
>   the reason when the sub-issue is genuinely security-neutral.
> - **Two-way epic ↔ sub-issue linkage**: the native sub-issue link _and_ the inline `#NNN` in the
>   epic's `## Planned Sub-Issues` list (step 5 below spells both out).
> - The rest of the body shape named in step 4: Summary / Acceptance Criteria / Edge Cases / Out of
>   Scope / Technical Notes / Affected Files / Dependencies, with an Out-of-Scope that names the
>   specific temptation and a Technical Note that records the rejected alternative.

### Project bindings for `create-issue`

- **Repo:** inferred from cwd; `repo.slug` if you must name it.
- **Sub-issue linkage:** modern `gh` (2.9x and later) has **native sub-issue flags** —
  `gh issue edit <epic> --add-sub-issue <child>` (or `gh issue edit <child> --parent <epic>`) for the
  link, confirmed via `gh issue view <epic> --json subIssues`. Snippets below. On an older `gh` these
  flags do not exist; fall back to the GraphQL `addSubIssue` mutation `create-issue` documents.
- **Labels:** the epic carries `labels.epic`; each sub-issue carries a type label (`labels.bug` |
  `labels.enhancement`) + a priority from `labels.priority_order` — see the project's contributing
  guide for the taxonomy.
- **Pickup label (`labels.ready`) — EVERY sub-issue you want built, no exceptions:** an autonomous
  build loop's discovery filters strictly on `--label <labels.ready>`, so an unlabelled child is
  **invisible to the loop and silently never builds**. Stamp `labels.ready` by default. Leave it OFF
  only for **host-resident** work the loop can't verify inside its fence (secrets, backups,
  service/systemd config, anything _applied to_ a live host — build those by explicit number on that
  host), a sub the owner explicitly parks at step 2's go-gate, or a sub carrying a checklist item that
  cannot be made to pass (step 4's arm) — never silently. The label is a
  _pickup_ signal only — merge safety stays with `labels.human_gate` + the `ui.paths` fail-safe, and
  the deliberate-review moment is step 2's go-gate. (Removing `labels.ready` later parks a misbehaving
  issue; keep that lever.)
- **Merge policy (`labels.human_gate`) — bubbles up to the FINAL PR:** apply `labels.human_gate` by
  default to any sub-issue whose surface touches `ui.paths` (a UI change), and leave it off
  backend-only sub-issues. Under universal bundling the label **no longer stalls the epic**: every
  ready sub — human-gated or not — still builds onto the epic branch and auto-merges into that branch
  as soon as it's green (a sub-PR into the epic branch can't reach the default branch on its own, so
  the merge policy reads it ungated). The label instead **bubbles up to the epic's ONE final
  epic-branch → default-branch PR**: that PR is human-gated iff `labels.human_gate` is on the
  **epic**, on **any** sub, OR the **aggregate** epic-branch diff touches `ui.paths` (the roll-up +
  the UI fail-safe). So the label is still the intent signal — it just gates the whole assembled epic
  once, not each sub, which is what kills the old "a human-gated sub #2 stalls subs #3–7" deadlock.
  _(If `ui.enabled` is false or absent there is no UI surface: the `ui.paths` fail-safe simply never
  fires, and the label is applied on explicit intent only.)_
- **Build depth (`labels.ultra`):** for a sub-issue flagged genuinely complex/high-stakes, apply
  `labels.ultra` so `/implement-issue` fires that ONE build at the coding agent's deepest effort
  setting — its own internal multi-agent depth, no bespoke fan-out authored here. Per-sub-issue
  opt-in only; it changes HOW that build happens, never the reviewer gate or the merge policy above.
- **The gate is `gate.command`** — name it in Technical Notes as the bar a sub-issue must pass, along
  with `gate.prereq` if the project declares one. If `gate` is absent that is fatal for the _builder_,
  not for you: still name the bar the project does have, and say so plainly if it has none.
- **GraphQL budget preflight:** the per-user tracker GraphQL pool is 5000/hr, shared with any armed
  build loop + interactive `gh`. Before a **batch** of issue/board/linkage GraphQL writes (filing
  several sub-issues, moving several board cards) run the project's budget guard when the
  manifest declares one at `gate.graphql_guard` — it's advisory + fail-open: exit 0 ⇒
  healthy, go ahead; exit 1 ⇒ the pool is low, so **space the writes out** (or pause and re-run)
  rather than draining it and starving the loop. With `gate.graphql_guard` absent, space a large batch out
  anyway. This governs `/create-issue`'s own board writes too, not just `/epic`.
- **Requirement-quality checklist (`checklist.path` + `checklist.section`):** the bar every sub-issue
  must clear to be released — its text items gate filing (step 4), an item whose evidence a later step
  creates is judged at step 5. The two keys are a **pointer, never a copy** — read
  the section named by `checklist.section` out of the file named by `checklist.path` and run the items
  that file actually contains. The project's copy is the only copy: never restate the items here, in
  an issue body, or anywhere else. _With no `checklist` binding_, fall back to `create-issue`'s
  **`## Self-Check Before Filing`** and lead the posted comment with
  `CHECKLIST: none bound - create-issue self-check only`, so a floor-only pass never reads as a full
  one. _With `checklist.path` bound but unreadable, or `checklist.section` not found inside it_, you
  **could not run** the bar — that is not a pass: file nothing, post the blocker as a comment on the
  epic issue, and stop non-zero.
- **Conventions live in the project's `CLAUDE.md`** (and any nested per-directory one) — cite the
  relevant one in Technical Notes so the builder inherits the house rules for the surface it touches.
- **Design-system surface — only when `ui.enabled` is true.** If `ui.enabled` is false or absent,
  **skip this binding entirely**: there is no UI surface, so no sub-issue carries a design target and
  no `ui.paths` fail-safe applies. When it is true, every UI sub-issue must name its review oracle in
  a **`## Design Target`** line, because the design reviewer diffs the built screenshots against
  exactly that. Resolve the design system **once** at the start of the run (list the project's design
  directory rather than guessing at a path you have not seen) and reuse the answer. Three roles:
  - the **spec** (the design system's top-level spec document) — always cited;
  - the **per-screen visual golden** for that view, under the design tree's `screens/<view>/`, when
    one has been minted (mint it first if the project has a design-pull workflow);
  - the **baseline golden prototype**, used when no per-screen golden exists yet.
- **`## Security Implications` is a required body section** on every sub-issue (the epic container
  itself is exempt — its security framing lives in Summary/Out-of-Scope). Analyse what the sub-issue
  touches: authz & multi-tenant isolation, untrusted input, secrets/credentials, new or bumped
  dependencies, new network/API surface, outbound/external calls. It is **mandatory, never blank** — a
  genuinely security-neutral sub-issue must still say so explicitly with a reason (the same
  explicit-negative rule as `## Design Spec`'s "no UI changes in scope").

## Procedure — NEW epic

1. **Shape it first (conversation, not fan-out).** Talk through the functionality at a high level
   with the person until the _seams_ are clear — what are the independently-shippable pieces, what
   must come before what. **Settle the dependency order before drafting any body** (per
   `create-issue` "One Issue or Several?"). High-level shape convo _before_ fan-out.

   > **Shape against a freshly-fetched canonical branch.** `git fetch origin` before deciding the
   > seams, and judge what already exists from the canonical branch (`git show origin/<repo.default_branch>:<path>` /
   > `git diff HEAD...origin/<repo.default_branch>`), not a stale local checkout — `create-issue`'s "investigate
   > from the canonical remote" rule governs every body you draft. A concurrent worktree can move the
   > local default branch mid-session, so re-check the gap before filing.

2. **Draft the breakdown and GATE it.** Present it answer-first, as a table, with no wall of text:
   - the **epic** one-liner (the why), and
   - the **ordered sub-issue list** — `N. title — one-line scope — Depends on #(prev) | none —
<disposition>`, where **disposition** marks what happens after filing: **loop-built**
     (`labels.ready` — the armed loop builds AND auto-merges an ungated green build), **host-resident**
     (left without `labels.ready`, built by explicit number on the host that owns it), **human-gated**
     (`labels.ready` + `labels.human_gate` — it is **built and auto-merged into the epic branch like
     any sub**; the gate label instead gates the epic's **final** PR, which the owner merges), or
     **parked** (no `labels.ready` — invisible to the loop until one is added).
   - plus the **outcome coverage matrix** — one row per epic-level outcome, taken from the epic's own
     `## Summary`, mapped to the sub-issue(s) and the acceptance-criterion number(s) that deliver it:
     `| Epic outcome | Sub-issue | AC # |`. An **unmapped outcome is a hole in the breakdown**, not a
     detail — either author another sub-issue for it, or record it as an explicit Out-of-Scope line in
     the epic body; never leave one silently unclaimed. This is **not** a blocking 100%-mapped gate:
     the person's go below is the arbiter, and the explicit Out-of-Scope line is the sanctioned
     escape. A single-sub epic still gets its one trivial row — presenting it is what forces the "is
     this really an epic?" question.

   Get the person's **go before filing anything**. This is the deliberate, gated act; do not create
   issues on a guess — and because dispositions are on the table, the go is _informed_: approving the
   breakdown approves what auto-merges into the epic branch on its own AND whether the epic's final
   PR reaches the default branch autonomously (no `labels.human_gate` / no `ui.paths` touch) or waits
   for the owner to review + merge the assembled whole.

3. **File the epic issue.** `gh issue create` with `labels.epic` and a body containing a `## Summary`
   and a `## Planned Sub-Issues` **numbered list — no checkboxes** (one line per sub-issue; the
   `#NNN` refs are filled in at linkage, step 5):

   ```bash
   gh issue create --label "<labels.epic>" \
     --title "Epic: <feature>" --body "$(cat <<'EOF'
   ## Summary
   <what this functionality is and why it needs to exist>

   ## Planned Sub-Issues
   1. **<title>** — <scope>
   2. **<title>** — <scope> (depends on 1)
   3. **<title>** — <scope> (depends on 2)
   EOF
   )"
   ```

   Capture the printed epic number — **that is the epic number** the person picks up later. Then put
   the epic on the board (`board.number`) at its **backlog** status — it's a container that awaits its
   children, not pickable work:

   ```bash
   <board.command> <epic> backlog
   ```

   _(No `board` row in the bindings tables ⇒ skip every board call in this skill. The card state is a
   convenience, never a gate; a failed board write must not block the filing.)_

4. **File each sub-issue, in order.** First **preflight the GraphQL budget** — filing N sub-issues
   plus their board cards + linkage (steps 4–5) is a burst of GraphQL writes, so run the budget guard
   before starting; if it reports low budget (exit 1), space the writes out (or pause until it clears)
   rather than draining the shared pool. **Next, run the project's requirement-quality checklist
   against every drafted body — before you create anything.** Read the section named by
   `checklist.section` out of the file named by `checklist.path`, and evaluate, by id, **every item
   whose evidence is in the text you drafted**. Fix the body and re-evaluate until every one of those
   passes; a body with a failing text item is not filed (the one exception is the cannot-pass arm
   below). **An item whose evidence only exists once a later step has run — any tracker fact this step
   has not created yet: an issue number (this sub-issue's or a sibling's), a link, a card — takes NO
   verdict here, neither pass nor fail.** You cannot honestly judge an item against state you have not
   created; step 5 judges those, once it has. _With no `checklist` binding_, run `create-issue`'s own
   **`## Self-Check Before Filing`** instead, and say which list you ran in the comment below. _With
   `checklist.path` bound but unreadable, or `checklist.section` not found inside it_, you **could not
   run** the bar, and that is not a pass: file nothing, post the blocker as a comment on the epic
   issue, and stop non-zero. Then, for each, `gh issue create` with the full `create-issue`
   body (Summary / Acceptance Criteria / Edge Cases / Out of Scope / Technical Notes / Affected Files
   / Dependencies). State the dependency explicitly as `Depends on #<earlier sub-issue>` (or "none").
   Apply the type + priority labels **and `labels.ready` per the approved disposition** (stamped by
   default, plus `labels.human_gate` where step 2 marked it human-gated; a host-resident or
   owner-parked sub-issue is filed WITHOUT `labels.ready`, and so is one the arm below holds back).
   Then put each sub-issue on the
   board at its **ready** status — these are committed, sequenced work the person can pick up:

   ```bash
   <board.command> <child> ready
   ```

   **If an item cannot be made to pass** — the shape the person approved genuinely does not carry what
   the item demands, and your due diligence could not supply it — **still file the sub-issue and wire
   its linkage in step 5.** What you withhold is the release, not the work: leave `labels.ready` OFF
   whatever disposition step 2 gave it, and record that item as a failure with its reason in the
   step-5 comment. **Never silently downgrade a failing item to a pass to get the sub-issue filed** —
   the withheld label is the signal, and a checklist that always passes is worth nothing.

5. **Wire the two-way linkage for every sub-issue** (BOTH are required — the tracker UI reads one,
   scripts the other):
   - **Native sub-issue link** (`gh issue edit --add-sub-issue`):
     ```bash
     gh issue edit <epic> --add-sub-issue <child>
     # equivalently, from the child's side:
     # gh issue edit <child> --parent <epic>
     ```
     > Linking is **not idempotent** — re-adding an already-linked child fails harmlessly with
     > `Issue may not contain duplicate sub-issues` and changes nothing. So add each link once; a
     > duplicate error on a re-run is safe to ignore.
   - **Epic body inline reference (no checkbox)** — fetch the epic body and rewrite the
     `## Planned Sub-Issues` list so each line carries its sub-issue inline:
     `N. #<child> — **<title>** — <scope>` (and upgrade any `depends on <ordinal>` to the dep's
     `#<child>`). Write the **whole** body back (never hand-edit a fragment). An inline `#NNN`
     auto-strikes-through when the issue closes, so the epic shows completion with no manual ticking:
     ```bash
     gh issue view <epic> --json body -q .body   # edit, then:
     gh issue edit <epic> --body "<full updated body>"
     ```

   Then, with **both** links in place, **post the completed checklist as a comment on that
   sub-issue** — one comment per child, every item, each verdict citing the evidence that exists at
   that moment. The text items were settled at step 4; judge the ones it deferred now, against the
   state you have just created. **If one of those does not hold, repair it and re-check BEFORE you
   record its verdict** — a link you can still add, or **the child's own** `Depends on` line, now
   correctable because the numbers finally exist — is a repair, not a failure. Rewrite **the child's
   own** body, not the epic's, which the bullet above already rewrote, and pass it through a file
   rather than inlining it, for the reason given just below:
   `gh issue edit <child> --body-file "<scratch>/body-<child>.md"`.
   Only a gap you cannot close takes step 4's cannot-pass arm — and reaching it from here
   means the sub-issue is already filed, so the arm's "leave `labels.ready` OFF" becomes **take it
   off**: `gh issue edit <child> --remove-label "<labels.ready>"` (harmless if the disposition never
   stamped it; and drop its board card back to `backlog`), then record the verdict. Stripping the label is the arm's remedy, not a
   repair of the item, so it does not violate the repair-before-verdict rule above.
   Count the comment in the budget preflight as one extra write per sub-issue, and lead with the
   machine-readable header line, so a later run can `grep` for it instead of re-reading the thread:

   Write it to a scratch file and comment the file, rather than inlining it into `--body` — checklist
   evidence quotes issue-body text full of backticked headings, and a file keeps that text out of the
   shell's hands entirely instead of relying on getting the quoting right. Redirecting a quoted
   heredoc is plain Bash, so this needs no `Write` tool.

   **What this does NOT fix, so nobody assumes it does:** the heredoc is still a heredoc, so an
   evidence line that is exactly `EOF` still ends it early either way. Never emit a bare `EOF` line
   into the body; if the content might contain one, change the delimiter (`<<'CHKEOF'`):

   ```bash
   # <scratch> = any writable temp dir for this session
   cat <<'EOF' > "<scratch>/chk-<child>.md"
   CHECKLIST: <checklist.path> § <checklist.section>
   <one line per checklist item: its id, its verdict, and the specific evidence for that verdict>
   EOF
   gh issue comment <child> --body-file "<scratch>/chk-<child>.md"
   ```

   With no `checklist` binding the header line is instead
   `CHECKLIST: none bound - create-issue self-check only` and the items are `create-issue`'s
   Self-Check boxes — a floor-only pass must never read as a full one.

6. **Confirm + report.** Verify the children are linked:
   `gh issue view <epic> --json subIssues,subIssuesSummary`
   (each node lists the child's `number` + `state`, plus a `completed`/`total` summary). Report the
   epic number, the sub-issues with their numbers + sequence, **any sub-issue whose `labels.ready` you
   withheld and the item that failed**, and point the person at
   **`/implement-issue`** to start (it will pick the lowest-numbered _ready_ sub-issue).

## Procedure — EXTEND an existing epic (`/epic <number>`)

1. **Load the epic.** `gh issue view <number> --json title,body,state,subIssues` — the `subIssues`
   field lists the current children + their state. Show the person the existing sequence so the new
   work slots in correctly.
2. **Shape the addition + settle where it fits** in the order (which existing/new issues it
   `Depends on`, and what now depends on it). **Gate the breakdown**, and in the same breath say
   **which epic outcome the addition closes** — or name it as a NEW outcome the epic body must gain
   (there is no matrix to present at this altitude; the one question is enough).
3. **File the new sub-issue(s)** (steps 4–5 above): full body, `Depends on #NNN`, both linkages,
   board card at **ready** (`<board.command> <child> ready`), and **append** the new line(s) to the
   epic's `## Planned Sub-Issues` list as `N. #<child> — **<title>** — <scope>` (numbered, no
   checkbox; fetch → modify → replace the whole body).
4. **Report** the updated sequence and the new numbers.

## Notes

- **The epic is a container, never worked directly** — only its sub-issues get a worktree + PR via
  `/implement-issue`. Every epic builds onto ONE epic branch: each sub-PR targets that branch and
  carries **`Refs #<sub>`, never `Closes`** (it doesn't target the default branch, so the sub-issue
  must stay open). The epic + all its subs close together the moment the ONE final epic-branch →
  default-branch PR merges — its body repeats the keyword per number
  (`Closes #<sub>, …, Closes #<N>`, never the `Closes #a #b #N` shorthand, which auto-closes only the
  first).
- **Sequence = `Depends on #NNN`** in each sub-issue body + the numbered epic list. `/implement-issue`
  reads exactly these to decide what's _ready_. Keep them accurate — a missing `Depends on` lets
  `/implement-issue` start something whose prerequisite hasn't merged.
- **Split on the seams** `create-issue` names (different surfaces, independently shippable,
  non-overlapping Affected Files). Don't fold a backend change and its UI into one sub-issue.
