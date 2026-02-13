# Verify Script Conventions

## Purpose

Each verify script runs the full quality-check pipeline for a specific stack. They are copied into downstream projects as `scripts/verify.sh` by `setup.sh`. The guard script (`guard-bash.sh`) blocks dangerous Bash commands and is shared across all stacks.

## Naming

```
verify-<stack>.sh    # Stack-specific verification
guard-bash.sh        # Shared dangerous command guard
```

Matches the stack name: `frontend`, `python`, `rust`.

## Required Structure

```bash
#!/usr/bin/env bash
set -uo pipefail

echo "==> Running <stack> verification" >&2

echo "--- Type check ---" >&2
<type check command> 2>&1 || { echo "FAIL: Type check failed" >&2; exit 2; }

echo "--- Lint ---" >&2
<lint command> 2>&1 || { echo "FAIL: Lint failed" >&2; exit 2; }

echo "--- Tests ---" >&2
<test command> 2>&1 || { echo "FAIL: Tests failed" >&2; exit 2; }

echo "" >&2
echo "All checks passed." >&2
```

### Three Stages

1. **Type checking** — `npx tsc --noEmit` (frontend), `mypy .` (Python), `cargo check` (Rust)
2. **Linting** — `npx eslint . --max-warnings 0` (frontend), `ruff check .` (Python), `cargo clippy -- -D warnings` (Rust)
3. **Testing** — `npx vitest run` (frontend), `pytest` (Python), `cargo test` (Rust)

## Conventions

- Use `set -uo pipefail` (**not** `set -e`) — explicit error handling per command
- Each command gets `|| { echo "FAIL: ..." >&2; exit 2; }` for Stop hook compatibility
- **Exit code 2** on failure — this is what Claude Code Stop hooks require to block
- All output goes to **stderr** (`>&2`) — that's what Claude sees when a Stop hook blocks
- Each stage gets a labeled echo (`--- Stage name ---`) for visibility
- Use `npx` for Node tools — no global installs assumed
- Keep scripts simple: no arguments, no flags, no conditional logic
- All scripts must be executable (`chmod +x`)
- Final line: `echo "All checks passed." >&2`

## Existing Scripts

| Script               | Type Check         | Lint                            | Test             |
| -------------------- | ------------------ | ------------------------------- | ---------------- |
| `verify-frontend.sh` | `npx tsc --noEmit` | `npx eslint . --max-warnings 0` | `npx vitest run` |
| `verify-python.sh`   | `mypy .`           | `ruff check .`                  | `pytest`         |
| `verify-rust.sh`     | `cargo check`      | `cargo clippy -- -D warnings`   | `cargo test`     |
| `guard-bash.sh`      | —                  | —                               | —                |
