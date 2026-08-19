#!/usr/bin/env bash
#
# ui-gate.sh - the portable "run the UI gate" shim. OPTIONAL contract.
#
# This is `ui.command` in .claude/PROJECT.md, reached only when `ui.enabled` is true. No logic
# belongs here: it is a shim, not a gate. Arguments pass straight through.
#
# STDOUT CONTRACT - the reason this shim cannot be guessed from a directory listing, and the reason
# it is scaffolded UNWIRED rather than pointed at something plausible:
#
#   * The LAST line of STDOUT is the ABSOLUTE screenshot directory. That path is what gets handed
#     to the design reviewer, so it must be a real directory of real screenshots.
#   * Every human-readable line goes to STDERR, so stdout stays clean for the caller.
#   * On any non-zero exit this shim writes NOTHING to stdout, so a caller reading stdout gets an
#     empty string rather than a plausible-looking wrong path.
#
# Judge on the exit status, never on whether the last stdout line looks like a path. One trap worth
# naming so nobody re-derives it wrongly: `X="$(this-shim | tail -n1)"` reports tail's status, not
# this shim's, so without `pipefail` in the calling shell it reads a could-not-run as a pass.
# Capture the status first, tail second.
#
# EXIT CODES:
#
#   0   PASS. The UI gate ran and is green; the last stdout line is the screenshot directory.
#
#   2   COULD NOT RUN / NOT AVAILABLE. The delegate is missing, or a tool it needs is absent. This
#       file being absent altogether, or `ui.enabled` being false or absent in the manifest, is the
#       same case for the caller: a declared skip, never a pass.
#
#   *   FAIL. The gate ran and the UI is red. Fix it.
#
# Scaffolded by `setup.sh --bootstrap` on {{TODAY}}.
set -euo pipefail

# Repo root: this script sits two levels down, so the shim works from any cwd.
cd "$(dirname "$0")/../.."

# ---------------------------------------------------------------------------------------------
# NOT WIRED YET. Bootstrap detected a UI ({{UI_EV}}) but cannot infer how this repo takes
# screenshots, so this shim refuses to answer rather than answer wrongly.
#
# EXIT 2, NEVER 0. A stub that exited 0 would report a conformant UI without looking at it, and
# would hand the reviewer an empty or wrong screenshot path. The unfilled state is could-not-run by
# construction.
#
# TO FIX: delete this block, replace it with the real command, and keep the stdout contract above.
# The shape that satisfies it:
#
#     command -v npx >/dev/null 2>&1 || { echo "ui-gate: npx not on PATH - COULD NOT RUN" >&2; exit 2; }
#     shots="$(cd "$(dirname "$0")/../.." && pwd)/.artifacts/ui-gate"
#     mkdir -p "$shots"
#     status=0
#     npx playwright test ${@+"$@"} >&2 || status=$?
#     case "$status" in 126|127) exit 2 ;; esac
#     [ "$status" -eq 0 ] || exit "$status"   # non-zero => NOTHING on stdout
#     echo "$shots"                           # the ONLY stdout line: the absolute screenshot dir
#
# Then bind it in .claude/PROJECT.md:
#
#     | `ui.command` | `bash .claude/scripts/ui-gate.sh` |
# ---------------------------------------------------------------------------------------------
echo "ui-gate: no UI gate is wired into this repo yet." >&2
echo "ui-gate: COULD NOT RUN (exit 2, treat as a declared skip - never a pass)." >&2
echo "ui-gate: fill in .claude/scripts/ui-gate.sh, then bind ui.command in .claude/PROJECT.md." >&2
exit 2
