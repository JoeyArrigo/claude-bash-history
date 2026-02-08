---
name: bash-history
description: >
  Search the Claude Code bash tool history log. Use when: recalling a past
  command or approach ("how did I do X before?"), filling gaps in git history
  or working directory state, checking what actions have already been taken in
  a session or project, or when something feels like it might be missing.
  Also useful when the user says "you did this before" or "didn't you already…".
allowed-tools: Bash, Read, Grep
---

# Bash History Search

The file `~/.claude/bash_history.jsonl` (or `$CLAUDE_BASH_HISTORY_FILE`) contains
a line per Bash tool invocation, recorded by a PostToolUse hook. Each line is JSON:

```
ts            ISO 8601 timestamp
session       session ID
project       git root (or cwd if not a repo)
cwd           working directory at time of call
branch        git branch at time of call
command       the command that was run
description   the Bash tool description field
exit_code     numeric exit code
output_preview first 200 chars of output
transcript    path to the session transcript
```

## How to search

Use `jq` against the log file. Prefer `select()` filters piped through the
single file rather than grep, since the data is structured JSON.

```bash
# Recent commands in a project
jq -r 'select(.project | contains("myproject")) | "\(.ts) \(.command)"' \
  ~/.claude/bash_history.jsonl | tail -20

# Search commands by keyword
jq -r 'select(.command | test("docker"; "i")) | "\(.ts) [\(.project | split("/")[-1])] \(.command)"' \
  ~/.claude/bash_history.jsonl

# Failed commands (non-zero exit)
jq -r 'select(.exit_code != 0) | "\(.ts) exit=\(.exit_code) \(.command)"' \
  ~/.claude/bash_history.jsonl

# Commands on a specific branch
jq -r 'select(.branch == "feature-x") | .command' \
  ~/.claude/bash_history.jsonl

# Commands from a specific session
jq -r 'select(.session == "SESSION_ID") | "\(.ts) \(.command)"' \
  ~/.claude/bash_history.jsonl

# Today's commands
jq -r --arg d "$(date -u +%Y-%m-%d)" \
  'select(.ts | startswith($d)) | "\(.ts) \(.command)"' \
  ~/.claude/bash_history.jsonl
```

## When to use this

- **"How did I/you do X?"** -- search by command keyword or description
- **Verifying past work** -- filter by project + branch to see what was already done
- **Something feels missing** -- check recent session commands to spot gaps
- **Understanding current state** -- review what commands led to the current
  working directory / git state, especially across sessions
- **Reproducing a workflow** -- find the sequence of commands from a prior session

## Tips

- Pipe through `tail` to limit output when the log is large.
- Use `test("pattern"; "i")` for case-insensitive search in jq.
- The `description` field often captures intent better than the raw command.
- Combine filters: `select(.project | contains("X")) | select(.command | test("Y"))`.
- The `output_preview` field is truncated at 200 chars -- for full output, check
  the transcript file referenced in the `transcript` field.
