# Engineering pack (portable, vendored)

The **engineering pack**: five skills and three reviewer agents that take a piece of work from "an
idea someone described" to "a merged PR behind a green gate", in _any_ repo, with **zero repo
specifics baked into them**.

Everything a repo owns (its slug, its labels, its branch prefixes, its gate command, its worktree
paths, its reviewers) lives in one file in the consumer repo: `.claude/PROJECT.md`, **the project
manifest**. The skills read the manifest; the manifest is the only thing that changes per repo.

These files are **copied** into a consumer repo, never symlinked and never submoduled. That is
deliberate: the target environment is a box that runs `git clone` + `git reset --hard` + `claude -p`,
with no `~/.claude`, no submodule fetch and no plugin host. A copy in the repo is the only thing that
survives that.

```
skills/engineering/
  README.md              this file
  implement-issue/SKILL.md   issue (or a whole epic) -> worktree -> gate -> reviewers -> PR
  epic/SKILL.md              author or extend an epic as ordered sub-issues
  triage/SKILL.md            raw phone captures -> implementable issues
  kickoff/SKILL.md           capability audit before substantial new work (interactive go-gate)
  quality-gate/SKILL.md      run the project's canonical gate, read the exit code honestly
  agents/
    correctness-reviewer.md  is the diff CORRECT, not merely green (red-green oracle proof)
    security-reviewer.md     is the diff SECURE (authz/IDOR, injection, secrets, supply chain)
    goal-checker.md          were the issue's Acceptance Criteria ACTUALLY implemented
```

Four **dependency skills** ride along from `skills/global/` (see "What rides along" below); they live
there rather than in the pack because they are ordinary stack-independent skills that `--global` also
installs into `~/.claude/skills/` for interactive work.

## Set up a new repo

`--vendor` (below) copies the pack in. It does **not** set a repo up: afterwards someone still has to
write `.claude/PROJECT.md`, add the `@.claude/PROJECT.md` import to the root `CLAUDE.md`, and create
`.claude/scripts/gate.sh`. `--bootstrap` does those three, then hands off to `--vendor`. Run it from
inside the repo you want set up:

```bash
git clone https://github.com/michaelkeevildown/claude-agents-skills ~/.claude-agents-skills 2>/dev/null || git -C ~/.claude-agents-skills pull --ff-only
~/.claude-agents-skills/setup.sh --bootstrap .
```

Both lines work whether or not the clone already exists: `clone` fails harmlessly when the directory
is there, and the `pull --ff-only` brings it up to date instead. The target defaults to `.`, so an
explicit path is only needed when running from elsewhere. `--dry-run` prints everything it would do
and writes nothing; `--force` proceeds over uncommitted changes under `.claude/`.

What it does, in order:

1. **Refuses safely.** A missing directory or a non-repo is an error with a non-zero exit and a note
   saying what to do instead. It also runs `--vendor`'s uncommitted-`.claude/` guard **before** it
   writes anything, so it cannot eat an in-progress edit.
