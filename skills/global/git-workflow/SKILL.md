---
name: git-workflow
description: Git workflow conventions — branching strategy, commit messages, PR workflow, and rebase vs merge.
---

# Git Workflow

## When to Use

Use this skill when working with git — branching, committing, creating PRs, resolving merge conflicts, and maintaining clean history. Covers conventional commits, branch naming, PR workflow, rebase vs merge, and safety rules.

This skill is designed for **AI-assisted ("vibe coding") workflows** where an LLM like Claude Code generates most of the code. The patterns here emphasize diff review discipline, selective staging, and atomic commits — critical when you are not typing every line yourself.

Stack-agnostic — applies to frontend, Python, Rust, and any other language.

**Safety rule:** Never run destructive git commands (`push --force`, `reset --hard`, `checkout .`, `restore .`, `clean -f`, `branch -D`) unless the user explicitly requests them. Always confirm before taking actions that are hard to reverse.

---

## Branch Strategy

### Branch Naming Convention

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feat/` | New feature | `feat/user-auth` |
| `fix/` | Bug fix | `fix/login-redirect` |
| `refactor/` | Code restructuring, no behavior change | `refactor/extract-utils` |
| `chore/` | Tooling, dependencies, config | `chore/upgrade-deps` |
| `docs/` | Documentation only | `docs/api-reference` |
| `test/` | Adding or fixing tests | `test/auth-edge-cases` |
| `spike/` | Exploration / throwaway (vibe coding sessions) | `spike/graph-layout-options` |

**Naming rules:**
- Lowercase, hyphens (not underscores or spaces), no slashes beyond the prefix
- Max ~50 characters
- Include ticket/issue ID when available: `feat/GH-42-user-auth`

```bash
# Create and switch to a feature branch
git checkout -b feat/user-auth

# Create from a specific base
git checkout -b fix/login-redirect origin/main
```

### When to Branch

- **Always branch from `main`** (or the designated trunk) for new work
- **One branch per logical change** — do not mix unrelated features
- **Branch-per-session for vibe coding** — when starting a new Claude Code session for exploratory work, create a fresh branch. This keeps `main` clean and gives you a safe sandbox. If the session goes sideways, discard the branch with no consequences.
- Use `spike/` prefix for throwaway exploration branches that you expect to discard

```bash
# Starting a vibe coding session
git checkout main && git pull
git checkout -b feat/GH-42-user-auth
```

### Keeping Branches Current

Rebase feature branches onto `main` before opening a PR. Do not let branches diverge for more than a day or two.

```bash
git fetch origin
git rebase origin/main
```

---

## Commit Messages

### Conventional Commits Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type Reference

| Type | When to use |
|------|-------------|
| `feat` | New feature visible to users |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or correcting tests |
| `docs` | Documentation only |
| `chore` | Build process, dependencies, tooling |
| `style` | Formatting, whitespace (no logic change) |
| `perf` | Performance improvement |
| `ci` | CI/CD configuration changes |

### Rules

- **Subject line:** imperative mood ("add", not "added" or "adds"), max 72 chars, no period at end, lowercase after type prefix
- **Scope:** optional, identifies the module or area affected (e.g., `auth`, `api`, `graph`). Use short, lowercase names matching project directories or domains. Be consistent — if you used `auth` before, keep using `auth`.
- **Body:** wrap at 72 chars, explain **why** not **what**, separated from subject by a blank line
- **Footer:** `BREAKING CHANGE:` prefix for breaking changes, issue references (`Closes #42`)

When a commit spans multiple scopes, either omit scope or use the primary affected area.

### Multi-Line Commit Messages

Use the HEREDOC pattern for multi-line messages in bash:

```bash
git commit -m "$(cat <<'EOF'
feat(auth): add OAuth2 login flow

Implement Google and GitHub OAuth2 providers using the passport library.
Includes token refresh logic and session persistence.

Closes #42
EOF
)"
```

**Always use the HEREDOC pattern** for multi-line commit messages. Never use multiple `-m` flags for the body.

---

