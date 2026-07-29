---
name: bash-pipefail-safety
description: Catch the set -euo pipefail + command substitution trap when editing or reviewing bash scripts on macOS /bin/bash 3.2.
when_to_use:
  - You are editing a bash script that begins with `set -euo pipefail` (or `set -eo pipefail`).
  - You are reviewing a bash script that uses command substitutions of the form `x="$(cmd1 | cmd2)"` where cmd1 or cmd2 can legitimately exit non-zero (lsof on no-match, grep on no-match, head/tail on empty input, awk on empty input).
  - The script must run on macOS where `/bin/bash` is 3.2.57.
---

# Bash pipefail safety

## The trap

Under `set -euo pipefail`, this idiom looks safe but is not:

```bash
pid="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -1)"
[ -n "$pid" ] || continue
```

If nothing is listening on `$port`, `lsof` exits 1. `pipefail` propagates that exit through the pipeline. `set -e` then aborts the entire script at the assignment, before the `[ -n "$pid" ] || continue` guard ever runs. The pattern repeats with `grep` on no-match, `awk` on empty input, and any `| head` that consumes a non-zero-exiting upstream.

Live reproducer (macOS `/bin/bash` 3.2.57):

```bash
/bin/bash -c 'set -euo pipefail; x="$(lsof -nP -iTCP:99999 -sTCP:LISTEN -t 2>/dev/null | head -1)"; echo "alive: [$x]"'
# exits 1, "alive" never printed.
```

## The fix

Wrap the whole substitution with `|| true` at the call site:

```bash
pid="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -1 || true)"
[ -n "$pid" ] || continue
```

Prefer per-call `|| true` over making the helper "always exit 0" via internal trickery. Per-call is local, visible, and does not surprise other callers.

## When NOT to apply

- Scripts that do not set `pipefail`. The trap is specifically the interaction of `set -e` + `pipefail` + a substitution whose pipeline can legitimately exit non-zero.
- Pipelines where a non-zero exit IS the failure signal you want (e.g. `set -euo pipefail; result="$(curl --fail "$url")"` should not be suppressed).

## Auditing an existing script

1. `grep -nE '"\$\((.*\|.*)\)"' <script>` to find command substitutions containing pipes.
2. For each, ask: can either side legitimately exit non-zero on an "expected empty" input? If yes, append `|| true` to the inner pipeline.
3. Add a one-line in-script comment above the helpers explaining the rule and the reproducer, so a future contributor does not undo the wrap.

## Regression pin it

Pair the fix with a tiny test (see `regression-proof-red-green` skill). For dev-stack-shaped scripts: a tempdir + the smallest invocation that hits the substitution + an exit-code assertion.
