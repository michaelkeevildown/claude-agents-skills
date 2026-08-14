---
name: triage
description: Work up the owner's raw captures — the tracker issues carrying `labels.triage` that were filed from a phone in seconds as a couple of lines plus a screenshot — into issues an autonomous agent can build without asking a question. Use when the user says "triage", "triage my issues", "triage the queue", "work up the raw issues", "work up the captures", "what needs triaging", "sort out issue 42", "clear the triage queue", or names an untriaged issue. Reads the screenshot (mandatory — it usually carries the real spec), does whole-system due diligence against a freshly-fetched canonical branch, then REWRITES each raw issue IN PLACE into a full implementable body, links it to the right epic, and swaps the triage label for the pickup label.
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Skill, Workflow, Task, WebFetch
---

# Triage — raw capture → implementable issue

The owner files issues from a **phone** via the project's raw-capture template: a couple of lines and
a screenshot, in seconds, while the thing is in front of them. Those land carrying `labels.triage` —
which is deliberately **not** `labels.ready`, so an autonomous build loop is blind to them. They are
**captures, not specs**.

This skill is the bridge between the two. It takes a raw capture and turns it into an issue an
autonomous agent can build without asking a single question — then hands it to the loop.

`/triage` does not replace `/create-issue` — it **loads** it. `/create-issue` says _how_ to write a
good body; `/triage` owns the _queue_, the _screenshot_, the _in-place rewrite_, and the _labels_.

## Bind to the project

The manifest at `.claude/PROJECT.md` is already in context via the root `CLAUDE.md` import. Its
**`## Bindings` section is a set of markdown tables in the manifest's prose body**, and every
`repo.*`, `labels.*`, `board.*`, `gate.*`, `checklist.*`, `tier.*`, `ui.*` name below is read out of
those tables **by dotted key name**. Never hardcode a label, a path or a command.

> The bindings live in the manifest's **body**, not in YAML frontmatter, on purpose: the `@`-import
> that puts the manifest in context strips frontmatter, so a binding written up there would not be in
> context at all. Look for the `## Bindings` tables; do not go hunting for a frontmatter block.

If the manifest is genuinely absent, do **not** guess a label or a gate command. Name the bindings
you could not resolve, leave every capture exactly as it is (no rewrite, no relabel), post that
blocker as a comment on the issue you were working, and stop non-zero. Do not wait for a human to
supply the value: headless there is nobody to answer.

`gh` infers the repository from the working directory, so no call below needs a `--repo` flag; use
`repo.slug` only where you must name it explicitly.

## When to use

- "triage", "triage the issues", "what needs triaging", "work up the raw ones"
- A specific number: "triage #695", "work up 696", "sort out that chat issue"
- A good periodic sweep — the queue accretes because capture is cheap by design.

## Cardinal rules

1. **REWRITE IN PLACE. Never file a new issue for a raw one.** The owner filed #695; #695 is the
   issue. They may have linked it, mentioned it, or be watching it. Creating #700 as "the real
   version of #695" orphans the original and breaks every reference. `gh issue edit <NN> --body`.
   _(The one exception: a genuine multi-issue fan-out — see step 6.)_
2. **Read the screenshot. Always. It is usually the actual spec.** The body is a few words typed
   one-handed; the image is where the owner circled the defect in red. Triaging from the text alone
   is the single biggest failure mode of this skill.
3. **Never delete the owner's words.** Preserve the original capture verbatim under
   `## Original capture` at the bottom of the rewritten body, screenshot link included. It is the
   provenance and the tie-breaker when your interpretation turns out wrong.
4. **The capture is a symptom, not a diagnosis.** "It always says X even when the system does not"
   is an observation about a code path the owner cannot see. Find the _cause_ in the code before you
   write acceptance criteria — a body that pins the wrong layer sends the builder to the wrong file.

## Procedure

### 1 · Pull the queue

```bash
gh issue list --label "<labels.triage>" --state open \
  --json number,title,body,labels,createdAt,author --limit 100
```

If the user named a number, work that one. If the queue is empty, say so plainly and stop.

### 2 · Read every capture — text AND image

Fetch each issue's body, then **download and Read every attachment in it**. Tracker attachment URLs
(`https://github.com/user-attachments/assets/<id>`) are **private-repo assets whenever
`repo.visibility` is private: an unauthenticated `curl` returns 404**, which reads like a broken link
but is an auth failure. Always send the token:

```bash
curl -sL -H "Authorization: token $(gh auth token)" \
  -o "$SCRATCH/shot-<NN>.png" "https://github.com/user-attachments/assets/<id>"
file "$SCRATCH/shot-<NN>.png"   # confirm it's a PNG, not a 9-byte "Not Found"
```

