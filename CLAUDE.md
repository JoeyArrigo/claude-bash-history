# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Claude Code plugin that logs every Bash tool invocation to a structured JSONL file. It registers a `PostToolUse` hook that fires after each Bash tool call, enriches the event with git context (branch, project root), and appends a single JSONL line to `~/.claude/bash_history.jsonl`. Includes a skill for searching the log.

## Architecture

A Claude Code plugin with no build system or tests:

- **`hooks/log-bash.sh`** — The hook itself. Reads Claude Code's hook JSON from stdin, extracts `cwd` for git context, then a single `jq` call handles all remaining field extraction, exit code parsing, and JSON construction. Designed to never fail (stderr suppressed, always exits 0).
- **`hooks/hooks.json`** — Plugin hook configuration. Registers `log-bash.sh` as a `PostToolUse` hook for the Bash tool, using `${CLAUDE_PLUGIN_ROOT}` for portable path resolution.
- **`skills/bash-history/SKILL.md`** — Skill that teaches Claude to search the log with `jq`. Auto-triggers when users ask about past commands or when context seems incomplete.
- **`.claude-plugin/plugin.json`** — Plugin manifest with metadata.

## Key Details

- Runtime dependency: `jq` (required by the hook script)
- Hook input contract: JSON on stdin with fields `session_id`, `cwd`, `tool_input.command`, `tool_input.description`, `tool_response`, `transcript_path`
- Exit code extraction is handled inside jq: string responses use `scan` (regex), object responses check `.exitCode` / `.exit_code`, defaulting to 0 when not found
- Log path is configurable via `CLAUDE_BASH_HISTORY_FILE` env var

## Testing Changes

No automated tests. To verify manually:

```bash
# Test log-bash.sh directly by piping mock hook input (use printf, not echo,
# because zsh's echo interprets \n in the JSON escape as a real newline)
printf '%s\n' '{"session_id":"test","cwd":"/tmp","tool_input":{"command":"echo hi","description":"test"},"tool_response":"hi\nExit code: 0","transcript_path":""}' | bash hooks/log-bash.sh
tail -1 ~/.claude/bash_history.jsonl | jq .

# Test the plugin loads correctly
claude --plugin-dir .
# Then run a bash command and verify logging:
#   tail -1 ~/.claude/bash_history.jsonl | jq .
```
