---
name: implement-issue
description: Pick up a tracker issue and take it end-to-end through a proper dev lifecycle in a dedicated git worktree — branch, scope, implement, run the quality gate, commit, open a PR that closes the issue, then clean up. Hand it an EPIC number and it runs the WHOLE epic autonomously — every ready sub-issue, in dependency order, on ONE shared worktree, building each onto one shared epic integration branch and auto-merging every green sub-PR into that branch, then opening + resolving one final integration-branch→default-branch PR, stopping only when the epic is done or it hits a gate it can't clear itself. For a single issue it's sequence-aware — only offers sub-issues whose dependencies are met. Label-scoped: with no argument it offers the open ready queue (the single pickup label, `labels.ready` in the project manifest — present = the driver loop or a manual build may take it, absent = held back); an explicit number (`pick up #42`) overrides the filter. Use for "/implement-issue", "/implement-issue <epic#>" (run the whole epic), "run the epic", "implement feature", "work an issue", "work the ticket", "pick up #42", "take #42", "start on #42", "what should I work on next", "what's next", "next ticket", "implement the next sub-issue", "work the next 3", "open a PR for this issue". Engineering work — building the system, in a worktree, behind the gate.
---

# /implement-issue — implement a tracker issue in a worktree, end-to-end

The single execution loop for the dev workstream: take one **issue**, build it on its own branch in a
**dedicated worktree**, prove it green against the quality gate, and open a PR that closes it.
Authoring issues is a separate step (`/epic`, or `/create-issue` for a one-off); this skill _consumes_
them, in dependency order.

## Bind to the project — do this first

The manifest at `.claude/PROJECT.md` is already in context via the root `CLAUDE.md` import. Its
**`## Bindings` section is a set of markdown tables in the manifest's prose body**, and every value
this skill needs is read out of those tables **by dotted key name** (`gate.command`, `labels.ready`,
`branch.epic_prefix`, ...). Read the value from that table; **never hardcode a repo slug, a label, a
branch prefix, a path or a command.** If the manifest is genuinely absent, do **NOT** guess: say so
and stop before making any change.

> The bindings live in the manifest's **body**, not in YAML frontmatter, on purpose: the `@`-import
> that puts the manifest in context strips frontmatter, so a binding written up there would not be in
> context at all. Look for the `## Bindings` tables; do not go hunting for a frontmatter block.

**Names used throughout this file** (every one resolved from the manifest's `## Bindings` tables, not
from memory):

| Written here    | Resolves to                                                                                                                                                                                     |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `<main>`        | `repo.default_branch`                                                                                                                                                                           |
| `<epic-branch>` | `<branch.epic_prefix>/<N>` for epic `N` — the epic integration branch                                                                                                                           |
| `<type>`        | `branch.bug_prefix` (issue labelled `labels.bug`) or `branch.feature_prefix` (`labels.enhancement`)                                                                                             |
| `<worktree>`    | `worktree.path_template` with `<slug>` substituted (epic mode: `worktree.epic_path_template` with `<N>`)                                                                                        |
| `<gate>`        | `gate.command` — its prerequisite is `gate.prereq`                                                                                                                                              |
| `<board-cmd>`   | `board.command`, taking `<NN> <status>` where the status is one of `board.statuses`                                                                                                             |
| `<ui-gate>`     | `ui.command` — fires only for a diff touching `ui.paths`, and only when `ui.enabled`                                                                                                            |
| `<ready>`       | `labels.ready` — the one pickup label                                                                                                                                                           |
| `<gate-label>`  | `labels.human_gate` — the label that hands a PR to a human to merge                                                                                                                             |
| `<ui-reviewer>` | the `reviewers` entry whose `when` matches `ui.paths` — **resolve it from the `reviewers` table, never name an agent inline.** No matching entry ⇒ this repo has no UI reviewer (degrade below) |
| `<checklist>`   | `checklist.section` read out of `checklist.path` — the project's requirement-quality checklist. Used at exactly one point: the epic-mode convergence audit must clear it before it may stamp `<ready>` on a gap issue it wrote itself. **Absent, unreadable, or any item failing ⇒ the audit still files the gap, just never with `<ready>`** |

**Reviewers are named by the manifest, not by this file.** `reviewers` is a list of `agent` + `when`
pairs, and a repo declares whichever it actually ships. The four roles this skill gates on are the
UI reviewer (`<ui-reviewer>`, selected by a `when` matching `ui.paths`), `correctness-reviewer`,
`security-reviewer` and `goal-checker`. **Any of them may be absent from a given repo's `reviewers`
table**, and an absent entry is a decision, not an oversight: that reviewer is not spawned and the PR
body says so (degrade below). Never invent an agent name that the manifest does not declare, and
never claim a review ran that did not.

**Never pass `--repo` to `gh`.** It infers the repository from the working directory, and every command
in this file runs inside the checkout or a worktree of it. `repo.slug` exists in the manifest for the
rare command that genuinely runs from outside a checkout.

**Headless-legal terminal action.** There is no human in the loop on an unattended driver, and the
driver's resume directive actively overrides an early stop, so **"stop and ask the human" is never a
legal degrade.** When something genuinely cannot be cleared: **do NOT open (or merge) the PR, post the
blocker as a comment on the issue, and exit non-zero.** Everywhere below that says _escalate_, that is
what it means. (The one _designed_ stop that is not a blocker is the gated final epic PR — see Epic
mode step 6.)

**Degrades when an optional binding is absent** (absence is a decision, not an oversight):

- **`ui.enabled` false or absent** — skip the UI gate entirely and **say in the PR body that no UI gate
  ran.** Never substitute a screenshot-free guess at design conformance. The same applies when the UI
  runner itself reports it could not run (exit `2` — see the exit-code table in step 3): a skip is
  recorded as a skip, never laundered into a pass, and never escalated as if the diff were red.
- **`board` absent** — skip every board-sync call. The card state is a convenience, never a gate: a
  board write failure must **never** block a build.
- **`reviewers` absent (or an entry missing)** — that reviewer is not spawned, **and the PR body must
  say so.** Never claim a review ran that did not. In particular, a repo whose `reviewers` table
  declares no entry matching `ui.paths` simply has **no `<ui-reviewer>`**: run the UI runner if one is
  configured, record "no design review ran (no such reviewer in this repo)" in the PR body, and carry
  on. Do not substitute another reviewer for it and do not stop.
- **A cited sibling skill is absent** — this file cites `/create-issue`, `git-workflow`,
  `regression-proof-red-green` and `bash-pipefail-safety`. They are conveniences, not dependencies:
  **every citation below states, inline, the one-line rule the skill exists to enforce.** If the skill
  is not vendored in this repo, apply that inline rule and carry on. A missing sibling skill is never
  a stop and never a blocker comment.