Then **`Read` the file** so you actually see it. Look for: red circles/underlines (the owner marking
the exact defect), the URL bar (which environment/tier, and which route), the viewport (a 1080×2412
phone shot means **mobile**, so the fix is viewport-specific), and any visible text that names a
component. Describe what you see in the worked-up body — the image can't be grepped later, and the
builder may not open it.

**Read the whole frame, not just the complaint.** A capture routinely shows more than the owner
typed: one capture carried two defects its body never mentioned. Everything visible is evidence.

**Then prove the pixels are ours** — this applies to any screenshot of a rendered surface, and it is
mandatory when `ui.enabled` is true. Before filing anything visual, establish where the page viewport
actually starts: sample the edge pixels down the image and find the row where the browser/OS chrome
colour gives way to the app's background. Anything painted **above** that row is browser or system
UI, not our DOM — no page element can paint over the toolbar. In one capture an empty white card
looked exactly like a broken header; it spanned y≈125–372 while the viewport began at y≈257, which
made it the browser's own floating toolbar and turned a plausible layout bug into a
**correctly-dropped** non-issue. "Screenshot artefact" is a legitimate verdict — but say what would
confirm it (there: open the same URL in another browser), and never file on the ambiguity.

### 3 · Establish live state before judging anything

```bash
git fetch origin
git rev-list --left-right --count HEAD...origin/<repo.default_branch>
```

Judge "does this already exist / what does the code do today" against the **canonical remote branch**,
never the local checkout — concurrent worktrees leave the local branch behind and a fix that already
merged will look unbuilt. Read canonical state with `git show origin/<repo.default_branch>:<path>` /
`git diff HEAD...origin/<repo.default_branch>`. A capture can be **days old and already fixed** — check before
working it up.

### 4 · Diagnose to the responsible layer

Find the code that produces the behaviour in the screenshot, and cite it `file:line`. The layer
mapping that repeats:

| Symptom in the shot                                         | Where to look first                                                           |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Rendering, spacing, markdown, anything about how it _looks_ | the view layer (under `ui.paths` when `ui.enabled`)                           |
| A status/progress indicator that disagrees with reality     | the backend's event → UI-event mapping, not the widget                        |
| Unformatted / raw text mid-flow                             | whatever emits that string — often a tool or service result surfaced verbatim |
| Wrong numbers or wrong content                              | the service/data layer, not the view                                          |

**Do not stop at the first plausible cause.** If the screenshot shows two parts concatenated with no
break, the candidates are: the splitter, the renderer, the whitespace policy in the rendering
component, and the backend's part boundaries. Name the one you believe, say what evidence picks it
over the others, and say so honestly if you could not confirm — an unconfirmed cause goes in
**Technical Notes as a lead**, never in Acceptance Criteria as fact.

### 5 · Dedup — by search, never by enumeration

The tracker only grows; do not read it all. From the _diagnosis's_ own handles (the component name,
the file, the symptom phrase), across **all** states — closed means already-shipped:

```bash
gh search issues --repo "<repo.slug>" "<symbol-or-symptom>" --state all
gh issue list --search "<terms>" --state all
git grep "<symbol>" origin/<repo.default_branch>
gh pr list --state open --json number,title,headRefName
```

Verdicts: **distinct** → work up. **Partial overlap** → work up _and_ cross-reference the neighbour.
**Duplicate / already shipped** → do not work up; close with a comment pointing at the original
(step 8). **In flight** → comment the PR link and leave `labels.triage` on until it lands.

### 6 · Decide the shape

| Shape                                        | Do this                                                                                                                                                                                                                                                                                   |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **One clean issue** (the common case)        | Rewrite in place.                                                                                                                                                                                                                                                                         |
| **Several independent fixes in one capture** | Three separate complaints in one body is the archetype. Rewrite the original as the **best single issue** if they share a cause, or convert it to an **epic** and file the children with `/epic`, keeping the original number as the parent. Never leave three unrelated ACs in one body. |
| **Belongs to a live epic**                   | Work it up, then link it as a sub-issue **both ways** (native sub-issue link + inline `#NNN` in the epic body) per `/create-issue`.                                                                                                                                                       |
| **Too big / too vague to spec**              | Don't guess and don't stamp it. Post the ONE question that unblocks it as a comment on the issue, leave `labels.triage` on, and move to the next capture. Never block the sweep waiting on an answer — there may be no human in the loop.                                                 |

### 7 · Rewrite in place

**Load `/create-issue` with the Skill tool now — before drafting a word.** This is a gate, not a
suggestion: the skeleton below is only the _section list_, and a body that fills those headings
without applying that skill's discipline (criteria a test can assert, named functions/fields/errors,
negative + edge cases as first-class, an Out-of-Scope that names the specific temptation and its
risk, the **Rejected** alternative recorded) is exactly the aspirational issue this skill exists to
prevent.