2. **Detects the repo's facts, with the evidence for each**, so a wrong guess is visible rather than
   silent: `repo.slug` and `tracker` from `git remote get-url origin` (both the `git@host:owner/repo`
   and `https://host/owner/repo` spellings), `repo.default_branch` from
   `git symbolic-ref refs/remotes/origin/HEAD` and falling back to main/master then to the current
   branch, `ui.enabled` **only** on real evidence of a web UI (a `web/` directory, a vite/next config,
   an `index.html`) and `false` otherwise, and `gate.command` in this documented precedence:

   | #   | Evidence                                                                                                       | Delegate                                                                                                            |
   | --- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
   | 1   | `.claude/scripts/gate.sh` already exists                                                                       | left alone; it already owns the delegate                                                                            |
   | 2a  | **a workflow CI definition** (`.github/workflows/*.yml`, `.gitlab-ci.yml`, `.circleci/config.yml`)             | the **union of every required job's** `run:`/`script:` commands, de-duplicated, in workflow order, joined with `&&` |
   | 2b  | **a host-build declaration** (`netlify.toml` `[build] command`, `vercel.json` `buildCommand`)                  | that build command; a `vercel.json` with no `buildCommand` means the framework default, i.e. `npm run build`        |
   | 3   | `scripts/verify.sh`                                                                                            | `bash scripts/verify.sh`                                                                                            |
   | 4   | `package.json` script, in order `verify` > `check` > `ci` > `test:ci` > `test:coverage` > `test:unit` > `test` | `npm run <it>`, else composed from lint + the best test script                                                      |
   | 5   | `Makefile` `check`, else `test` target                                                                         | `make check` / `make test`                                                                                          |
   | 6   | `Cargo.toml`                                                                                                   | `cargo fmt --check && clippy && test`                                                                               |
   | 7   | `pyproject.toml`                                                                                               | ruff (when mentioned) + pytest, under uv/poetry when a lockfile says so                                             |
   | 8   | `pubspec.yaml`                                                                                                 | `dart analyze` + `flutter test` / `dart test`                                                                       |
   | 9   | a verify-ish command in `.claude/settings.json`                                                                | that command                                                                                                        |

   **Rule 2 outranks everything below it because it is not a guess.** A CI workflow, and equally a
   `netlify.toml` or `vercel.json`, is the repo writing down what it means by green; rules 4-8 read
   what the repo is BUILT with, never what it is CHECKED with, and that gap is how a heuristic ships
   a false green. Files rank above the settings hook because a file **is** the gate whereas a hook
   merely mentions one. **Nothing matched means no command is invented.**

   **Rule 2a is a union, never a pick.** A workflow with a `verify` job and a `migrations` job has
   TWO required checks, and a shim replaying only the first certifies exactly the tree the second
   exists to reject. So every job goes in that (a) belongs to a workflow which runs on `push` or
   `pull_request` -- a `workflow_dispatch`/`schedule`-only workflow is a button or a cron, not a
   green-tree check, and the whole file is passed over -- and (b) is not named as a ship/report step
   (`deploy`, `release`, `publish`, `notify`, `codeql`, ... are **dropped**, and named as dropped).

   The reader is a targeted line scan (bash 3.2, no `yq`) handling single-line and `run: |` block
   steps, and it never discards a job in silence:
   - **Unreadable job -> a loud TODO naming it and why.** A `${{ }}` expression, a heredoc, shell
     control flow, a `working-directory:` step or more than fifteen commands means "cannot read this
     confidently". The jobs that _were_ read still form the gate, and the ones that were not are
     reported in the evidence line, in the bootstrap summary, in the shim header **and** in
     `PROJECT.md`. You are never told "the repo's own CI is its own answer" when half of it went
     unread.
   - **Standalone script rescue.** Before giving up on such a job, any command that is purely an
     invocation of a repo-local `.sh` (no shell syntax around it, and the file must really exist) is
     salvaged into the gate. That is how TrueBalance's `migrations` job -- set up by a heredoc against
     a postgres service -- still contributes `./scripts/check-schema-sync.sh`, the check its own header
     documents as standalone-runnable with no database.
   - **Jobs that need infrastructure are read, not faked.** A `services:` block, or a command needing
     a live database or a compose stack (`supabase`, `psql`, `alembic`, `prisma`, `docker compose up`,
     ...), is recorded as a **prerequisite** rather than put in the gate; the job's ordinary commands
     still go in. The prerequisite list is written into `PROJECT.md` under `gate.prereq` so a red leg
     caused by a service that was never started is recognisable as a could-not-run in disguise.

   Whatever rule fires, the candidate then passes four post-checks before it is allowed out:
   - **Watch-mode guard.** A gate that never exits is a hang, not a gate. `--watch`, `--watchAll`
     (without `=false`), `nodemon`, bare `vitest`, bare `vite`, `next dev`, `npm start`, `cargo
watch` and a bare `jest` whose config sets `watch: true` are all refused. `vite build` and
     `vite optimize` are not watch mode and are allowed. A watch-mode `package.json` script is passed
     over at selection time so the non-watch sibling (`test:ci`) wins; a bare `vitest` in the
     delegate itself is rewritten to `vitest run`; anything else **downgrades to a TODO**.
   - **Completeness check.** The delegate is resolved (package scripts expanded recursively,
     repo-local `.sh` bodies and Makefile recipes read) and compared against the checks the repo
     evidently has.
     - **A `tsconfig.json` means the gate MUST compile** -- `tsc`/`vue-tsc`/`svelte-check`/
       `astro check`/a `typecheck` or `check` script/`next build`; `vite build` and `tsup` strip types
       rather than check them and deliberately do not count.
     - **A build artefact means the gate MUST build.** A `build` script _plus_ a framework config
       (astro/next/nuxt/vite/sveltekit/remix/gatsby/angular/rollup/webpack) is a repo whose output has
       to build, so `npm run build` is composed on when the delegate never builds. A gate that
       type-checks but never builds is not a gate for a site that has to build: `astro check` returns
       0 on a tree whose build has been broken for weeks.
     - A missing compile, build, test or lint leg is composed on from a script that provides it (or
       `npx --no-install tsc --noEmit` when TypeScript is a declared dependency), and when a compile
       or test leg cannot be composed safely the **whole candidate is thrown away** and the gate
       becomes a TODO with a loud warning naming exactly what was missing. A missing linter warns
       rather than blocks.
   - **Exit-2 warning.** A repo-local delegate script carrying a bare `exit 2` collides with this
     contract's COULD NOT RUN code, so **that delegate reports RED as COULD NOT RUN**. The code is
     deliberately not remapped (that direction is safe -- a failure is never read as green); the
     collision is printed in the bootstrap summary and written as a line under the `### gate` section
     of the generated `PROJECT.md`.
   - **tsc exit-2 normalisation.** `tsc --noEmit` exits **2** (`DiagnosticsPresent_OutputsGenerated`)
     on a COLD run of a project with `"incremental": true`, because writing the `.tsbuildinfo` counts
     as generating output, and **1** once that cache is warm. `*.tsbuildinfo` is gitignored, so cold
     is the default state of every fresh clone, worktree and CI runner. Both codes mean diagnostics
     were present -- RED -- but 2 is this contract's COULD NOT RUN code, so an ordinary type error
     would report "nothing was proved" exactly where builds happen. Any leg bootstrap **resolved to
     tsc itself** (a composed `npx --no-install tsc --noEmit`, or a selected script whose value is
     exactly `tsc --noEmit`) is therefore wrapped in a `gate_tsc` helper in the generated shim that
     folds 2 onto 1. **Only those legs.** A third-party delegate's 2 is never remapped: for
     `scripts/verify.sh` a 2 may genuinely mean could-not-run, which is what the exit-2 warning above
     is for.

   Every warning, every skipped CI job and any refusal is printed in the bootstrap summary **and**
   written into `PROJECT.md`, so they survive the session that ran the bootstrap.