- **`.claude/REVIEW-ANCHORS.md` absent** (the project's own review-anchors file, never vendored):
  the reviewers still run, on their **universal lenses only**. Spawn them anyway, say plainly in the
  task prompt that no project anchors exist so each one records `ANCHORS: none — universal lenses
only` in its verdict, and repeat that narrowing in the PR body. A narrowed review must never read
  as a full one. (See "Project review anchors" in step 3.)
- **`hooks` absent, or `hooks.close_out` empty**: there are no project close-out actions, so that
  part of close-out is skipped silently. Never invent a hook.
- **`tracker: none`** — there is no issue to close: drop the closing keyword from the PR body rather
  than inventing an issue number, and post the progress log wherever the project keeps it.
- **`gate` absent** — fatal. A skill that cannot prove the tree is green must not open a PR.

**Tracker capability note (`tracker: github`).** `gh` 2.6x+ reads epic structure natively with
`gh issue view <epic> --json subIssues,subIssuesSummary` — no GraphQL needed; each node carries the
child's `number` + `state`.

## Epic mode — one command runs the WHOLE epic (`/implement-issue <epic#>`)

**When the argument is an epic, this skill stops being a one-issue tool and becomes the autonomous
driver for the entire epic.** You hand it the epic number and nothing else; it works through _every_
ready sub-issue, in dependency order, on **one shared worktree**, **building every sub-issue onto one
shared integration branch `<epic-branch>` and auto-merging each green sub-PR into that branch**, then
opening + resolving ONE final `<epic-branch>→<main>` PR — and only stops when the epic is finished or
it hits a gate it cannot clear by itself. No "do them all" each time, no pausing between sub-issues.

**Detect the epic first.** The argument is an epic iff `gh issue view <N> --json labels` carries the
`labels.epic` label (or `gh issue view <N> --json subIssues` returns children). If it's a plain issue,
ignore this section and run the single-issue **Procedure** below as normal.

**The integration-branch model — the whole shape in one place:**

- **Every epic builds onto ONE branch `<epic-branch>`.** It's cut off fresh `origin/<main>` on first
  use and pushed; each ready sub-issue branches off `origin/<epic-branch>`, and its PR **targets
  `<epic-branch>`** (not `<main>`). A green sub-PR **auto-merges INTO `<epic-branch>`** — its own
  quality gate + reviewers passing is enough; there is no per-sub owner gate. Sub-PRs carry
  **`Refs #<sub>`, NEVER `Closes`** (they don't target the default branch, so the sub-issue must stay
  open until the final PR merges).
- **A lone sub of an epic still bundles.** Even a single ready sub of an epic builds onto
  `<epic-branch>` and PRs into it — never straight to `<main>`. Only a genuinely standalone (non-epic)
  issue PRs to `<main>`. Resolve a sub → its parent with
  `gh issue view <NN> --json parent -q .parent.number` (empty ⇒ standalone).
- **`<gate-label>` no longer stalls the epic — it bubbles up to the FINAL PR.** A `<gate-label>` (or
  `ui.paths`-touching) sub still builds + auto-merges into `<epic-branch>` like any other. The gate
  moves to the ONE final `<epic-branch>→<main>` PR: it is **human-gated iff** `<gate-label>` is on the
  **epic**, on **any** sub, OR the **aggregate** `<epic-branch>` diff touches `ui.paths`. (This is
  exactly what un-sticks the old deadlock where a gated sub #2 froze subs #3–7.)
- **Safety invariant — nothing reaches `<main>` unless the aggregate gate is green AND (if gated) a
  human merged it.** The only two paths to `<main>` are the unchanged standalone PR and this epic's ONE
  final `<epic-branch>→<main>` PR. A sub-PR is hard-guarded to `base == <epic-branch>` — it can never
  merge to `<main>`. Ungated final PR ⇒ auto-merge to `<main>` once every sub is in AND aggregate CI is
  green; gated ⇒ mark ready + add `<gate-label>` + STOP for the owner.
- **Idempotent + re-entrant.** Creating the `<epic-branch>` branch, opening/updating the final PR,
  merging subs, and the final merge must ALL be safe to re-run — detect "already exists / already
  merged / already open" and no-op. Tolerate an epic PARTIALLY on `<main>` already (e.g. a sub merged
  straight to `<main>` before bundling, or a sub with an open PR against `<main>`): retarget the stray
  PR onto `<epic-branch>` (`gh pr edit --base <epic-branch>`, rewrite `Closes`→`Refs`), and treat an
  already-merged sub as satisfied — do not rebuild it.

**Run the whole loop in THIS (the main) session — never delegate a sub-issue to a subagent.** Every
reviewer in `reviewers[]` is spawned as an agent, and **an agent can only be spawned from the main
session** (a subagent cannot spawn another agent). That is load-bearing for the visual reviewer in
particular: fan one sub-issue out to a subagent and a `ui.paths`-touching sub would hit the UI gate,
fail to spawn `<ui-reviewer>`, and either die or merge **without the required design PASS**. The
same holds for `correctness-reviewer`, `security-reviewer` and `goal-checker`. So this loop runs the
sub-issues itself, one at a time, in the main session.

**This session IS the orchestrating layer, so it also MERGES.** The Procedure tells the _implementer_
to stop at in-review and leave the merge to "the orchestrating layer"; **in epic mode that layer is
this loop**, so it carries each sub-issue all the way to merged. The loop **owns** the worktree, pick,
merge, and teardown — so when it runs the per-sub-issue Procedure it runs **only the build steps**
(Procedure step 3 dev lifecycle + step 4 open-the-PR) and **overrides** the rest, per the map below:

1. **Stand up ONE shared worktree AND the `<epic-branch>` integration branch** — both idempotent
   (re-attach on a resume, don't recreate). The worktree is off fresh `origin/<main>` (per-sub-issue
   branches are cut _inside_ it); the integration branch is cut off fresh `origin/<main>` on first use
   and pushed, else reused:
   ```bash
   git -C <repo> fetch origin
   git -C <repo> worktree add <worktree> origin/<main>   # skip if it already exists
   # ensure the <epic-branch> integration branch exists on origin (idempotent):
   if git -C <repo> ls-remote --exit-code --heads origin <epic-branch> >/dev/null 2>&1; then
     :   # already on origin — reuse it
   else
     git -C <repo> push origin origin/<main>:refs/heads/<epic-branch>   # first cut, off fresh main
   fi
   ```
2. **Pick the highest-priority, lowest-numbered READY sub-issue** (this replaces Procedure step 1 —
   no interactive "let the person choose"). Order = priority rank first (`labels.priority_order`, in
   that order, then **no priority label LAST**), issue number second — the same order the armed driver
   uses, so the owner expedites work by bumping one label. Readiness = every `Depends on #NNN` in its
   body is `CLOSED`. Skip the epic container itself, and any sub that lacks `<ready>` (parked — not a
   pick, invisible until the owner labels it). **Claim the pick immediately** —
   `gh issue edit <NN> --add-assignee "@me"` — so the armed driver's assignee skip can't double-pick
   the sub-issue this session is mid-building.
3. **Build it — run ONLY Procedure step 3 (dev lifecycle) + step 4 (open the PR)** inside the shared
   worktree. The loop has already done the pick (Procedure step 1) and owns merge + teardown
   (Procedure step 5), so **do NOT run Procedure steps 1, 2, or 5 here.** Concretely:
   - **No `worktree add`** (Procedure step 2): the shared worktree already exists — branch _inside_ it
     off the **integration branch**
     `git fetch origin && git checkout -B <type>/<NN>-<slug> origin/<epic-branch>` (NOT
     `origin/<main>`), so each sub-issue starts from an `<epic-branch>` that already contains every
     sibling the loop merged into it earlier — no stacking needed. One branch + one card per
     sub-issue, path-explicit `git add`, issue thread kept as the live log throughout.
   - **The sub-PR targets `<epic-branch>`, not `<main>`**: open it with
     `gh pr create --base <epic-branch> …` and write the body with **`Refs #<NN>`, NEVER
     `Closes #<NN>`** (a sub doesn't target the default branch, so it must stay open until the final PR
     merges). This is the ONE epic-mode override of the standalone `Closes #<NN>` template in
     Procedure step 4.
   - **`/kickoff` is a self-audit, NOT an approval gate** in epic mode (Procedure step 3.1's "present
     the plan, get the go" is suspended): capability-audit the sub-issue, post the plan as an issue
     comment, and **proceed automatically** — the _only_ kickoff interrupt is a genuine owner-only
     design question (stop table, last row).
4. **Auto-merge the green sub-PR INTO `<epic-branch>`, then move on** (this replaces Procedure step 5's
   "stop at in-review / leave it for a later merge-pass" — in epic mode this loop is the only driver).
   A `<gate-label>` on a **sub does NOT block this** — it bubbles up to the final PR. Once the sub-PR
   is open, **wait for CI then merge it into the branch:**
   - Poll `gh pr checks <PR#>` (quick status — **never `--watch`**, it busts the 120 s Bash tool
     timeout). Wait between polls with a **bounded background poll** (a `while` loop that re-runs
     `gh pr checks` with a `sleep` _inside_ a `run_in_background` Bash command — foreground `sleep` is
     blocked — so it re-invokes you on exit) or the **`Monitor`** tool's until-loop. **Cap the wait**
     (e.g. ~15 min); if CI hasn't gone green by the cap, treat it as the red-gate stop (below), not a
     silent loop-exit.
   - On green **and** the UI gate satisfied for any `ui.paths`-touching sub-PR — a `<ui-reviewer>`
     PASS, or an explicitly recorded skip (`ui.enabled` false/absent, the runner exited `2`, or no
     `<ui-reviewer>` in `reviewers[]`; step 3's exit-code table):
     `gh pr merge <PR#> --squash --delete-branch` (this merges into **`<epic-branch>`**, the PR's base
     — never `<main>`). The sub-issue's card stays **in-review / open** (do NOT set it `done` — the
     sub-issue only closes when the final PR merges). On a red check, self-heal (fix → re-push →
     re-poll) up to ~3 attempts before escalating (gate row below).
   - **Open / update the ONE final `<epic-branch>→<main>` PR (idempotent).** If no open PR with head
     `<epic-branch>` and base `<main>` exists, open it **as a draft**; else refresh its body. Its body
     carries the closing keyword **repeated per number** — `Closes #<sub-a>, Closes #<sub-b>, …,
Closes #<N>` (one `Closes` per in-scope sub **and** the epic) so merging it later closes every sub - the epic atomically. **Do NOT** write the shorthand `Closes #a #b #N`: the tracker auto-closes
     ONLY the first `#` after a single `Closes`, which would orphan every later sub + the epic. Keep it
     a **draft** while any sub is still unbuilt/unmerged into the branch.
5. **Recompute readiness and go again** — readiness in epic mode = every dep is `CLOSED` **OR** that
   dep's sub-PR is already merged into `<epic-branch>` (the sub-issue itself stays open until the final
   PR, so a `CLOSED`-only check would deadlock the chain). The branch-merge you just landed satisfies
   the next sub's dependency, so repeat from step 2 until no ready sub-issue remains.
6. **Resolve the ONE final `<epic-branch>→<main>` PR, then tear down.** When every in-scope sub is
   merged into `<epic-branch>` (or already on `<main>`):
   - **Ungated** (no `<gate-label>` on the epic or any sub, and the aggregate `<epic-branch>` diff
     doesn't touch `ui.paths`): `gh pr ready <final PR>`, wait for the **aggregate** CI to go green,
     then `gh pr merge <final PR> --squash --delete-branch` — this lands the whole epic on `<main>` and
     its per-number `Closes #<sub>, …, Closes #<N>` body closes them all (repeat the keyword per
     number — never `Closes #a #b #N`). Then **run the project's close-out hooks
     (`hooks.close_out`, Procedure step 5) once for EVERY issue that merge closed**, the epic and
     each in-scope sub, since the subs only close here. Then run the **post-merge convergence audit**
     (step 7 below): it goes after the hooks and **before** teardown, while the worktree still exists.
     Only then remove the shared worktree (`git -C <repo> worktree remove <worktree>`) and report.
   - **Gated** (`<gate-label>` on the epic or any sub, or an aggregate diff touching `ui.paths`):
     `gh pr ready <final PR>` + `gh pr edit <final PR> --add-label <gate-label>`, post the handoff note
     on the epic, and **STOP** — the owner checks out `<epic-branch>`, tests the assembled whole, and
     merges. Leave the worktree in place. Nothing has closed yet, so neither the close-out hooks nor
     the convergence audit (step 7) runs on this path: name **both** in the handoff note as pending
     on the owner's merge, for whoever performs it. **Never auto-merge a gated final PR.** This stop
     is a _designed_ terminal state (the epic is built and parked at its gate), not a blocker:
     report it and finish cleanly.
7. **Post-merge convergence audit — runs exactly ONCE per epic, on whichever path performed the
   merge.** Spec-kit's `/speckit.converge` pattern, ported onto the issue rail: the per-sub reviewers
   certify each sub-PR individually (`goal-checker`, where this repo declares one), but integration
   gaps _between_ subs evaporate the moment everything is merged — this is the one check that
   re-verifies the ASSEMBLED result against everything the epic promised. On the **Ungated** path it
   runs here, after the close-out hooks and **before** the worktree teardown. On the **Gated** path
   nothing has merged yet, so it does **not** run here at all: the handoff note names it as pending on
   the owner's merge, and whoever performs that merge runs it. Never run it twice for the same epic.
   1. **Audit freshly-fetched `origin/<main>`, never the worktree.** `git fetch origin`, then read the
      merged result through `origin/<main>` (`git show origin/<main>:<path>`). That is _mechanical_
      here, not just the usual stale-checkout rule: the merge above ran `--delete-branch`, so
      `<epic-branch>` is already gone and `origin/<main>` is the only readable oracle left.
   2. **Re-read what was promised** — the epic body, and for every **closed** sub-issue its
      `## Acceptance Criteria` GIVEN/WHEN/THEN block. A sub that is still open (a late-added, unmerged
      straggler) is out of scope for this pass: note it in the audit comment, don't audit it.
   3. **Verify each AC against the merged code, then classify it.** Read the file/symbol it claims —
      **never infer from the PR description alone.**
      - **met** — nothing to do.
      - **missing / partial / contradicts** — a confirmed gap; file it (substep 5).
      - **descoped** — the owner deliberately dropped it mid-epic: note it, file nothing.
      - **unverifiable here** — it needs live production/pre-production state or a physical device:
        note it _and the reason_, and never guess a verdict.
      - **already tracked** by an open follow-up filed mid-epic — link it, don't refile.
   4. **Zero confirmed gaps ⇒ one comment, no issues:**
      `gh issue comment <N> --body "converged — no gaps vs #<N>"`, and file nothing.
   5. **Confirmed gap(s) ⇒ idempotent filing.** Search first —
      `gh issue list --search "Refs #<N>" --state open`, or the tracker's equivalent body search — and
      skip every gap an open issue already tracks. File each remaining gap as a NEW standalone issue to
      the full `/create-issue` discipline; its body carries **`Refs #<N>`, never a closing keyword**,
      and names the originating sub-issue + AC number, typed and prioritised on merit. **Without that
      skill, the rule holds anyway: open a plain tracker issue yourself** (title, what is wrong, how to
      reproduce, GIVEN/WHEN/THEN acceptance criteria, and a `## Security Implications` section that is
      never blank). Before filing a batch, **preflight the budget** the same way step 4 of `/epic`
      does (`gate.graphql_guard`): a gap issue plus its checklist comment is two writes each, and this
      runs unattended.

      **Releasing a gap issue is the one privileged act in this audit, so it is gated exactly like any
      other release — never by self-assertion.** You authored this body, so "it looks fine" is worth
      nothing: run the project's requirement-quality checklist against it (`checklist.section` out of
      `checklist.path`, every item by id, the same list `/triage` runs before its release relabel),
      post the completed per-item result as a comment on the gap issue leading with the
      `CHECKLIST:` header, and only then apply `<ready>`. **File without `<ready>` — and say so in the
      audit comment — whenever any item fails, whenever the checklist could not run (`checklist.path`
      unreadable or `checklist.section` not found), and whenever no `checklist` is bound at all.**
      An unattended agent must never hand its own output the pickup label on the strength of a bar it
      did not actually apply; a human or a later `/triage` pass can always release it afterwards.

      Then post one summary comment on the epic listing every gap number
      filed. Under `tracker: none` there is nothing to search and nothing to file: record the audit
      result wherever the project keeps its log.
   6. **Append-only, always.** The audit reads issues, files new ones, and posts comments — it
      **NEVER** reopens a closed sub-issue and **NEVER** edits a shipped issue's body, even to
      "correct" it.

> **Resume contract:** the loop is re-entrant. If it's interrupted (a dead agent, a crash, you stop
> it), just re-invoke `/implement-issue <epic#>` — it re-attaches to the existing `<epic-branch>`
> branch, worktree, and final PR idempotently, recomputes readiness from live state (a sub whose PR is
> already merged into `<epic-branch>` counts as satisfied), and resumes at the next ready sub. It
> tolerates an epic **partially on `<main>`** already — a sub merged straight to `<main>`, or a sub
> with an open PR against `<main>` — by retargeting the stray PR onto `<epic-branch>`
> (`gh pr edit --base <epic-branch>`, `Closes`→`Refs`) and treating an already-merged sub as satisfied.
> Nothing is lost, nothing is double-built.
>
> **Step 7's audit re-attaches the same way, off its own markers on the tracker** — alongside the
> branch, the worktree and the final PR: the `converged — no gaps vs #<N>` comment on the epic, or the
> gap issues carrying `Refs #<N>` plus the summary comment listing them. Markers present ⇒ this epic
> has already been audited, so don't audit it again; markers absent ⇒ it never was. **A fully-merged,
> closed epic is therefore NOT the "epic ISN'T complete" stop below**: re-entering on one leaves
> exactly step 7 to do — run the audit if its markers are absent, report converged if they are
> present, and finish.

