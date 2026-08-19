# Project-layer templates

The **project layer** is everything a consumer repo needs that is NOT vendored: the bindings
manifest, the gate shims, the review anchors, the contributing rules the manifest points into. The
vendored pack is identical everywhere; this is what makes it mean the right thing in one repo.

`setup.sh --bootstrap` writes these. They live here as **real files** rather than heredocs inside
the script so that changing one is a markdown edit, not shell string-formatting.

## Adding a scaffolded file

Two steps, no shell editing:

1. Drop the template under `templates/project/`, mirroring where it lands in the consumer
   (`claude/` maps to `.claude/`).
2. Add one row to [`FILES.tsv`](FILES.tsv).

```
#source	dest	mode	when	summary
claude/scripts/ui-gate.sh	.claude/scripts/ui-gate.sh	755	ui	UI gate shim
```

| Column    | Meaning                                                       |
| --------- | ------------------------------------------------------------- |
| `source`  | path under `templates/project/`                               |
| `dest`    | path in the consumer repo, relative to its root               |
| `mode`    | mode to `chmod` after writing — `755` for anything executable |
| `when`    | `always`, or `ui` to write only when bootstrap detects a UI   |
| `summary` | one line; printed by bootstrap and reused in its TODO notes   |

Columns are **tab-separated**. Blank lines and `#` comments are ignored.

## Tokens

A template may use `{{TOKEN}}` placeholders. They are substituted at write time:

| Token           | Value                                                       |
| --------------- | ----------------------------------------------------------- |
| `{{REPO_NAME}}` | the consumer repo's directory name                          |
| `{{TODAY}}`     | UTC date, `YYYY-MM-DD`                                      |
| `{{UI_EV}}`     | the evidence string for the UI detection (empty when no UI) |

An unknown `{{TOKEN}}` is left **as-is** rather than blanked, so a typo shows up in the output
instead of silently deleting content. Add a token by extending `_boot_render_template` in
`setup.sh`; keep the list above in step with it.

## Rules these templates follow

- **An unwired shim exits 2, never 0.** A stub that exits 0 reports a green tree without running
  anything, and every caller treats 0 as proof. Could-not-run is the correct unfilled state.
- **A scaffolded file is never overwritten.** An existing destination is reported as skipped, the
  same as the manifest and the gate shim. Bootstrap is safe to re-run.
- **A file the manifest binds into must exist.** `checklist.path`/`checklist.section` and
  `tier.path`/`tier.section` point into `CONTRIBUTING.md`; if that file were left to the consumer,
  a fresh repo would have bindings resolving nowhere — which the degrade rules make a could-not-run,
  not a pass. That is why `CONTRIBUTING.md` ships with real content and not a stub.
- **Templates carry no consumer-specific facts.** Anything repo-specific is a token or a TODO.
