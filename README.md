# claude-bash-history

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) hook that logs every Bash tool invocation to a structured JSONL file. Gives you a persistent, greppable history of what commands Claude ran, when, where, and why — across all sessions and projects.

## Why

Claude Code doesn't keep a dedicated log of the shell commands it runs. If you want to:

- **Audit** what happened in a session after the fact
- **Resume context** in a new session by reviewing what was done before
- **Debug** a failed workflow by checking which commands errored
- **Track patterns** across projects and branches

...this hook gives you that for free, automatically, in a format you can query with `jq`.

## Sample output

```jsonl
{"ts":"2026-02-07T22:29:41Z","session":"60ec374e-6aef-4e88-ba9c-50c68652e30c","project":"/Users/you/myapp","cwd":"/Users/you/myapp","branch":"main","command":"echo \"I'm like, hey, what's up, hello\"","description":"Echo first line from Trap Queen","exit_code":0,"output_preview":"{\"stdout\":\"I'm like, hey, what's up, hello\",\"stderr\":\"\",\"interrupted\":false,\"isImage\":false}","transcript":"/Users/you/.claude/projects/.../session.jsonl"}
{"ts":"2026-02-07T22:50:22Z","session":"94f1fe20-b81b-426b-937a-c9d56e17d952","project":"/Users/you/myapp","cwd":"/Users/you/myapp","branch":"main","command":"wc -l ~/.claude/bash_history.jsonl","description":"Check how many entries exist","exit_code":0,"output_preview":"{\"stdout\":\"       2 /Users/you/.claude/bash_history.jsonl\",\"stderr\":\"\",\"interrupted\":false,\"isImage\":false}","transcript":"/Users/you/.claude/projects/.../session.jsonl"}
```

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (hooks support)
- [`jq`](https://jqlang.github.io/jq/) (JSON processing)

## Install

```bash
git clone https://github.com/JoeyArrigo/claude-bash-history.git
cd claude-bash-history
bash install.sh
```

The installer:
1. Copies `log-bash.sh` to `~/.claude/hooks/`
2. Registers a `PostToolUse` hook in `~/.claude/settings.json`

Logging starts on your next Claude Code session.

## Uninstall

```bash
bash uninstall.sh
```

Removes the hook script and settings entry. Your log file is preserved.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_BASH_HISTORY_FILE` | `~/.claude/bash_history.jsonl` | Path to the log file |

Set it in your shell profile to override:

```bash
export CLAUDE_BASH_HISTORY_FILE="/Users/you/logs/claude-bash.jsonl"
```

## Schema

Each line in the JSONL file is a JSON object with these fields:

| Field | Type | Description |
|---|---|---|
| `ts` | string | ISO 8601 UTC timestamp |
| `session` | string | Claude Code session ID |
| `project` | string | Git root (or cwd if not a repo) |
| `cwd` | string | Working directory when the command ran |
| `branch` | string | Git branch (empty if not a repo) |
| `command` | string | The shell command that was executed |
| `description` | string | Why Claude ran the command (human-readable) |
| `exit_code` | number | Exit code (0 = success, best-effort extraction) |
| `output_preview` | string | First 200 characters of command output |
| `transcript` | string | Path to the full session transcript file |

## Querying the log

```bash
# Last 10 commands
tail -10 ~/.claude/bash_history.jsonl | jq .

# Commands that failed
jq 'select(.exit_code != 0)' ~/.claude/bash_history.jsonl

# Commands from a specific project
jq 'select(.project | contains("myapp"))' ~/.claude/bash_history.jsonl

# Commands on a specific branch
jq 'select(.branch == "main")' ~/.claude/bash_history.jsonl

# Just the commands and descriptions (great for context refresh)
jq '{command, description, branch}' ~/.claude/bash_history.jsonl

# Commands from today
jq 'select(.ts | startswith("2026-02-07"))' ~/.claude/bash_history.jsonl

# Group by session
jq -s 'group_by(.session) | map({session: .[0].session, count: length, commands: [.[].command]})' ~/.claude/bash_history.jsonl

# Unique commands ranked by frequency
jq -r .command ~/.claude/bash_history.jsonl | sort | uniq -c | sort -rn | head -20
```

## How it works

Claude Code [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) let you run shell commands in response to tool events. This project registers a `PostToolUse` hook that triggers after every Bash tool call. The hook receives the tool invocation details as JSON on stdin, enriches it with git context, and appends a single JSONL line to the log file.

The hook is designed to be invisible — it runs silently, suppresses all errors, and always exits 0 so it never interferes with Claude Code's operation.

## License

[BSD 2-Clause](LICENSE)