**Stop ONLY when one of these is true — then report and hand back** (between sub-issues the loop does
**not** pause to ask; these are the only interrupts):

| Stop reason                                                                                                                                                                              | What to do                                                                                                                                                                                                                                                                                                                                     |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **All subs merged into `<epic-branch>`, final PR ungated + aggregate CI green**                                                                                                          | `gh pr ready` the final `<epic-branch>→<main>` PR, squash-merge it to `<main>` (its per-number `Closes #<sub>, …, Closes #<N>` body — keyword repeated per number — closes them all), then — in this order — run the close-out hooks, run the convergence audit (step 7), tear down the worktree, and report.                                                                         |
| **All subs merged into `<epic-branch>`, but the final PR is gated** (`<gate-label>` on the epic or any sub, or an aggregate diff touching `ui.paths`)                                    | `gh pr ready` the final PR + `gh pr edit --add-label <gate-label>`, post the handoff note, and **STOP** — the owner merges the assembled whole. The handoff note names the close-out hooks and the convergence audit (step 7) as pending on that merge. Leave the worktree in place; report the merged subs + the pending final PR.            |
| **No ready sub-issue remains but the epic ISN'T complete** — all remaining are blocked (an owner-gated dep, a parked sub without `<ready>`, or a malformed/cross-epic `Depends on`)      | Classify _why_ each remaining sub-issue is blocked, comment that classification on the epic, and **leave the shared worktree in place** (only the all-merged ungated path removes it) so a follow-up can resume.                                                                                                                               |
| **Remaining work is owner-gated** — a live apply to a shared/production environment, a step that can only run on the target host (secrets, backups, service units), a production release | Don't force it. Finish everything you _can_ first, then list the gated steps for the owner. The _authoring_ of such a change and its PR still merge (CI runs the gate against the test environment); only the **live apply** is gated — collect it, don't block the loop on it.                                                                |
| **A gate stays red after ~3 self-heals** — the quality gate, a RED UI runner / `<ui-reviewer>` FAIL, or CI past the wait cap                                                             | Stop on that sub-issue, leave its card **in-progress**, and take the headless-legal terminal action: no PR merge, post the cited failure as a comment on the sub-issue, exit non-zero. Do **not** advance as if it merged. (A UI runner exiting `2` is **not** this row — it could not run, so it is a recorded skip and the loop carries on.) |
| **`/kickoff` surfaces a genuine design question** only the owner can answer                                                                                                              | Post the one question as a comment on the issue, do not open the PR, exit non-zero. Resume the loop by re-invoking it once the question is answered on the thread.                                                                                                                                                                             |