3. **Scaffolds `.claude/PROJECT.md`** with the detected values as **Markdown tables in the body**
   (never frontmatter, see "The manifest contract"), plus the degrade rules and the reviewers table.
   Anything undetected is written as a **TODO** and repeated in a TODO section at the top of the file.
4. **Injects `@.claude/PROJECT.md`** near the top of the root `CLAUDE.md`, creating a minimal one if
   there is none, with a sentence saying what it is and why the bindings live in the body.
5. **Scaffolds `.claude/scripts/gate.sh`** (chmod +x) delegating to the detected command and honouring
   the exit contract below. When no gate was detected the scaffold **exits 2 (could-not-run) and never
   0** -- a stub that returned green is the worst possible failure here, so the unfilled state is
   could-not-run by construction.
6. **Vendors the pack** through the same `--vendor` path, which is why the reviewer agents the fresh
   manifest declares are installed on the first run.
7. **Prints a numbered summary**: what it detected and from what evidence, what it created versus
   skipped, and the remaining manual steps -- fill in every TODO, and **restart Claude Code**, because
   the agent registry loads at boot and a newly vendored reviewer is not spawnable until it does.

Every step is idempotent. An existing `PROJECT.md`, `gate.sh` or `CLAUDE.md` import is left **exactly**
as it is and reported as skipped: bootstrap never edits a file it did not write, and never deletes
anything.

## Install

Into a repo that is already set up (or one you intend to set up by hand), from the shared repo:

```bash
./setup.sh --vendor /path/to/your-repo            # copy the pack in, write the lock
./setup.sh --vendor /path/to/your-repo --dry-run  # show what would change, write nothing
```

