# Review anchors — {{REPO_NAME}}

Scaffolded by `setup.sh --bootstrap` on {{TODAY}}. **Never vendored.** This file is what gives the
vendored reviewers (`correctness-reviewer`, `security-reviewer`, `goal-checker`) teeth _in this
repo_: they know how to review in general, and this is where they learn what "wrong" means here.

An empty anchors file is not neutral — it makes every reviewer fall back to generic judgement, which
is exactly the review that passes a diff violating a rule nobody wrote down. Fill it in as you learn
the rules the hard way; each anchor should come from something that actually went wrong.

## How to write an anchor

An anchor is a **falsifiable** statement a reviewer can cite, not a preference:

> **Never trust an upstream 200 — read it back.** The API silently coerces values, so a write is
> only proved by diffing what was stored against what was sent. Cite `client.publish()` callers.

Bad anchors ("prefer clean code", "be careful with auth") cannot be violated, so they never produce
a finding.

## Hard lines

The rules a diff may never breach here. A clear breach in any of these is a FAIL, not a comment.

- **TODO** — add the first one. Until this section has content, `correctness-reviewer` and
  `security-reviewer` review on generic lenses only, and their PASS means less than it looks.

## Known traps

Places this codebase has bitten before. A reviewer should look here first when a diff touches them.

- **TODO** — e.g. "a test that asserts on a changed row count can pass on a no-op; assert positive
  evidence instead."

## Out of scope for review

Say what reviewers should NOT flag, so their findings stay signal.

- Generated files, vendored copies, and lockfiles — changes there are reviewed by regenerating, not
  by reading the diff.