> **Why sequential on one worktree (not a fan-out):** two reasons, in order. (1) **The hard one** —
> each sub-issue's lifecycle must run in the main session so the gates can spawn their reviewer agents
> (above), which rules out a subagent-per-item fan-out. (2) **The owner's explicit choice** — one
> shared worktree, worked through in dependency order, each sub auto-merging into `<epic-branch>` as it
> goes (so each next branch off `origin/<epic-branch>` already carries its prerequisites). Independent
> sub-issues _could_ in principle run in parallel, but here they're run sequentially **by design** —
> this is the sanctioned exception to the repo's fan-out default, not an oversight.

## The issue is a live log — update it at EVERY step

**The issue is the single source of truth for "what's been done".** Someone else (or you, in a later
session) must be able to read the issue's comment thread and see _exactly_ where the work stands —
what's complete, what's in flight, what's left — without reading the diff or asking. So **every step
below posts a progress comment to the issue as it finishes** — kickoff, each implementation chunk, the
migration, the quality gate (pass _and_ fail), the PR. A silent worktree is a failure mode: if the
thread stops, the next person can't tell if anything happened.

- **Comment when you start a step and when you finish it** — not just at the very end.
- Keep each comment short and factual: **what changed, what's green, what's next.** Reference commit
  SHAs / file paths so the log is auditable.
- A reusable shape (use throughout):
  ```bash
  gh issue comment <NN> --body "✅ <step>: <what's done>. Next: <what's next>."
  ```

## Procedure

### 1. Pick the work (label-scoped, sequence-aware)

**Pickup scope — the driver loop and this skill share ONE label: `<ready>`.** This is the _only_ filter,
and it is stated once, here. An issue carrying `<ready>` is fair game for either the unattended driver
or a manual build; an issue WITHOUT it is held back — the safe default for un-triaged/legacy work, and
the parking lever (remove `<ready>` to park a misbehaving issue). An explicit issue number always
overrides the filter.

| Invocation                  | Scope                                                                           |
| --------------------------- | ------------------------------------------------------------------------------- |
| `/implement-issue` (no arg) | the open `<ready>` queue (ready sub-issues first)                               |
| `/implement-issue 42`       | that exact issue, whatever its labels (an explicit number overrides the filter) |

- **Pull the open `<ready>` queue:**
  ```bash
  gh issue list --state open --label <ready> --limit 50
  ```
  > **Never widen the pickup filter.** An issue with **no `<ready>` label is invisible to this skill by
  > design** — that's a triage gap (or a deliberate park), not a pick. Label it `<ready>` first; do
  > **not** drop `--label`, substitute another label, or add a second one to "find" it. Work that is
  > deliberately fenced (anything _applied to_ a live host, or that the driver cannot verify inside its
  > fence) is intentionally left without `<ready>` so the loop won't auto-build it; build that by
  > explicit number, from the right place, when a human is driving.
- If the person **named an issue number** (`/implement-issue 42`), use it directly — explicit selection
  overrides the filter; don't silently skip an explicitly-named issue even if it lacks the label.
