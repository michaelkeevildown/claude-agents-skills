---
name: regression-proof-red-green
description: Prove a regression test fails on pre-fix code and passes on the fix before claiming the fix lands, without using git stash.
when_to_use:
  - You have just written a test that pins a bug you also fixed in the same change.
  - A reviewer asks for evidence that a regression test "catches the class".
  - You need to verify a fix on a branch with a dirty stash list or one where `git stash` is contraindicated.
---

# Regression proof: RED on revert, GREEN on fix

## Why

A passing test on a fixed tree proves correctness but not coverage. The test might pass for an unrelated reason (a fixture matched the new code by accident; the assertion was too loose). The minimum bar before claiming a regression test catches the bug class:

- **RED on revert** — temporarily restore the pre-fix code; the test must fail.
- **GREEN on fix** — restore the fix; the test must pass.

## Recipe (no git stash)

Some repos forbid `git stash; X; git stash pop` because a pre-existing stash can leak into the pop. Use a working-tree-only swap instead:

```bash
# 1. Save the fix to a side file.
cp path/to/fixed.sh /tmp/fixed.sh.bak

# 2. Restore the pre-fix version from HEAD's parent (or whichever ref holds the bug).
git show HEAD~1:path/to/fixed.sh > path/to/fixed.sh
# Or, if the bug is in the as-yet-uncommitted baseline:
git checkout HEAD -- path/to/fixed.sh

# 3. Run the test. Expect non-zero.
bash scripts/test-fixed.sh; echo "RED exit=$?"

# 4. Restore the fix.
cp /tmp/fixed.sh.bak path/to/fixed.sh

# 5. Run the test. Expect zero.
bash scripts/test-fixed.sh; echo "GREEN exit=$?"

# 6. Clean up.
rm /tmp/fixed.sh.bak
```

If you must use `git stash` (e.g. the bug spans many files), first run `git stash list` and confirm it is empty. A repo-level "never stash here" rule reduces but does not eliminate the leak risk; the cp-and-restore recipe above is preferable.

## What to report

In the rework comment, paste the actual stdout of both runs, captioned `RED on revert` and `GREEN on fix`. Two lines of evidence settle the question.

## When to skip

- The regression is on a deterministic surface (a pure function, a parse) and the test exercises it via a direct call. RED-on-revert is then mechanical and the fix is small; a brief textual claim is acceptable.
- The reviewer has not asked for proof and the bug class is narrow.

Default: when in doubt, prove it.
