# Hook Settings Conventions

## Purpose

Files in this directory are `.claude/settings.json` templates. When `setup.sh` runs for a stack, the matching settings file is copied into the target project's `.claude/settings.json` (if one doesn't already exist).

## Naming

```
<stack>-settings.json
```

Matches the stack name used in `setup.sh`: `frontend`, `python`, `rust`.

## JSON Structure

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/guard-bash.sh" }
        ]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "<protected-files guard>" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "<formatter command>" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "<stop_hook_active guard + verify.sh>" }
        ]
      }
    ]
  }
}
```

## Hook Types

**PreToolUse** — Runs before Claude uses a tool
- `matcher`: regex pattern against tool name (e.g., `"Bash"`, `"Edit|Write"`)
- Use for: blocking dangerous commands, protecting lock files and `.env`
- Exit code 2 blocks the tool use; stderr shown to Claude

**PostToolUse** — Runs after Claude uses a tool
- `matcher`: regex pattern against tool name
- Use for: auto-formatting every file Claude touches
- Must be fast (<5 seconds) — runs on every matching tool use
- Exit code 2 sends stderr to Claude (tool already ran, can't block)

**Stop** — Runs when Claude completes a response
- No matcher needed — fires on every completion
- Use for: running the full verify script as a quality gate
- **Must check `stop_hook_active`** to prevent infinite retry loops

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success — continue normally |
| `2` | Block — PreToolUse blocks the tool; Stop forces Claude to fix issues |
| Other | Non-blocking error — logged in verbose mode, no effect |

## Critical Patterns

### Stop Hook Guard (prevents infinite loops)

```
jq -r '.stop_hook_active' | { read -r active; [ "$active" = "true" ] && exit 0; ... }
```

When `stop_hook_active` is `true`, Claude is already retrying after a previous failure. Exit 0 to let Claude stop (one retry cycle maximum).

### Stderr Routing for Stop Hooks

```
OUT=$("$CLAUDE_PROJECT_DIR"/scripts/verify.sh 2>&1); RC=$?; echo "$OUT" | tail -30 >&2; exit $RC;
```

Captures verify.sh output, truncates to 30 lines, sends to stderr (which Claude sees on exit 2).

### Protected File Guard

```
jq -r '.tool_input.file_path' | { read -r fp; if echo "$fp" | grep -qE '<pattern>'; then echo "Blocked: ..." >&2; exit 2; fi; }
```

Always use `read -r` (not `read`) to prevent backslash interpretation.

## Valid Matcher Tool Names

`Bash`, `Edit`, `Write`, `Read`, `Glob`, `Grep`, `WebFetch`, `WebSearch`, `Task`, `mcp__<server>__<tool>`

Note: `MultiEdit` does not exist. Use `Edit|Write` for file modification hooks.

## Guidelines

- Always use `"$CLAUDE_PROJECT_DIR"` for paths — working directory varies between invocations
- Commands must be non-interactive (no prompts, no editors)
- PostToolUse commands should complete in under 5 seconds
- Pipe long output through `tail` to avoid flooding Claude's context
- All hook scripts require `jq` — ensure it is installed in target environments
- Add `$schema` field for IDE validation

## Current Templates

| File | PreToolUse | PostToolUse | Stop |
|---|---|---|---|
| `frontend-settings.json` | guard-bash.sh + protect .env/locks | prettier | verify.sh |
| `python-settings.json` | guard-bash.sh + protect .env/locks | black + isort | verify.sh |
| `rust-settings.json` | guard-bash.sh + protect .env/Cargo.lock | rustfmt | verify.sh |