- Otherwise present the queue **grouped**: standalone issues, and each **epic** with its sub-issues.
- **Compute readiness for sub-issues.** Parse `Depends on #NNN` from the issue body
  (`gh issue view <n> --json body`). A sub-issue is **ready** iff _every_ dep is closed
  (`gh issue view <dep> --json state -q .state` → `CLOSED`), else **blocked**. Show ready vs blocked.
  (**Epic mode:** a dep is _also_ met once its sub-PR is merged into `<epic-branch>` — even though the
  dep's issue is still open — so a branch-merged prerequisite unblocks the next sub.)
- **Recommend the highest-priority, lowest-numbered ready sub-issue** (`labels.priority_order` in
  order, then no priority label last; number breaks ties — the armed driver's order) in the active epic
  (or let the person choose). If they pick a **blocked** one, say which dep isn't merged and confirm
  before proceeding — don't silently build on an unmet prerequisite.
- **`labels.ultra` → build depth.** If the picked issue carries the `labels.ultra` label, this build
  runs at Claude Code's **`ultracode`** effort mode — its own internal multi-agent depth, not a bespoke
  fan-out this skill builds. The driver's fire literally appends `--effort ultracode`; picking it up
  interactively, prefer starting/continuing the session at that same effort level. It changes **only**
  HOW the build is done — the quality gate, the reviewer gates in `reviewers[]`, and the merge policy
  are unaffected.

### 2. Spin up the worktree

> **Epic mode overrides this step** — the shared epic worktree already exists; branch _inside_ it with
> `git checkout -B <branch> origin/<epic-branch>` (the integration branch, **not** `origin/<main>`)
> instead of `git worktree add`. (See "Epic mode" up top.)

- Choose a branch name from the issue: `<type>/<NN>-<slug>` — `branch.bug_prefix` for a
  `labels.bug` issue, `branch.feature_prefix` for a `labels.enhancement` one — lowercase, hyphens,
  no longer than `branch.slug_max_len` (per the `git-workflow` skill; **if that skill is not vendored
  here, the rule it carries is exactly the sentence you just read**: one branch per issue, named
  `<type>/<NN>-<slug>` off fresh `origin/<main>`, lowercase and hyphenated within
  `branch.slug_max_len`, so apply it inline and carry on).
- Branch from fresh `<main>` into a **sibling worktree** (the house pattern):
  ```bash
  git -C <repo> fetch origin
  git -C <repo> worktree add -b <branch> <worktree> origin/<main>
  ```
- **Mark it in progress AND claim it:** move the board card, **assign yourself**, and drop a comment
  so the issue reflects reality:
  ```bash
  <board-cmd> <NN> in-progress     # skip silently if `board` is absent; never let it block the build
  gh issue edit <NN> --add-assignee "@me"
  gh issue comment <NN> --body "Picking this up on \`<branch>\` (worktree)."
  ```
  > **The assignee is the CLAIM the armed loop respects:** the loop's discovery skips any assigned
  > issue, closing the pick-race window between "worktree started" and "PR opened" (before a PR exists,
  > nothing else marks the work in flight). The loop's own builds never assign — so if you abandon a
  > manual pickup, unassign to release it back to the loop.
  >
  > **The board Status is the SINGLE SOURCE OF TRUTH for issue state** where a board is configured. Do
  > **not** maintain a parallel in-progress _label_; the card on the board (`board.number`) carries the
  > state, and `board.command` bakes in every constant — you pass only the issue number + a status from
  > `board.statuses`. **A board write failure must never block a build:** log it and carry on.

### 3. Dev lifecycle (inside the worktree)

Work from the new worktree directory for everything below. **Post a progress comment to the issue at
the end of each step** (see "The issue is a live log" above) — the thread is how the next person knows
what's done.

#### Project review anchors: the FIFTH input to every reviewer spawn

**A reviewer agent starts in a FRESH context.** It does **not** inherit this session's `CLAUDE.md`
or `.claude/PROJECT.md` import, its conventions or its memory, so **anything you do not paste into
its task prompt does not exist for it.** The reviewer agents are vendored and identical in every
repo; the concrete house rules that give their lenses teeth here live in the project-owned file
**`.claude/REVIEW-ANCHORS.md`**. **Read that file before spawning any reviewer below, and hand the
relevant section over verbatim as an input in its own right:**

| Reviewer               | Section to paste in verbatim                               | Where it lands in the agent            |
| ---------------------- | ---------------------------------------------------------- | -------------------------------------- |
| `correctness-reviewer` | `## Correctness anchors`                                   | lens 1, its "project hard lines"       |
| `security-reviewer`    | `## Security anchors`, `### <lens>` headings intact        | each named lens, keyed by that heading |
| `goal-checker`         | none: it certifies the issue's ACs, not project invariants | n/a                                    |
| `<ui-reviewer>`        | none: its oracle is the design spec named in its own brief | n/a                                    |

- **Paste it, don't point at it.** "Go and read `.claude/REVIEW-ANCHORS.md`" is the agent's own
  documented _fallback_; handing the anchors over is the spawner's job and the only guaranteed path.
  State in the task prompt that the anchors are handed in, so the reviewer records
  `ANCHORS: handed in task` in its verdict.
- **Keep the lens keys in step.** The `### <lens>` headings under `## Security anchors` are keyed to
  `security-reviewer`'s own lens names (`authz-idor`, `api-authn-authz`, `input-validation`,
  `injection`, `secret-leakage`, `supply-chain`, `ssrf-path-traversal`, `error-info-leak`). A
  heading that matches no lens is an anchor nobody reads: if the two ever drift, fix the mismatch
  rather than pasting an orphaned section.
- **File or section absent: the narrowing is DECLARED, never silent.** Spawn the reviewer anyway,
  say in the task prompt that no project anchors exist, and require it to record
  `ANCHORS: none — universal lenses only` in its verdict. Then carry that narrowing through to the
  issue comment and the PR body. Missing anchors are a narrowed review, not a failed one; a review
  that quietly ran fewer lenses passing as a full one is the failure.

1.  **`/kickoff`** — capability-audit the issue against existing skills, agents, and the `CLAUDE.md`s
    before writing code, so you don't rebuild something that exists. Present the plan, get the go.
    (**Epic mode:** the "get the go" is suspended — kickoff self-audits, posts the plan as a comment,
    and proceeds automatically; pause only for a genuine owner-only design question.)
    → **Log:** comment the agreed plan / scope on the issue so the approach is on record.
2.  **Implement** to the issue's Acceptance Criteria. Follow the repo's own engineering conventions —
    the root `CLAUDE.md` and any nested `CLAUDE.md` covering the area you're touching (its runner, its
    layout, its hard lines).
    → **Log:** comment as each meaningful chunk lands — _what_ was built and the commit SHA(s) — so a
    half-finished issue shows exactly which Acceptance Criteria are done and which remain.
3.  **Schema / data-migration change?** Author it the project's way (a repo may ship a dedicated
    migration skill; follow it). The **live apply to a shared or production environment** is a gated,
    outward-facing step — flag it for the owner, do **not** auto-apply.
    → **Log:** comment the migration id + whether it's been applied to the shared environment yet (so
    the gated apply isn't silently forgotten).
