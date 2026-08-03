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

## The red must be BEHAVIOURAL

A red is not automatically evidence. Check _why_ the test failed:

- **`AssertionError`** — the test evaluated the behaviour and the behaviour was wrong. This is the proof.
- **`ImportError` / `AttributeError` / `NameError` / `TypeError` / `SyntaxError` / a collection error** — the test never got as far as the behaviour. A reversion that deletes or renames a symbol reds this way and proves _nothing_; the test would fail identically if the code were merely misspelled.

So revert the fix's **logic**, not its **symbols**. If your reversion removes a `def`, a `class` or an `import`, it is testing the linker, not the fix.

Two traps worth knowing, both observed in the wild:

- **A masked arm.** If the function under test has several arms that produce the same answer, deleting one may leave the test green because another still returns it. Assert through the value the reverted arm **uniquely** controls, and pin each severable arm separately.
- **A swallowed structural error.** A broad `except Exception` can absorb an `AttributeError` from a renamed symbol, after which the test fails on its own assertion and _looks_ behavioural. Constrain the reversion's shape, don't just read the exception.

Some genuinely behavioural pins red on something other than `AssertionError` — a test that drives a real subsystem may red on that subsystem's own error type. That is legitimate, but it must be _declared_, not assumed.

## What to report

In the rework comment, paste the actual stdout of both runs, captioned `RED on revert` and `GREEN on fix`, **including the exception type of the red**. Two lines of evidence settle the question; the exception type is what makes them evidence rather than a claim.

## When to skip

Never skip the proof itself.

A brief textual claim used to be acceptable for small deterministic fixes. It is not. Four pins claimed in one session on that basis turned out to be worthless — one left 543 tests passing on revert, one passed with _and_ without the fix, one raised `TypeError` on both. Every one was written by an author who believed the claim when they made it. The belief is not the problem; the absence of a run is.

What may be scaled down is the _reporting_, never the _running_: on a narrow, deterministic fix, run the revert, confirm the red and its exception type, and report it in one line.

**If your project mechanises this, prefer the mechanism.** A declared pin that a gate re-runs beats a claim in a PR body, because the claim is checked exactly once by the person least able to be sceptical about it.

Default: when in doubt, prove it. When not in doubt, prove it anyway — that is the case that has failed.