It refuses to run if the target is not a git repository, and refuses if the target has **uncommitted
changes under `.claude/`** (including untracked files) unless you pass `--force`, so a re-vendor
cannot silently eat someone's in-progress edit. A first vendor into a repo with no `.claude/` yet is
clean and needs no flag; a first vendor into a repo that already has an _untracked_ `.claude/` needs
a commit or `--force`.

Skills land in `<target>/.claude/skills/<name>/SKILL.md`, agents in
`<target>/.claude/agents/<name>.md`, and a `<target>/.claude/skills/.vendored.lock` records a sha256
per copied file plus provenance. Then write `<target>/.claude/PROJECT.md` (see below) and import it
from the root `CLAUDE.md` with a literal line:

```
@.claude/PROJECT.md
```

That import puts the manifest's **prose body** in context on **every** session, including a headless
`claude -p` where nothing prompts anyone to go and read a file. The body, and only the body: an `@`
import **strips YAML frontmatter**, so a binding written as frontmatter never reaches a headless run.
That is why the bindings are a Markdown table in the body (see "The manifest contract").

## What rides along

### The four dependency skills

The pack's skills **cite other skills by name**: `/epic` and `/triage` load `create-issue`, and
`/implement-issue` cites `git-workflow`, `bash-pipefail-safety` and `regression-proof-red-green` (the
correctness reviewer cites the last one too). On the target box there is no `~/.claude`, so a cited
skill that was not vendored simply does not resolve, and the citing skill hard-stops at its own gate.

The rule is therefore: **a vendored skill may only depend on something that is also vendored.**
`--vendor` enforces it by copying these four in alongside the pack, under the names the pack cites
them by:

| Vendored as                  | Source                                      | Cited by                                                                        |
| ---------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------- |
| `create-issue`               | `skills/global/issue-authoring/`            | `/epic`, `/triage`, and `/implement-issue` when it files an out-of-scope defect |
| `git-workflow`               | `skills/global/git-workflow/`               | `/implement-issue` (branch naming, staged-diff commit discipline)               |
| `bash-pipefail-safety`       | `skills/global/bash-pipefail-safety/`       | `/implement-issue` when the diff touches shell                                  |
| `regression-proof-red-green` | `skills/global/regression-proof-red-green/` | `/implement-issue` and `correctness-reviewer` (the red-green oracle proof)      |

The install name is what the consumer's directory is called and it must match the skill's own
frontmatter `name:` - which is why `issue-authoring/` lands as `create-issue/`. Every file under each
source directory is copied, so a dependency that later grows a `references/` directory needs no change
to `setup.sh`. All four are recorded in `.vendored.lock` exactly like the pack's own files, so the
drift check covers them and an override can be declared against them.

If a dependency is missing from the shared repo, `--vendor` **fails with exit 2 and writes nothing**
rather than shipping a pack whose skills hard-stop on the box.

### The reviewer agents, only when the manifest names them

Agents are vendored **conditionally**. `--vendor` reads the target's `.claude/PROJECT.md`, finds the
reviewers declaration, and installs **only** the agents it names. Nothing named means nothing
installed.

That is the deliberate choice, over "install them all and warn": a file in `.claude/agents/` _is_ a
spawnable agent, and a reader who sees `security-reviewer.md` sitting there reasonably concludes the
repo has a security review gate. It does not; the skills only spawn a reviewer the manifest lists. So
the repo contents match the wiring, and the missing agents are reported loudly at vendor time:

```
    reviewers: no .claude/PROJECT.md in the target - no agent will be installed.
    NOT installed (no manifest entry references it): correctness-reviewer
    NOT installed (no manifest entry references it): goal-checker
    NOT installed (no manifest entry references it): security-reviewer
    To install one, add it to the reviewers table in .claude/PROJECT.md and re-vendor.
```

Parsing details worth knowing:

- The reviewers list is read from the **Markdown table in the manifest body** - the `## Bindings`
  table, or a reviewers table of its own. YAML frontmatter is **not** read: an `@` import carries the
  prose body only, so a binding kept in frontmatter never reaches a headless run's context.