## Commit Hygiene

This is the most critical section for AI-assisted development. AI-generated code can produce large diffs, and discipline around staging, reviewing, and splitting commits is what separates clean history from chaos.

### Atomic Commits

- Each commit represents **one logical change** that could be reverted independently
- A commit should leave the codebase in a working state (tests pass, builds succeed)
- If you cannot describe a commit in a single subject line without "and", it should be two commits

### Always Review Diffs Before Committing

**The single most important rule for vibe coding.** AI-generated code must be reviewed before it enters the repository. AI can introduce subtle issues: wrong imports, hardcoded values, missing error handling, security vulnerabilities.

```bash
# Review what will be committed
git diff --staged

# Review unstaged changes
git diff

# Review both staged and unstaged
git diff HEAD
```

Read every line of the diff. Use `git add -p` (interactive patch staging) to stage only the changes you have verified:

```bash
# Stage changes interactively, hunk by hunk
git add -p

# Stage specific files only
git add src/auth/login.ts src/auth/oauth.ts
```

### What NOT to Commit

- **Never commit secrets:** `.env`, API keys, credentials, tokens
- **Never commit generated artifacts** that belong in `.gitignore`: `node_modules/`, `__pycache__/`, `target/`, `.next/`, `dist/`
- **Never commit AI conversation logs** or prompt files unless intentionally part of the repo
- **Prefer `git add <specific files>`** over `git add .` or `git add -A` to avoid accidentally staging sensitive files

### Splitting Large AI-Generated Changes

When AI produces a large change (new feature with types, implementation, and tests), split it into logical commits:

```bash
# Stage types/interfaces first
git add src/types/auth.ts
git commit -m "feat(auth): add OAuth2 type definitions"

# Stage implementation
git add src/auth/oauth-provider.ts src/auth/token-manager.ts
git commit -m "feat(auth): implement OAuth2 provider and token management"

# Stage tests
git add tests/auth/oauth.test.ts
git commit -m "test(auth): add OAuth2 provider tests"
```

### Checkpoint Commits During Long Sessions

During extended AI coding sessions, create work-in-progress checkpoint commits to avoid losing work:

```bash
git add -A && git commit -m "wip: checkpoint — auth flow in progress"
```

- Checkpoint every 15-30 minutes of productive AI generation
- The `wip:` prefix signals these are not final commits
- Always checkpoint before switching context or trying a risky refactor
- These will be squashed or rebased before the PR is finalized

---

## PR Workflow

### Creating a PR

Use `gh pr create` with a structured description:

```bash
gh pr create --title "feat(auth): add OAuth2 login flow" --body "$(cat <<'EOF'
## Summary
- Add Google and GitHub OAuth2 providers
- Implement token refresh and session persistence
- Add comprehensive test coverage for auth flows

## Test plan
- [ ] Manual test: Google login flow end-to-end
- [ ] Manual test: GitHub login flow end-to-end
- [ ] Verify token refresh after expiry
- [ ] Run full test suite
EOF
)"
```

### PR Title

- Follow the same conventional commits format as commit messages
- Under 70 characters
- Use the description/body for details, not the title

### PR Description Structure

Every PR should include:

1. **Summary:** 1-3 bullet points describing what changed and why
2. **Test plan:** How to verify the changes work (bulleted checklist)
3. **Breaking changes:** Call out any breaking changes prominently
5. **Screenshots:** For UI changes, include before/after screenshots

### Draft PRs

Use draft PRs for work-in-progress that needs early feedback:

```bash
gh pr create --draft --title "wip: auth flow exploration"
```

Convert to ready-for-review when the implementation is complete. Draft PRs signal "not ready to merge" to teammates.

### PR Size

- Aim for PRs under **400 lines of diff**
- AI can easily generate 1000+ line changes — break these into smaller PRs
- If a feature is too large for one PR, use a feature branch and stack PRs against it
- Each PR should be independently reviewable and ideally deployable

---

## Rebase vs Merge

### Default: Rebase

Rebase is the default for keeping feature branches current with `main`:

```bash
# Update feature branch with latest main
git fetch origin
git rebase origin/main

# If conflicts arise, resolve them one commit at a time
# Edit conflicted files, then:
git add <resolved-files>
git rebase --continue
```

### When to Use Merge

Use merge commits **only** when:
- Merging a feature branch into `main` via PR (the platform handles this)
- Merging a long-lived branch where commit history tells a story
- You explicitly want a merge commit as a historical marker

```bash
# Merge with a merge commit (explicit)
git merge --no-ff feat/user-auth
```

### When to Squash

Use squash when the feature branch has messy intermediate commits — common in vibe coding sessions with WIP/checkpoint commits:

```bash
# Non-interactive squash (safe for AI — no editor required)
git reset --soft origin/main
git commit -m "$(cat <<'EOF'
feat(auth): add OAuth2 login flow

Implement Google and GitHub OAuth2 providers with token refresh
and session persistence.
EOF
)"
```

This collapses all commits on the branch into a single clean commit. Prefer this over `git rebase -i` which requires interactive editor input.

### Golden Rule

**Never rebase commits that have been pushed to a shared branch.** Rebase rewrites history. If others have pulled those commits, rebasing causes conflicts for everyone.

---

## Vibe Coding Patterns

Patterns specific to working with AI coding assistants.

### Branch-Per-Session Workflow

Start every new Claude Code session on a fresh branch:

```bash
git checkout main && git pull
git checkout -b feat/GH-42-user-auth
```

This keeps `main` clean and gives you a safe sandbox. If the session goes poorly, discard the branch.

### The Review-Stage-Commit Loop

The fundamental workflow for AI-assisted development:

```
1. AI generates code
2. Review the diff (git diff)
3. Stage verified changes (git add -p or git add <files>)
4. Commit with conventional message
5. Repeat
```

**Never let AI generate code and commit it in a single step without reviewing the diff.**

### Checkpoint Strategy

During a long vibe coding session:

```bash
# Every 15-30 minutes of productive AI generation
git add -A && git commit -m "wip: checkpoint — implemented token refresh"

# Before trying a risky approach
git add -A && git commit -m "wip: checkpoint — stable state before refactor"

# If the risky approach fails, roll back to the checkpoint
git reset --soft HEAD~1
```

### Handling Large AI-Generated Changes

When AI produces a large multi-file change:

1. **Do not `git add .`** — stage file by file after reviewing each
2. Group related files into logical commits (types, implementation, tests, docs)
3. If the change is too large, ask the AI to break it into steps

```bash
# Review what changed
git status
git diff --stat

# Stage and commit in logical groups
git add src/types/ && git commit -m "feat(auth): add type definitions"

git add src/auth/ && git commit -m "feat(auth): implement OAuth2 flow"

git add tests/ && git commit -m "test(auth): add OAuth2 tests"
```

### .gitignore for AI Artifacts

Ensure `.gitignore` includes entries for common AI-related artifacts:

```gitignore
# AI / LLM artifacts
.claude/
.cursor/
.aider*
.copilot/
*.prompt.md
```

---

## Protected Branches and Safety

### Protected Branch Rules

- **`main`/`master` is always protected.** Never commit directly to it. Always go through a PR.
- **Never force push to `main`/`master`.** If asked to force push to main, warn the user first.

### Destructive Commands

Never run these without explicit user request:

- `git push --force` (use `--force-with-lease` if you must)
- `git reset --hard`
- `git checkout .` / `git restore .`
- `git clean -f`
- `git branch -D`

### Safe Undo Operations

When you need to undo changes, prefer safe operations:

```bash
# Undo last commit but keep changes staged
git reset --soft HEAD~1

# Undo last commit and unstage changes (keeps files)
git reset HEAD~1

# Discard changes in a specific file (only affects one file)
git checkout -- path/to/file.ts

# Create a revert commit (adds new history, does not destroy old)
git revert HEAD
```

### Pre-Commit Hook Behavior