4.  **Run the gate** — `<gate>` (`gate.command`). It **must be green** before a PR. Satisfy
    `gate.prereq` first if the environment doesn't already provide it — in a headless driver container
    the dependency is often supplied already (e.g. a database the container points the gate at), in
    which case **skip the prereq**; don't fail on a missing container runtime the gate doesn't need. The
    gate is the single source of truth for "green": read its output rather than assuming which legs it
    runs. It may include a **patch-coverage leg that hard-blocks** when the new/changed lines in the
    diff fall below its threshold — add tests for the lines it lists, or mark a genuinely unreachable
    one with the language's no-cover pragma.
    → **Log:** comment the gate result **whether it passes or fails** — the pass summary on green; the
    failing test/error/uncovered lines on red so a blocked issue shows _why_ it's blocked.

    #### UI gate — **fires only when `ui.enabled` AND the diff touches `ui.paths`**

    If `ui.enabled` is false or absent, **skip this whole gate** and say in the PR body that no UI gate
    ran. Never substitute a guess at design conformance.

    If (and only if) this issue's diff touches a path in `ui.paths`, the standard gate is **not
    sufficient** — the PR must also pass the visual/e2e UI gate **before it can go green or open a PR**.
    The gate judges the **whole composed page, not just the component this issue touched** —
    composition regressions (a grid-stretched card left with a dead band, ragged cross-component
    rhythm) are cross-cutting and have slipped through per-component review before. Run it as the
    in-review ↔ in-progress rework loop, automated:
    1.  **Run the UI runner** — `<ui-gate>` (`ui.command`: it boots the app, runs the e2e + the
        layout-lint, and captures multi-viewport screenshots — both the per-component shots AND the
        whole-page shot). The e2e **fixtures must stretch the grid** (at least one tall component and one
        long list, so the short components inherit the row height) — a dead-band bug only renders when a
        component is stretched, and grids typically only stretch at the large breakpoint, so the **wide
        viewport** shots are the ones composition is judged on.

        **Judge on the exit status, never on how the output looks.** Capture the status explicitly
        rather than inferring it from stdout, because a path-shaped string on stdout is not evidence
        the gate passed:

        ```bash
        status=0
        OUT_FILE="${TMPDIR:-/tmp}/ui-gate.out"
        <ui-gate> > "$OUT_FILE" || status=$?        # status of the runner itself, no pipeline
        SHOTS="$(tail -n1 "$OUT_FILE")"             # last stdout line, only meaningful when status is 0
        ```

        **Start the line with the runner, not with a capture.** Redirecting to a scratch file keeps the status
        honest _and_ leaves the command itself at the head of the line, so a permission allow-rule
        written against `ui.command` actually matches it. Wrapping it as `OUT="$(<ui-gate>)"` buries the
        command inside a substitution, and a rule naming the runner then fails to match, so an
        automated run stops for a prompt that nobody is there to answer.

        **Do not fold the `tail` into the status-bearing substitution.** `X="$(<ui-gate> | tail -n1)"`
        reports `tail`'s status, not the runner's, so unless the calling shell happens to have
        `pipefail` set it hands you `status=0` with an empty `SHOTS` on a could-not-run: precisely the
        skip-laundered-into-a-pass this gate exists to stop. Split the pipeline as above and the
        reading is correct whatever options the shell was started with.

        | Exit               | Meaning                                                                                                              | What it demands                                                                                                                                                                                                                                                                                                                                 |
        | ------------------ | -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
        | `0`                | **PASS.** The runner ran in full and the UI is green. Its **last stdout line is the absolute screenshot directory.** | Hand that directory to `<ui-reviewer>` (item 2) and carry on through the gate.                                                                                                                                                                                                                                                                  |
        | `2`                | **COULD NOT RUN.** The runner is absent, or a tool it needs is missing. Nothing was proved either way.               | **Record the skip explicitly and carry on with the build.** Comment `no UI gate ran (runner exited 2, could not run)` on the issue and write that same line into the PR body's Test plan. Do **not** spawn `<ui-reviewer>` on a directory that does not exist, do **not** spend a self-heal attempt on it, and **never** let it read as a pass. |
        | any other non-zero | **RED.** The runner ran and the UI failed (boot, e2e, or layout-lint).                                               | Self-heal per item 4, within `LOOP_MAX_RETRIES`, then the headless-legal terminal action.                                                                                                                                                                                                                                                       |

        > **This table is the authoritative contract for `ui.command`.** It is stated here, once, and
        > every repo's own runner implements it. In this repo that runner is
        > `.claude/scripts/ui-gate.sh`, whose header points back at this table rather than restating
        > it. If a runner's own docs ever disagree with this table, this table wins and the runner is
        > the bug.
        >
        > **Exit `2` is the code that gets misread, in both directions.** Laundered into a pass, it
        > ships an unreviewed UI; mistaken for a red, it burns the whole retry budget "fixing" a page
        > that was never rendered. It is neither: it is a declared skip, and a declared skip is
        > headless-legal (never a reason to stop and ask, because there is nobody to ask).

    2.  **Spawn the `<ui-reviewer>` agent** (the `reviewers[]` entry whose `when` matches `ui.paths`;
        **main session only** — a subagent cannot spawn it) on three inputs: the screenshot dir from step
        1, the project's design spec (the review oracle named in the reviewer's own brief), and **the
        issue's intent** (its title / body / Acceptance Criteria). **Always instruct it to judge the
        page-wide Composition lens on the WHOLE-PAGE screenshot — the whole composed page, not just the
        component the issue touched** — so a composition breach (a stretched component with a dead band,
        ragged cross-component rhythm) FAILs the gate even when the touched component is itself clean.
        The issue's intent scopes WHAT must be present; it never narrows the review surface. It returns
        `VERDICT: PASS` or `VERDICT: FAIL` (the `composition` lens rolls into the verdict — a breach in
        any lens is a FAIL) with cited violations.

              **No `<ui-reviewer>` in this repo's `reviewers` table** (no entry whose `when` matches
              `ui.paths`) is a decision, not an oversight: skip this item, record `no design review ran (no

        such reviewer in this repo)` on the issue and in the PR body, and carry on. Never substitute
        another reviewer for it, and never claim a design review ran.

    3.  **Both green** (the runner exited `0` **and** the reviewer returns `VERDICT: PASS`): proceed to
        commit / PR. Screenshots are **never committed to the repo** — they're transient gate output,
        uploaded by the CI UI-gate job as an artifact and already reviewed by `<ui-reviewer>`.
        Comment the reviewer's verdict on the issue for the record.
    4.  **Either fails** (the runner exited non-zero **and not** `2`, **or** the reviewer returns
        `VERDICT: FAIL`): **do NOT open the PR.** Self-heal — apply the fixes the lint/reviewer cite,
        re-run the UI gate — for up to `LOOP_MAX_RETRIES` (the driver's loop-guard cap, default 3). Only
        **escalate** if it's still failing after that (headless-legal terminal action: no PR, blocker
        comment on the issue, exit non-zero). (This is the in-review ↔ in-progress rework loop below, run
        automatically.) **A runner exit of `2` is NOT this case:** it could not run, so it is a recorded
        skip (item 1's table), it consumes no self-heal attempt, and the build carries on.
        → **Log:** comment the UI-gate outcome each pass — the reviewer verdict on green (screenshots live
        in the CI artifact, not the repo); the cited violations + which self-heal attempt on red; the
        explicit `no UI gate ran` line on a skip (`ui.enabled` false/absent, runner exit `2`, or no
        `<ui-reviewer>`), never phrased as a pass.

    #### Backend code-correctness gate — **fires for a non-trivial diff under the reviewer's `when` path**

    > **Merge is additionally gated by every REQUIRED check the project defines at the merge door.**
    > This correctness gate and the security gate below run inside THIS author session and gate
    > **PR-open**. At the merge door the merge poll additionally requires **every** required CI check to
    > have concluded success — deterministic checks a reviewer cannot vouch for are the point. Never
    > neuter, skip, or merge around a required check.

    The deterministic gate proves the changed lines _execute_; it does **not** prove any assertion
    _observes_ the bug, and on a pure-backend diff `<ui-reviewer>` never fires — so the diff is
    otherwise graded by nobody but its author (a "nodding loop"). This gate closes that hole: an
    independent, read-only, **fail-closed** `correctness-reviewer` (the backend twin of
    `<ui-reviewer>`, and the side-by-side sibling of the security gate) judges the diff before a PR
    opens. It **fires** when the diff touches the path named in that reviewer's `when` entry in
    `reviewers[]` (the backend source tree); it **skips** a docs/comment/format-only diff and a pure
    `ui.paths` diff (which `<ui-reviewer>` owns). Like the UI gate, run it as the in-review ↔
    in-progress rework loop, automated:
    1. **Spawn the `correctness-reviewer` agent** (its `reviewers[]` entry by name, exactly as the UI
       gate spawns `<ui-reviewer>`) **from the
       orchestrating layer — never the implementing subagent** (it cannot spawn the reviewer, and
       self-spawning recreates the nodding loop). Hand it **five** inputs: `git diff
origin/<main>...HEAD`, the changed-files list, the **green** gate output, the **issue intent**
       (title / body / Acceptance Criteria), and the **project correctness anchors** pasted verbatim
       from the `## Correctness anchors` section of `.claude/REVIEW-ANCHORS.md` (its lens 1; see
       "Project review anchors" at the top of this step). If that file or section is absent, say so
       in the task prompt, require `ANCHORS: none — universal lenses only` in the verdict, and repeat
       the narrowing in the PR body. For a **bug-fix** diff, also generate the **red-green evidence**
       first per the `regression-proof-red-green` skill (the test FAILs RED on the pre-fix code, PASSes GREEN on
       the fix) — the reviewer **verifies** it read-only; it does not produce it. **If that skill is not
       vendored here the rule stands on its own: run the new test against the pre-fix code and show it
       FAIL, then against the fix and show it PASS, and paste both outputs.** An assertion never seen
       to fail proves nothing. Apply that inline and carry on; a missing skill is never a stop.
       (Greenfield diffs have no revert target — the reviewer asserts behaviour-presence instead; do not
       demand RED.)
    2. **Read the verdict.** The reviewer returns the structured `VERDICT: PASS | FAIL` block (PER-LENS
       NOTES + cited, falsifiable VIOLATIONS) — the same shape as `<ui-reviewer>`. A breach in ANY
       lens (the repo's hard lines · generic correctness · test-oracle independence) ⇒ FAIL (do **not**
       average). A missing input / empty diff / red gate / unreachable dependency ⇒ FAIL, never PASS
       blind.
    3. **PASS:** proceed to commit / PR. Comment the verdict on the issue for the record.
    4. **FAIL:** **do NOT open the PR.** Self-heal — apply the cited fixes, re-run the gate + reviewer —
       for up to `LOOP_MAX_RETRIES` (default 3). Only **escalate** if it's still FAIL after that (no PR,
       blocker comment on the issue, exit non-zero); never silently open a PR on a still-FAIL verdict.
       → **Log:** comment the reviewer verdict each pass — PASS (with the per-lens roll-up) on green; the
       cited violations + which self-heal attempt on FAIL.

    #### Stop-condition gate (`goal-checker`) — **fires for EVERY issue, once the gate is green**

    The deterministic gate + the design/correctness reviewers prove the change is _well-built_; none of
    them prove the issue's **Acceptance Criteria were actually implemented** — a green gate means "the
    tests pass", not "the goal was hit". The `goal-checker` (the `reviewers[]` entry with
    `when: always`) is the third independent judge: spawned **from the orchestrating layer in a fresh
    context, separate from the implementer** (never from inside the implementing subagent), on **every**
    issue once the gate is green. Hand it the issue's `## Acceptance Criteria` GIVEN/WHEN/THEN block,
    `git diff origin/<main>...HEAD`, and the green gate output. It returns
    `verdict: done | not-done | broken` (per-AC cited): **`done`** = every AC met AND gate green (the
    only verdict that permits a merge); **`not-done`** = gate green but ≥ 1 AC unmet; **`broken`** =
    gate red, a regression, or **no parseable ACs** (it never returns `done` when there's nothing to
    certify).
    - **`done`:** proceed to commit / PR; comment the verdict for the record.
    - **`not-done` / `broken`:** **do NOT open the PR.** Self-heal the cited unmet ACs — re-run the
      gate + checker — up to `LOOP_MAX_RETRIES`, then **escalate** with the cited ACs (blocker comment
      on the issue, exit non-zero); never merge a `not-done` / `broken`.
      → **Log:** comment the checker verdict each pass — `done` (with the per-AC roll-up) or the unmet
      ACs + which self-heal attempt.

    > **The loop-guard primitives back this gate.** The self-heal cap above is `LOOP_MAX_RETRIES`
    > (default 3); an unattended driver additionally enforces the per-run / daily **budget caps**, a
    > **halt-file kill-switch** (a file, so it halts a _running_ loop with no restart), and a JSONL
    > **run-state ledger** — all fail-closed.

