# Verify Script Conventions

## Purpose

Each verify script runs the full quality-check pipeline for a specific stack. They are copied into downstream projects as `scripts/verify.sh` by `setup.sh`.

## Naming

```
verify-<stack>.sh
```

Matches the stack name: `frontend`, `python`, `rust`.

## Required Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "==> Running <stack> verification"

echo "--- Type check ---"
<type check command>

echo "--- Lint ---"
<lint command>

echo "--- Tests ---"
<test command>

echo ""
echo "All checks passed."
```

### Three Stages

1. **Type checking** — `npx tsc --noEmit` (frontend), `mypy .` (Python), `cargo check` (Rust)
2. **Linting** — `npx eslint . --max-warnings 0` (frontend), `ruff check .` (Python), `cargo clippy -- -D warnings` (Rust)
3. **Testing** — `npx vitest run` (frontend), `pytest` (Python), `cargo test` (Rust)

## Conventions

- Scripts exit on first failure (`set -e`) — no partial results
- Each stage gets a labeled echo (`--- Stage name ---`) for visibility
- Use `npx` for Node tools — no global installs assumed
- Keep scripts simple: no arguments, no flags, no conditional logic
- All scripts must be executable (`chmod +x`)
- Final line: `echo "All checks passed."`

## Existing Scripts

| Script | Type Check | Lint | Test |
|---|---|---|---|
| `verify-frontend.sh` | `npx tsc --noEmit` | `npx eslint . --max-warnings 0` | `npx vitest run` |
| `verify-python.sh` | `mypy .` | `ruff check .` | `pytest` |
| `verify-rust.sh` | `cargo check` | `cargo clippy -- -D warnings` | `cargo test` |