When a pre-commit hook fails:
- The commit did **not** happen
- Fix the issue flagged by the hook
- Re-stage the files (`git add`)
- Create a **new** commit — do not use `--amend`, which would modify the previous unrelated commit

```bash
# Hook failed — fix, re-stage, and commit fresh
git add src/fixed-file.ts
git commit -m "fix(lint): resolve formatting issues"
```

### Stashing Work

Use stash to temporarily shelve changes:

```bash
# Stash current work
git stash push -m "wip: auth flow changes"

# List stashes
git stash list

# Restore most recent stash
git stash pop
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Create feature branch | `git checkout -b feat/description` |
| Stage specific files | `git add path/to/file.ts` |
| Stage interactively | `git add -p` |
| Review staged changes | `git diff --staged` |
| Review all changes | `git diff HEAD` |
| Commit (single line) | `git commit -m "type(scope): subject"` |
| Commit (multi-line) | `git commit -m "$(cat <<'EOF' ... EOF)"` |
| Rebase onto main | `git fetch origin && git rebase origin/main` |
| Squash branch | `git reset --soft origin/main && git commit` |
| Undo last commit (keep changes) | `git reset --soft HEAD~1` |
| Revert a commit | `git revert HEAD` |
| Stash work | `git stash push -m "description"` |
| Pop stash | `git stash pop` |
| Create PR | `gh pr create --title "..." --body "..."` |
| Create draft PR | `gh pr create --draft --title "..."` |
| View PR status | `gh pr status` |
| Checkpoint commit | `git add -A && git commit -m "wip: checkpoint"` |

---

## Anti-Patterns

### 1. Committing Without Reviewing the Diff

```bash
# BAD — blindly commit everything AI generated
git add -A && git commit -m "feat: add auth"

# GOOD — review, then stage selectively
git diff
git add -p
git commit -m "feat(auth): add OAuth2 login flow"
```

### 2. Meaningless Commit Messages

```bash
# BAD
git commit -m "fix stuff"
git commit -m "update"
git commit -m "wip"
git commit -m "asdf"

# GOOD
git commit -m "fix(auth): prevent token refresh race condition"
git commit -m "refactor(api): extract validation middleware"
```

### 3. Mega-Commits

```bash
# BAD — one commit with types, implementation, tests, config, and docs
git add -A && git commit -m "feat: add entire auth system"

# GOOD — logical atomic commits
git add src/types/ && git commit -m "feat(auth): add type definitions"
git add src/auth/ && git commit -m "feat(auth): implement OAuth2 flow"
git add tests/ && git commit -m "test(auth): add OAuth2 tests"
```

### 4. Working Directly on Main

```bash
# BAD
git checkout main
# ... make changes ...
git commit -m "feat: new feature"
git push

# GOOD
git checkout -b feat/new-feature
# ... make changes ...
git commit -m "feat: new feature"
gh pr create
```

### 5. Force Pushing to Shared Branches

```bash
# BAD — rewrites history others may have pulled
git push --force origin main

# GOOD — only force push to your own feature branches, use --force-with-lease
git push --force-with-lease origin feat/my-feature
```

`--force-with-lease` refuses to push if the remote has commits you have not seen, preventing you from overwriting a colleague's work.

### 6. Amending After Hook Failure

```bash
# BAD — pre-commit hook failed, --amend modifies the PREVIOUS (unrelated) commit
git add . && git commit --amend

# GOOD — fix the issue, create a new commit
git add src/fixed-file.ts
git commit -m "style: fix linting errors"
```

### 7. Committing Secrets or Generated Files

```bash
# BAD — .env contains API keys, node_modules staged
git add -A
git commit -m "chore: initial setup"

# GOOD — stage specific files, verify .gitignore first
git add src/ package.json tsconfig.json
git commit -m "chore: initial project setup"
```

### 8. Using --no-verify to Skip Hooks

```bash
# BAD — bypasses all safety checks
git commit --no-verify -m "feat: rush this in"

# GOOD — fix the issue the hook caught, then commit normally
git commit -m "feat: properly linted and tested feature"
```
