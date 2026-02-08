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
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "npx tsc --noEmit 2>&1 | tail -20" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "<guard command>" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "scripts/verify.sh 2>&1 | tail -30" },
          { "type": "prompt", "prompt": "Self-review checklist text here" }
        ]
      }
    ]
  }
}
```

## Hook Types

**PostToolUse** — Runs after Claude uses a tool
- `matcher`: pipe-separated tool names (e.g., `"Write|Edit"`)
- Use for: auto-formatting, type checking, syntax validation
- Must be fast (<5 seconds) — runs on every matching tool use

**PreToolUse** — Runs before Claude uses a tool
- Use for: branch guards, blocking edits to protected files
- Exit code 2 blocks the tool use

**Stop** — Runs when Claude completes a response
- `matcher`: empty string `""` matches all completions
- Use for: running the full verify script, self-review prompt
- Can be slower since it runs once at the end

## Hook Subtypes

**Command hooks** (`"type": "command"`):
- `command` field contains a shell command
- Pipe output through `tail -N` to limit context window consumption
- Include `2>&1` to capture stderr

**Prompt hooks** (`"type": "prompt"`):
- `prompt` field contains text sent to Claude as a self-review checklist
- Use for convention checks that require judgment, not just pass/fail

## Guidelines

- Commands must be non-interactive (no prompts, no editors)
- Use relative paths (`scripts/verify.sh`) so hooks work from any project root
- PostToolUse commands should complete in under 5 seconds
- Always pipe through `tail` to avoid flooding Claude's context with long output

## Current Templates

| File | PostToolUse | Stop | Status |
|---|---|---|---|
| `frontend-settings.json` | `npx tsc --noEmit` on Write\|Edit | — | Has PostToolUse |
| `python-settings.json` | — | — | Empty `{}` |
| `rust-settings.json` | — | — | Empty `{}` |