- The scan is shape-tolerant (it collects table rows from any heading mentioning "reviewer", plus any
  `## Bindings` row whose key starts with `reviewers`, then asks whether an agent's name appears).
  Anything it cannot find is treated as **not declared**, so a manifest it cannot parse installs no
  agent rather than a wrong one.
- An agent already present in the target that the manifest no longer names is **left on disk**
  (vendoring never deletes) but drops out of the lock, and the run says both things.

## The manifest contract

`.claude/PROJECT.md` is a Markdown file whose **`## Bindings` table in the prose body is the
contract**. Each row is one binding: a dotted key name in the first cell, its value in the second.
The dotted names below are the interface, and the table is the only place a value lives.

**There is no YAML frontmatter, and no frontmatter mirror of the table.** This is a load-bearing
constraint, not a style choice: the root `CLAUDE.md`'s `@.claude/PROJECT.md` import carries the prose
body **only**, and strips frontmatter before it ever reaches context. A binding kept in frontmatter is
therefore invisible to exactly the run that cannot go and read the file for itself, the headless one.
A mirror would just be a second copy free to drift from the first. One table, one source of truth.

`--vendor` reads the same table when it decides which reviewer agents to install, so a manifest that
keeps its reviewers in frontmatter installs **no agents at all** (see "The reviewer agents, only when
the manifest names them").

The rest of the body is orientation for humans, plus any _project guards_ (things a skill must not do
in this repo). Nothing parses that prose.

| Key                                                    | Required                       | Default when absent                         | Degrade behaviour when absent                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------------------------------------------ | ------------------------------ | ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `manifest_version`                                     | yes                            | none                                        | Currently always `1`. A skill that meets an unknown version should say so rather than guess.                                                                                                                                                                                                                                                                                                                                       |
| `repo.slug`                                            | no                             | inferred by `gh` from the working directory | Skills never pass `--repo`; the slug is only for the rare command run from outside a checkout, and for `gh search issues --repo`.                                                                                                                                                                                                                                                                                                  |
| `repo.default_branch`                                  | yes                            | none                                        | The canonical branch every freshness check compares against (`origin/<default_branch>`). Without it a skill cannot tell a stale checkout from current state, so treat it as required.                                                                                                                                                                                                                                              |
| `repo.visibility`                                      | no                             | assume `private`                            | Only used to explain why an unauthenticated fetch of an attachment returns 404. Assuming private is the safe direction.                                                                                                                                                                                                                                                                                                            |
| `tracker`                                              | yes                            | none                                        | `github` today. **`tracker: none`** means there is no issue to close: drop the `Closes #NN` keyword from the PR body rather than inventing an issue number, and post the progress log wherever the project keeps it.                                                                                                                                                                                                               |
| `labels.ready`                                         | yes (with a tracker)           | none                                        | The single pickup label. An autonomous build loop filters strictly on it: present = takeable, absent = held back.                                                                                                                                                                                                                                                                                                                  |
| `labels.human_gate`                                    | no                             | no PR is human-gated                        | Nothing is held for a human to merge. Say so rather than assuming a gate exists.                                                                                                                                                                                                                                                                                                                                                   |
| `labels.triage`                                        | only for `/triage`             | none                                        | `/triage` has no queue to read and does nothing.                                                                                                                                                                                                                                                                                                                                                                                   |
| `labels.epic`                                          | only for `/epic` and epic mode | none                                        | An epic cannot be detected by label; fall back to "does the issue have sub-issues".                                                                                                                                                                                                                                                                                                                                                |
| `labels.bug`, `labels.enhancement`                     | yes (with a tracker)           | none                                        | The type labels that also pick the branch prefix.                                                                                                                                                                                                                                                                                                                                                                                  |
| `labels.priority_order`                                | no                             | no priority ordering                        | Pick order falls back to lowest issue number first.                                                                                                                                                                                                                                                                                                                                                                                |
| `labels.ultra`                                         | no                             | never escalate build depth                  | Every build runs at normal depth.                                                                                                                                                                                                                                                                                                                                                                                                  |
| `labels.owner_task` / `labels.deferred`                | no                             | neither disposition is available            | **Declared degrade: no `owner-task` disposition** — file the manual deliverable `host-resident` or `parked` instead, and never imply a gate the project has no label for — **and no auto-unarm** for a `deferred`-shaped sub — park a blocked one by removing `labels.ready` by hand. |
| `board` (`number`, `command`, `statuses`)              | no                             | no board                                    | **Declared degrade: skip every board-sync call.** The card state is a convenience, never a gate, and a board write failure must never block a build.                                                                                                                                                                                                                                                                               |
| `branch.bug_prefix` / `feature_prefix` / `epic_prefix` | yes                            | none                                        | Branch naming is not guessable; a skill that invents a prefix produces branches no one can find.                                                                                                                                                                                                                                                                                                                                   |
| `branch.slug_max_len`                                  | no                             | 50                                          | Longer slugs are merely ugly, so a default is safe here.                                                                                                                                                                                                                                                                                                                                                                           |
| `worktree.path_template` / `epic_path_template`        | yes                            | none                                        | Where the dedicated worktree is created. `<slug>` / `<N>` are substituted.                                                                                                                                                                                                                                                                                                                                                         |
| `gate.command`                                         | **yes, fatal if absent**       | none                                        | **Declared degrade: fatal.** A skill that cannot prove the tree is green **must not open a PR**. See the headless-legal terminal action below.                                                                                                                                                                                                                                                                                     |
| `gate.prereq`                                          | no                             | nothing to satisfy                          | Run the gate directly. If the gate then reports "could not run" (exit 2), that is unsatisfied, not a pass.                                                                                                                                                                                                                                                                                                                         |
| `checklist.path` / `checklist.section`                 | no                             | `/create-issue`'s Self-Check Before Filing  | **Declared degrade: run the requirement-quality pass on `/create-issue`'s Self-Check only, and say so in the posted comment** (`CHECKLIST: none bound - create-issue self-check only`). Never skip the pass; never present a floor-only pass as a full one. Bound but unreadable, or the named section missing from the file, is **could not run, not a pass**: file nothing, relabel nothing, comment the blocker, exit non-zero. |
| `ui.enabled`                                           | no                             | `false`                                     | **Declared degrade: skip the UI gate entirely and say in the PR body that no UI gate ran.** Never substitute a screenshot-free guess at design conformance.                                                                                                                                                                                                                                                                        |
| `ui.paths`                                             | only when `ui.enabled`         | none                                        | Nothing counts as a UI diff, so the UI gate never fires.                                                                                                                                                                                                                                                                                                                                                                           |
| `ui.command`                                           | only when `ui.enabled`         | none                                        | Same as `ui.enabled: false`: skip, and say the skip out loud.                                                                                                                                                                                                                                                                                                                                                                      |
| `reviewers[]` (`agent`, `when`)                        | no                             | no reviewer runs                            | **Declared degrade: that reviewer is not spawned AND the PR body must say so.** Never claim a review ran that did not.                                                                                                                                                                                                                                                                                                             |
| `hooks.close_out[]` (`id`, `do`)                       | no                             | nothing extra at close-out                  | **Declared degrade: skip silently.** Never invent a hook.                                                                                                                                                                                                                                                                                                                                                                          |

Two more things the skills look for that are _not_ rows in the bindings table:

- **`.claude/REVIEW-ANCHORS.md`** (project-local, **never vendored**): the repo's own hard lines, which
  sharpen the reviewer agents. Absent, the reviewers still run on their **universal lenses only**: say
  so in the task prompt, have each reviewer record `ANCHORS: none - universal lenses only` in its
  verdict, and repeat that narrowing in the PR body. A narrowed review must never read as a full one.
- **Project guards** in the manifest prose: rules a skill must obey _in this repo_ (for example "never
  restructure the product domain for an engineering reason"). They live in the consumer repo
  precisely so a repo without that domain vendors the same skills and carries none of it.

### Never "stop and ask the human"

The pack targets unattended runs. On the box there is no human in the loop, and the driver's resume
directive actively overrides an early stop, so **"stop and ask" is never a legal degrade on a failure
path**. The headless-legal terminal action is:

> **do not open (or merge) the PR, post the blocker as a comment on the issue, and exit non-zero.**

An **interactive gate that is the whole point of the skill** is a different thing and is preserved:
`/kickoff` proposes a plan and waits for go, and the final epic PR is deliberately human-gated. Those
are designed stops, not failure paths.

## The two script contracts

The manifest points at two shims in the consumer repo. They exist so a vendored skill can say "run
the gate" in any repo without knowing what the gate actually is. Keep them shims: no logic.

### `gate.sh` (required, `gate.command`)

Delegates to whatever the repo's real gate is, passes arguments straight through, preserves the exit
code, and carves out one code:

| Exit  | Meaning                                                                                                         | Caller's response                                                                                                                          |
| ----- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `0`   | GREEN. The gate ran in full and passed.                                                                         | Proceed.                                                                                                                                   |
| `2`   | COULD NOT RUN. Nothing was proved either way (delegate missing, Docker absent, environment short-circuited it). | **Unsatisfied.** Never a pass, and not an ordinary test failure, so "just fix the failing test" is the wrong response. Do not open the PR. |
| other | RED. The gate ran and failed.                                                                                   | Ordinary lint/test failure: fix the code.                                                                                                  |

Two rules keep the dangerous confusion (a could-not-run read as a pass) shut: every non-zero exit
stays non-zero, and a `0` is rejected up front when the environment is one that makes the delegate
exit 0 _without_ running the gate.

### `ui-gate.sh` (optional, `ui.command`, only when `ui.enabled: true`)

Same shim shape, plus a **stdout contract**:

- The **last line of stdout is the absolute screenshot directory**. That is the hand-off to a visual
  reviewer.
- Every human-readable line goes to **stderr**, so stdout stays clean.
- On any non-zero exit it writes **nothing** to stdout, so a caller reading stdout gets an empty
  string rather than a plausible-looking wrong path.

The caller idiom captures the status rather than inferring it from stdout:

```bash
status=0
SHOTS="$(bash .claude/scripts/ui-gate.sh | tail -n1)" || status=$?
# judge on $status, never on whether SHOTS looks like a path
```

Exit `2` means could-not-run / not available: **skip** the UI gate and say so. Skipping means
skipping; never substitute a guess, never report a skipped gate as a passed one, and never treat a
skip as a reason to stop and wait for a human.

## Minimal manifest

A small JavaScript repo: no UI gate, no board, no reviewers. This is a complete, working
`.claude/PROJECT.md`.

```markdown
# widget-cli - project manifest

The per-project facts the vendored engineering skills bind to. Root `CLAUDE.md` imports this file
with a literal `@.claude/PROJECT.md` line, so the table below is in context on every session,
headless runs included. Keep the bindings in this table: the import strips YAML frontmatter, so a
binding written up there would never arrive.

## Bindings

`manifest_version: 1`

### repo

| Key                   | Value             |
| --------------------- | ----------------- |
| `repo.slug`           | `acme/widget-cli` |
| `repo.default_branch` | `main`            |
| `repo.visibility`     | `private`         |
| `tracker`             | `github`          |

### labels

| Key                     | Value            |
| ----------------------- | ---------------- |
| `labels.ready`          | `ready-to-build` |
| `labels.human_gate`     | `human-merge`    |
| `labels.triage`         | `needs-triage`   |
| `labels.epic`           | `epic`           |
| `labels.bug`            | `bug`            |
| `labels.enhancement`    | `enhancement`    |
| `labels.priority_order` | `[P0, P1, P2]`   |

### branch

| Key                     | Value  |
| ----------------------- | ------ |
| `branch.bug_prefix`     | `fix`  |
| `branch.feature_prefix` | `feat` |
| `branch.epic_prefix`    | `epic` |
| `branch.slug_max_len`   | `50`   |

### worktree

| Key                           | Value                    |
| ----------------------------- | ------------------------ |
| `worktree.path_template`      | `../widget-cli-<slug>`   |
| `worktree.epic_path_template` | `../widget-cli-epic-<N>` |

### gate

| Key            | Value                          |
| -------------- | ------------------------------ |
| `gate.command` | `bash .claude/scripts/gate.sh` |

## Degrades this repo has chosen

No `ui` section, so the UI gate never runs. No `board`, so board sync is skipped. No `reviewers`
section, so no reviewer is spawned, every PR body must say plainly that no review ran, and
`--vendor` installs no agent files.
```

To add a reviewer later, add the section and re-vendor. The agents install because the table names
them:

```markdown
### reviewers

`reviewers` is a list. Each entry is one `agent` plus the `when` condition that selects it.

| #   | `agent`                | `when`   |
| --- | ---------------------- | -------- |
| 1   | `correctness-reviewer` | `src/`   |
| 2   | `security-reviewer`    | `always` |
```

And the gate shim it points at, `.claude/scripts/gate.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# gate.command - shim, no logic. Exit 2 = could not run.
command -v npm >/dev/null 2>&1 || exit 2
npm run --silent verify -- "$@"
```

## Operational gotchas

**1. A newly vendored reviewer needs a Claude Code restart.** The agent registry is read **at boot**.
Copying `correctness-reviewer.md` into `.claude/agents/` while a session is running does _not_ make it
spawnable: the session holds the registry it booted with, and `/clear` does not re-read it. Vendoring
into a fresh repo therefore needs **one restart before the first gated build**, or the reviewer legs
will fail to spawn and the PR will honestly report that no review ran.

**2. Never edit a vendored file in place.** A vendored file is a copy of an upstream file, so editing
the copy forks it silently: the next re-vendor overwrites the edit and the improvement never reaches
the other repos. The drift check reads `.claude/skills/.vendored.lock` at gate time and turns that
silent fork into a loud, deterministic failure. There are exactly two legitimate moves:

- **Change it upstream** in this shared repo, commit, then re-run `--vendor` in every consumer (see
  Propagation below). This is the default and the one that helps every repo.
- **Declare a deliberate divergence** by adding an override line to the lock:

  ```
  # override: .claude/skills/triage/SKILL.md this repo triages from Linear, not GitHub
  ```

  The overridden file keeps its checklist line (recording the upstream digest it forked from), the
  drift check skips it, and `--vendor` will **not** overwrite it on a later run. One consequence by
  design: a plain `shasum -a 256 -c` run reports a declared override as FAILED, because the recorded
  digest is deliberately stale. The drift checker is the authoritative check; plain `shasum -c` is
  only a rough eyeball.

The consumer repo owns the drift checker and wires it into its own gate. Contract: read
`.claude/skills/.vendored.lock`, exit `0` when every non-overridden listed file still hashes to its
recorded digest (and `0` when the lock is absent, since a repo that vendors nothing is legitimate),
exit `1` on drift naming each changed / missing / malformed path, exit `2` on a usage error or no
sha256 tool on PATH. It must never touch the network, so it has no fail-open path. The reference
implementation is the reference `tools/scripts/skills-drift.sh` shipped by the pack's origin repo.

## The lock file

`<target>/.claude/skills/.vendored.lock`, written by `--vendor`, is a `shasum -a 256 -c` checklist so
a human can read it and standard tooling can consume it:

```
<64 lowercase hex digest><two spaces><repo-relative path>
```

Paths are relative to the **consumer repo root**, not to the lock, and must not contain spaces.
Digests are lowercase hex exactly as `shasum -a 256` emits them. Blank lines and `#` comments are
ignored, which is how `# override:` declarations ride along. A commented provenance header records
`source_repo:`, `source_commit:` and `vendored_at:`, so any consumer can say exactly which upstream
commit its copies came from.

## Propagation

There is no live link between a consumer and this repo, by design (a copy is the only thing that
survives `git clone` + `reset --hard` on a box with no `~/.claude`). Propagation is therefore an
explicit step, and `consumers.txt` in the repo root is the list of who needs it (gitignored -- copy
`consumers.txt.example` to start one; the real list names private repos and local paths, so it stays
out of git):

1. **Edit upstream.** Change `skills/engineering/**` here, never in a consumer.
2. **Commit** in this repo. The commit SHA is what lands in each consumer's lock as `source_commit`,
   so an uncommitted change makes the provenance a lie (`--vendor` marks it `-dirty` if you try).
3. **Re-vendor each consumer** listed in `consumers.txt`:

   ```bash
   ./setup.sh --vendor /path/to/consumer --dry-run   # see the diff first
   ./setup.sh --vendor /path/to/consumer
   ```

4. **Commit in the consumer.** The lock changes with the files, so the drift check goes green again in
   the same commit that carries the new content.
5. **Restart Claude Code** in that consumer if any _agent_ changed (gotcha 1).

Add a row to `consumers.txt` the first time you vendor into a repo. A consumer that is not on the list
does not get fixes, which is exactly the failure mode the file exists to prevent.