5.  **Commit with discipline** (`git-workflow`): review the diff, stage specific files (not
    `git add -A`), atomic conventional commits that reference the issue:
    ```bash
    git commit -m "feat(scope): <subject>" -m "" -m "Refs #<NN>"
    ```
    **If `git-workflow` is not vendored here, that one line above IS the rule:** read the diff before
    staging, `git add` explicit paths only, one logical change per commit, conventional subject, and a
    `Refs #<NN>` trailer. Apply it inline and carry on.
    → **Log:** the `Refs #<NN>` trailer already links each commit to the issue; add a comment if the
    commit closes out an Acceptance Criterion so the thread stays readable.
6.  **Security review — the last engineering step.** The diff is now whole, green, and committed —
    assess its security posture before the PR opens. **Unconditional**: this runs for **every** issue,
    not just `ui.paths`-touching ones — the security surface (authz/IDOR, secrets, injection,
    dependencies) is mostly non-UI (data services, API routes, sync jobs), so gating only the UI paths
    would miss the highest-risk changes. It is **independent** of the UI gate above — on a
    `ui.paths`-touching issue both must PASS; security does not replace design review, and it runs even
    when design review doesn't (a pure-backend diff). Run it as the in-review ↔ in-progress rework loop,
    like the UI/correctness gates:
    1. **Spawn the `security-reviewer` agent** (the `reviewers[]` entry with `when: always`) **from the
       MAIN session — never the implementing subagent** (a subagent cannot spawn another agent, so a
       security review triggered from inside an implementing subagent silently never runs). Hand it
       **four** inputs: `git diff origin/<main>...HEAD`, the changed-files list, the issue intent
       (title / body / Acceptance Criteria), and the **project security anchors** pasted verbatim
       from the `## Security anchors` section of `.claude/REVIEW-ANCHORS.md`, `### <lens>` headings
       intact so every lens gets its own pointers (see "Project review anchors" at the top of this
       step). If that file or section is absent, say so in the task prompt, require
       `ANCHORS: none — universal lenses only` in the verdict, and repeat the narrowing in the PR
       body. _Requires the reviewer's agent shim to be registered — the agent registry
       loads at boot, so a newly vendored reviewer needs one Claude Code restart before it is spawnable;
       if it isn't, spawning fails — see the fail-safe below._
    2. **Also run the built-in `/security-review`** on the pending branch diff — the deterministic
       scanner-and-LLM layer that ships with Claude Code, alongside the dedicated agent.
    3. **Fail-safe, never fail-open:** if the `security-reviewer` agent cannot be spawned (shim not
       registered, or any other spawn failure), treat that as **"gate not satisfied"** and escalate —
       do **not** silently skip the gate and open the PR. If `reviewers[]` genuinely has no security
       entry, say so in the PR body; never claim a review ran.
    4. **Both clean** (`security-reviewer` returns `VERDICT: PASS` and `/security-review` reports no
       confirmed high/critical finding): proceed to step 4 (open the PR). Comment both verdicts on the
       issue for the record.
    5. **Either flags a problem** (`security-reviewer` returns `VERDICT: FAIL`, or `/security-review`
       reports a confirmed high/critical finding): **do NOT open the PR.** Self-heal — apply the cited
       fixes, re-run both — for up to `LOOP_MAX_RETRIES` (default 3). Only **escalate** if still failing
       after that (blocker comment on the issue, exit non-zero).
       - **Disputed finding (false positive):** record the dispute + rationale on the issue thread;
         downgrade to a `MINOR OBSERVATION` only with explicit reasoning — never delete a `FINDING`
         just to make the gate pass.
       - **A defect outside this issue's scope** (e.g. a pre-existing leak): file it standalone via
         `/create-issue` and reference the number — don't expand the current PR to fix it. **Without
         that skill, the rule holds anyway: open a plain tracker issue yourself** (title, what is
         wrong, how to reproduce, GIVEN/WHEN/THEN acceptance criteria, and a `## Security Implications`
         section that is never blank), reference its number here, and carry on. Never widen this PR and
         never drop the finding on the floor because the authoring skill is missing.
         → **Log:** comment both verdicts each pass — the `security-reviewer` verdict + "`/security-review`
         scanners green" (plus any accepted residual risk) on clean; the cited findings + which self-heal
         attempt on FAIL.

### 4. Open the PR

> **Epic mode overrides the PR base + closing keyword:** for an epic sub-issue the PR targets the
> integration branch — `gh pr create --base <epic-branch> …` — and its body uses **`Refs #<NN>`, NEVER
> `Closes #<NN>`** (a sub doesn't target the default branch, so it must stay open until the epic's
> final PR merges). The `Closes #<NN>` template below is the **standalone** shape; leave it as-is and
> apply this override only in epic mode.

- **Autonomy — no human in the per-PR loop.** Once the local gate and every applicable reviewer in
  `reviewers[]` PASS — `<ui-reviewer>` (`ui.paths`), `correctness-reviewer` (backend),
  `security-reviewer` (every issue), **and** `goal-checker` = `done` (every issue) — the implementer
  pushes + opens the PR + sets the card to in-review with no human step; the **orchestrating layer
  merges it** the moment CI is green (step 5 — the implementer does NOT block-watch). Don't stop to ask
  before pushing a green, reviewer-passed change; the person's gate is the **running system**, not the
  PR.

  > **Where there is no server-side branch protection the gate is agent-enforced:** merge ONLY on a
  > green CI **and** a PASS from every applicable reviewer — the reviewer legs are **AND-ed**, never
  > averaged. On any failure, do NOT merge — self-heal (apply the cited fixes, re-run the gate) up to
  > `LOOP_MAX_RETRIES` (default 3), then escalate.
  > **UI gate:** for any PR touching `ui.paths` (when `ui.enabled`), the UI gate must be **satisfied**
  > before this PR step runs — see "UI gate" under step 3 above (e2e + layout-lint + multi-viewport
  > screenshots, then a `<ui-reviewer>` PASS). Screenshots stay OUT of the repo (CI artifact only).
  > _Satisfied_ means either green **or** an explicitly recorded skip (`ui.enabled` false/absent, the
  > runner exited `2`, or this repo declares no `<ui-reviewer>`). A skip is written into the PR body
  > verbatim and never phrased as a pass. A `ui.paths`-touching PR whose UI runner came back **RED**
  > (any non-zero other than `2`) or whose `<ui-reviewer>` returned FAIL must not be opened.
  > **Security gate (unconditional):** every PR, UI-touching or not, must also have a clean
  > `security-reviewer` verdict + `/security-review` pass before this step runs. Independent of the UI
  > gate — both must PASS on a `ui.paths`-touching PR.

  ```bash
  git -C <worktree> push -u origin <branch>
  gh pr create --title "<type>(<scope>): <subject>" \
    --body "$(cat <<'EOF'
  ## Summary
  - <what changed and why>

  ## Security
  - <security-reviewer verdict summary, e.g. "PASS — no findings"> + "`/security-review` scanners
    green" + any accepted residual risk (with rationale, if a disputed finding was downgraded)

  ## Test plan
  - [ ] the project gate (`gate.command`) green
  - [ ] <issue-specific verification>
  - [ ] <if `ui.enabled` is false/absent: "no UI gate ran (none configured for this repo)">
  - [ ] <if the UI runner exited 2: "no UI gate ran (runner exited 2, could not run)". A skip,
    never a pass.>
  - [ ] <if a reviewer in `reviewers[]` is absent: name it and say no such review ran, e.g. "no
    design review ran (no such reviewer in this repo)">
  - [ ] <if `.claude/REVIEW-ANCHORS.md` is absent: "reviewers ran their universal lenses only, no
    project anchors supplied">

  Closes #<NN>
  EOF
  )"
  ```

