# Declared revert-pins

Scaffolded by `setup.sh --bootstrap` on {{TODAY}}.

A **revert-pin** proves a bug fix is actually held: it declares a reversion of the fix plus the one
test that must go red when the reversion is applied. Without it a fix is unheld — re-introducing the
original defect leaves the suite green, and the next rebase silently restores the bug.

The vendored `create-issue` skill demands the criterion; the vendored `regression-proof-red-green`
skill is how a builder demonstrates the red. This directory is where a pin is **declared** so the
demonstration can be replayed mechanically instead of asserted in a PR body.

## Format

One file per pin, `<issue>-<slug>.toml`:

```toml
id     = "1464-router-honours-epic-park"
issue  = 1464
test   = "path/to/test_file.py::test_the_named_test"

[[edit]]
file = "path/to/source.py"
find = '''        if candidate is not None and predicate(candidate):
            continue
'''
replace = ''
```

- **`find` must match the target file byte-for-byte**, indentation included. One space out is a
  could-not-run, not a near miss.
- **Default accept is `AssertionError`.** Any other red must be declared with `expect = "..."`.
- **`ImportError`, `AttributeError`, `NameError`, `TypeError`, `SyntaxError` and collection errors
  can never be declared** — a red from a missing symbol proves nothing about behaviour.
- **Pin each severable arm separately.** If two branches produce the same answer, deleting one
  leaves the test green; assert through the value the reverted branch _uniquely_ controls.

## What a replayed pin does and does not prove

It proves **the declared pin bites** — never that the fix is pinned. It is structurally blind to a
seam nobody declared, and it detects **accident, not intent**: the reversion, the test, and the
accept type are all authored by the same branch. The honest phrasing in a PR body is _"pin replayed:
the declared reversion made the declared test red on `<ExcType>`"_ — never _"pin verified"_.

## Wiring it into the gate

Nothing here runs on its own. To enforce pins, add a leg to `.claude/scripts/gate.sh` that applies
each declared reversion in an isolated tree, runs **only** the named test, and requires a
behavioural red — with a **cannot-verify exits 2** rule, so a rotted anchor or a timeout is a
could-not-run rather than a silent pass.