**Then gate the draft on the project's requirement-quality checklist.** Read `checklist.section` out
of `checklist.path` and evaluate **every item in it, by its id**, against the body you have drafted.
Fix the draft and re-evaluate until every item passes. Keep each item's verdict and the specific
evidence for it — you post that per-item result as a comment in step 8, and it is the artefact that
justifies the release.

**If an item cannot be made to pass** — the capture simply does not carry what the item demands, and
your due diligence could not supply it — **still write the rewritten body to the issue.** A worked-up
body with one honest gap is strictly better than the raw capture, and it is what the next sweep (or
the owner) picks up from. What you must not do is _release_ it: record that item's verdict as a
failure with the reason, and step 8 holds `labels.ready` back. **Never silently downgrade a failing
item to a pass to get the capture out of the queue** — the withheld label is the signal, and a
checklist that always passes is worth nothing.

> **If `create-issue` is not installed here, carry on rather than hard-stopping.** A missing skill is
> not a reason to abandon the queue, and there may be no human to install it. Say plainly in your
> report that `create-issue` was unavailable and that you applied its essentials inline, then enforce
> those essentials yourself: **GIVEN/WHEN/THEN acceptance criteria** that a test could assert (exact
> functions, fields, files and errors, negative and edge cases as first-class); the **mandatory
> `## Security Implications` section, never blank** (an explicit "no impact" plus its reason when
> genuinely security-neutral); **two-way linkage** whenever the capture belongs to an epic (the
> native sub-issue link _and_ the inline `#NNN` in the epic body); and an Out-of-Scope that names the
> specific temptation plus a Technical Note recording the rejected alternative. The section list
> below is the skeleton for exactly that.

> **A missing `checklist` binding NARROWS the pass — it never stops the sweep.** This skill carries
> two degrade severities, and the checklist deliberately takes the softer one, the same class as the
> note above: **not** the manifest-absent hard stop near the top of this file. That stop leaves every
> capture exactly as it is, and applying it here would cost a repo that never declared a checklist its
> whole triage queue. So with **no `checklist` row in the bindings tables**, run `/create-issue`'s own
> **`## Self-Check Before Filing`** (its seven boxes) as the floor instead, work the capture up
> normally — and **declare the narrowing**: the step-8 comment leads with
> `CHECKLIST: none bound - create-issue self-check only`, because a floor-only pass must never read as
> a full one.
>
> **The half-bound arm is the fatal one.** `checklist.path` bound but unreadable, or
> `checklist.section` not found inside that file, is **could not run, not a pass** — a typo'd binding
> must never degrade quietly into a floor-only pass that claims to be a full one. Rewrite nothing,
> relabel nothing, post that blocker as a comment on the issue, and stop non-zero. Do not wait for a
> human to correct the binding: headless there is nobody to answer.

Body:

```markdown
## Summary

<what's broken/wanted and why — one paragraph, informed by the screenshot>

## Evidence

<what the screenshot shows, described in words — the marked-up defect, viewport, environment, route>
<the attachment link, preserved>

## Acceptance Criteria

1. GIVEN … WHEN … THEN <exact observable result>

## Edge Cases

## Out of Scope

## Technical Notes

- Suspected cause: `path/file.ext:NN` — <evidence>. <Rejected alternatives.>
- Bar: `gate.command` green.

## Security Implications

<mandatory, never blank — an explicit "no impact" with a reason if genuinely none>

## Affected Files

## Design Spec

> Only when `ui.enabled` is true AND the issue has a visible UI surface: cite the project's
> design-system spec plus the review oracle (the per-screen visual golden for that view if one
> exists, else the baseline golden prototype). Resolve those paths by listing the design directory,
> not by guessing. Otherwise write "no UI changes in scope" — and if `ui.enabled` is false or
> absent, drop this section entirely.

## Dependencies

---

## Original capture

> <the owner's verbatim words + screenshot link, unedited>
```

Write it with a heredoc to a scratch file, then `gh issue edit <NN> --body-file <path>` — never
hand-edit a fragment, and never inline a body with backticks straight into the shell.

Retitle if the raw title is vague, keeping the project's `branch.bug_prefix:` / `branch.feature_prefix:`
title convention.

### 8 · Relabel, prioritise, board

**Post the step-7 checklist result as a comment FIRST, before the relabel below.** The release
judgement then exists as an auditable artefact on the thread instead of only in a transcript nobody
can read later. Write it to a scratch file and comment the file — a checklist is full of backticked
headings like `` `## Acceptance Criteria` ``, so the step-7 rule applies here too: never inline a body
with backticks straight into the shell.

```bash
gh issue comment <NN> --body-file "$SCRATCH/checklist-<NN>.md"
```

The comment **leads with one stable header line**, which is what makes it greppable — for the
idempotency check below, and for anyone later auditing whether an issue was actually checked:

| Case                   | First line of the comment                              |
| ---------------------- | ------------------------------------------------------ |
| `checklist` bound      | `CHECKLIST: <checklist.path> § <checklist.section>`    |
| No `checklist` binding | `CHECKLIST: none bound - create-issue self-check only` |

Then one line per item: its id, its verdict, and the specific evidence for that verdict.

- **A failing item blocks the relabel for THAT capture only.** Leave the rewritten body in place,
  leave `labels.triage` on, do **not** stamp `labels.ready`, and move to the next capture. **Never
  abort the sweep** — this is the same shape of hold as a too-vague capture (step 6), one issue held
  while the queue keeps moving.
- **A re-sweep must not stack comments.** A capture parked in flight comes back around on a later
  sweep: grep the thread for the `CHECKLIST:` header first, and replace it or skip rather than
  posting a second checklist for the same body revision.
- **The checklist gates release, not analysis.** It does not run, and no comment is posted, for a
  capture closed as duplicate / won't-fix (step 5), parked in flight (step 5), or parked as too big /
  too vague (step 6). None of those has a rewritten body to check, so the checklist is
  _inapplicable_, not failing — never read a missing comment on those paths as a block.
- **This comment is a main-session write**, alongside the label writes below — never delegated to a
  fan-out worker.

Before the relabel, decide the **build tier** — a `model:` and an `effort:` label — when the project
binds a vocabulary for it (`tier.path` + `tier.section`, alongside the other `labels.*` bindings; see
`create-issue`'s "Build Tier Labels"). Read the class table and the push-up/push-down signals from
`tier.section` in `tier.path`, pick the class from what the rewritten body actually shows (multi-file,
security-touching, a prod data path, a demanded revert-pin push up; docs-only, single-file,
well-precedented push down), and add a line to the rewritten body's `## Technical Notes` recording the
choice and the signal that decided it. **No `tier` binding ⇒ stamp neither label** — the same silent,
safe degrade `create-issue` documents, never a guess at a model name.

The relabel is what actually releases the issue to the loop — **`labels.triage` off, `labels.ready`
on, in one call** so it can never sit in both states:

```bash
gh issue edit <NN> \
  --remove-label "<labels.triage>" \
  --add-label "<labels.ready>,<type>,<priority>"   # type: labels.bug|labels.enhancement · priority: from labels.priority_order
  # plus "<model-label>,<effort-label>" in the same --add-label, when `tier` is bound
<board.command> <NN> ready
```

- **`labels.human_gate`** — add for anything touching `ui.paths` when `ui.enabled` is true (the
  default for UI issues; the owner validates and merges). With no UI surface, apply it on explicit
  intent only.
- **`labels.ultra`** — only when the owner asks for it, or the work is genuinely multi-file/subtle.
  Expands to `model:opus` + `effort:xhigh` on its own; an explicit `model:`/`effort:` label on the
  same issue beats the expansion, per the project's own rule.
- **`labels.ready` is a release, not a formality.** If you left an open question in the body, do
  **not** stamp it — the loop will build the guess.
- **A failing checklist item is that same hold.** The body stays rewritten and the comment stays
  posted, but `labels.triage` stays on and `labels.ready` is withheld until the item passes. Say which
  item held it in your report, so the next sweep knows what to fix.
- **No `board` row in the bindings tables ⇒ skip the board call.** The card state is a convenience, never a
  gate; a failed board write must not block the relabel.

For **duplicate / won't-fix**: comment why + the link, `gh issue close <NN> --reason "not planned"`,
and remove `labels.triage` so it leaves the queue.

### 9 · Report

Lead with the answer. One table, one row per issue:

| #   | title  | verdict   | cause found        | now        |
| --- | ------ | --------- | ------------------ | ---------- |
| 695 | fix: … | worked up | `path/file.ext:88` | ready · P2 |

Then flag anything you could **not** confirm, and any issue left in the queue with the question that
blocks it.

## Notes

- **Fan out for a multi-issue sweep.** A queue of N raw captures is N independent investigations —
  use a **Workflow** fan-out (one agent per issue: read shot → diagnose → dedup → draft body), then
  apply the edits yourself after reviewing. A single agent serialising ten captures is the
  anti-pattern. Keep the _label writes_ in the main session.
- **The owner is the reporter, not the architect.** "Everything that shows up should be pretty and
  look nice" is a goal; your job is to turn it into criteria a test can assert.
- **Capture must stay cheap.** Never respond to a thin raw issue by asking the owner to fill in a
  template. Working it up is _this skill's_ job — that division is the entire point of the raw
  capture template.
- **Screenshots expire from your context, not from the issue.** Describe what you saw in the body.
  The next agent to touch the issue will read text, not pixels.