- **Move the card to in-review** the moment the PR is open (skip silently if `board` is absent):
  ```bash
  <board-cmd> <NN> in-review
  ```
- `Closes #<NN>` auto-closes the issue on merge. Use `--draft` for WIP that needs early eyes. Under
  `tracker: none` there is no issue to close: drop the keyword rather than invent a number.

### 5. Close-out

> **Epic mode overrides this step's merge handoff** — there, _this loop_ is the orchestrating layer, so
> it waits for CI and merges each green **sub-PR into `<epic-branch>`** itself (Epic-mode step 4),
> maintains the ONE `<epic-branch>→<main>` final PR, and resolves that final PR per its gate (Epic-mode
> step 6: ungated ⇒ squash-merge to `<main>` + teardown; gated ⇒ ready + `<gate-label>` + STOP). It
> removes the worktree once at the end (never per sub-issue), and "leave it for a later merge-pass"
> does NOT apply. The **close-out hooks below still apply in epic mode**, but they fire once at the
> final merge, for every issue that merge closed (Epic-mode step 6), never per sub-PR: a sub-PR
> merging into `<epic-branch>` closes nothing. The text below governs the single-issue / fan-out flow.

- **The implementer STOPS at in-review.** Open the PR, set the card in-review, report the PR#, and
  STOP. Do NOT block on `gh pr checks --watch` inside the implementing agent — it exceeds the Bash
  120s tool timeout, and a long-lived agent is exposed to transient API errors (a 5xx mid-watch kills
  the agent before it merges; the work is safe in the green PR, but the merge is lost).
- **Merge is a separate, quick, re-runnable step by the ORCHESTRATING layer** (the main session, or
  the workflow that fanned the agents out) once CI is green — never a long block inside the implementer:
  ```bash
  gh pr checks <PR#>        # quick status, NOT --watch
  # merge ONLY if: every required check passes AND every applicable reviewer in reviewers[] PASSed
  # (<ui-reviewer> for ui.paths, correctness-reviewer for backend, security-reviewer + goal-checker
  # = done for every issue):
  gh pr merge <PR#> --squash --delete-branch
  <board-cmd> <NN> done
  ```
  If checks are still pending, leave it — a later merge-pass picks it up (a dead/timed-out agent never
  loses a merge). On a red CI, do NOT merge — rework (fix, re-push, card stays in-review). `Closes #NN`
  does the rest. For a sub-issue, the tracker's native sub-issue progress on the epic updates
  automatically, and the epic body's `## Planned Sub-Issues` list shows it done on its own — the inline
  `#NN` reference renders struck-through once the issue is closed, so there is **no checkbox to tick**
  and no epic-body edit needed on merge.
- **Run the project's close-out hooks** (`hooks.close_out` in the manifest) once the PR is merged
  and the issue is closed. It is a list of project-specific actions, each one an `id` plus a `do`
  instruction written in the project's own terms (a feedback rail to stamp, an external record to
  update). **Perform every declared action, in listed order, for each issue this PR closed**, then
  note on the issue thread that the hook fired, so the log shows it. Two rules:
  - **`hooks` absent, or `close_out` empty, means there is nothing extra to do here: skip it
    silently and never invent a hook.** No project hooks is the normal case in a repo with no such
    rail, and absence is a decision, not an oversight.
  - **A hook is a close-out action, not a gate.** It runs _after_ the merge has already landed, so a
    hook that fails is reported as a comment on the issue and the rest of close-out carries on.
    Never unwind the merge over one, and never stop to ask about one.
- **Surface the next ready sub-issue** in the epic (re-run the readiness check from step 1) so the
  sequence keeps moving.
- **Remove the worktree** once merged (offer it): `git -C <repo> worktree remove <worktree>`.
  (**Epic mode:** do NOT remove per sub-issue — the shared epic worktree is removed once, when the
  whole epic is done.)

### Rework loop (in-review ↔ in-progress)

The PR rarely lands first time — the card **ping-pongs** while the dev/test cycle goes round. If the
PR gets change requests, or the person moves the card back to **in-progress**, that's the signal to
pick it up again:

- **On resume** (you start reworking): `<board-cmd> <NN> in-progress`.
- **On re-push** (fixes are up, PR refreshed): `<board-cmd> <NN> in-review`.

Keep iterating — in-progress → fix → re-push → in-review → review → … — until it's **merged**. The
issue thread stays the live log throughout: comment each rework chunk and gate re-run, same as the
first pass. `board.command` is idempotent, so re-setting a status the card already holds is a clean
no-op; and a board write that fails is logged, never a blocker.

### Batch mode (sequential, shared worktree)

This is the per-issue branch discipline that **Epic mode** (top of file) loops automatically — and it
also runs on demand when the person says **"work the next 3–4"** / pulls a batch of ready issues to do
back-to-back. Run them **sequentially in ONE shared worktree** — but each issue still gets its own
branch, PR, and card. (Epic mode adds the auto-merge-and-continue around this; manual batch mode
stops each at in-review unless told to merge.) **Per issue**, inside the shared worktree:

```bash
git fetch origin
git checkout -B <type>/<NN>-<slug> origin/<main>   # branch off FRESH default branch, every time
```

Then: set **in-progress**, implement, green the gate, open a **per-issue** PR (`Closes #<NN>`), set
**in-review**, and only then move to the next issue.

**Hard rules — bake these in:**

- **One branch + one PR + one card per issue.** Never a batched PR that closes several issues.
- **Branch each issue off fresh `<main>`** (`git checkout -B … origin/<main>`) — _never_ off the
  previous issue's branch, **unless** there's a genuine dependency stack (below).
- **Path-explicit `git add <path …>`** — never `git add -A` — so one issue's changes can't bleed into
  the next.
- **`git status` clean** before starting each issue; a dirty tree means the prior issue wasn't fully
  committed/PR'd — resolve it first.

Independent issues are **parallel-safe** but we run them sequentially here. The **one** exception to
"branch off fresh default branch" is a **strict dependency chain** (e.g. `#32 → #33 → #34 → #35`):
there it's legitimate to **stack** each PR onto the previous issue's branch so the unmerged
prerequisite code is present — same readiness logic as step 1.

## Notes

- **The issue thread is the status — keep it current at every step.** Kickoff, each dev chunk,
  migration, the gate (pass _and_ fail), the PR all post a comment. If someone reads the issue and
  can't tell what's been done, the skill was run wrong. Don't batch it all into one end-of-run dump.
- **One issue → one branch → one worktree → one PR.** Don't mix two issues in a branch; if the work
  splits, it was two issues — go back to `/epic`.
- **An epic _number_ triggers Epic mode (top of file), not a build of the container** — the loop works
  the epic's sub-issues one by one on a shared worktree, each sub-PR auto-merging into `<epic-branch>`
  as it goes; the epic container itself is still never implemented directly. The epic + every sub close
  together the moment the single `<epic-branch>→<main>` PR merges (its per-number
  `Closes #<sub>, …, Closes #<N>` line — the keyword repeats per number). **That merge is not the last
  step** — it triggers the post-merge convergence audit (Epic-mode step 7), which re-verifies the
  assembled result on `origin/<main>` against the epic's and every closed sub's acceptance criteria and
  files each confirmed gap as a NEW issue.
- **Don't build on an unmet dependency.** The readiness gate exists because a sub-issue's
  `Depends on #NNN` names code that must merge first; starting early means rebasing onto churn.
- **The default branch is sacred** — never commit to `<main>` directly; everything goes through a
  worktree branch + PR. (Where server-side branch protection isn't available, this is convention + the
  pre-commit gate hook — hold the line.)
- **Bash discipline for anything you script here:** these snippets run under `set -euo pipefail` on
  bash 3.2. Guard a command substitution whose pipeline can legitimately exit non-zero
  (`x="$(… | grep … || true)"`), capture an expected non-zero status rather than letting `set -e` eat
  it (`out="$(cmd)" || status=$?`), and expand a possibly-empty array as `${arr[@]+"${arr[@]}"}` — see
  the `bash-pipefail-safety` skill. **Those three clauses are the whole rule**, so if that skill is
  not vendored here, apply them inline and carry on rather than stopping.
