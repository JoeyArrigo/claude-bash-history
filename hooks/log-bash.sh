#!/usr/bin/env bash
# claude-bash-history: Log Claude Code bash tool usage to JSONL
# https://github.com/JoeyArrigo/claude-bash-history
# SPDX-License-Identifier: BSD-2-Clause

LOG_FILE="${CLAUDE_BASH_HISTORY_FILE:-$HOME/.claude/bash_history.jsonl}"

main() {
  # Read hook input from stdin (Claude Code sends JSON)
  local input
  input=$(cat)

  # Extract cwd for git context (needs shell access)
  local cwd
  cwd=$(echo "$input" | jq -r '.cwd // ""')

  # Git context (silent failure if not a repo)
  local branch="" project=""
  if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    branch=$(cd "$cwd" && git branch --show-current 2>/dev/null || true)
    project=$(cd "$cwd" && git rev-parse --show-toplevel 2>/dev/null || true)
  fi

  # ISO 8601 timestamp
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Ensure log directory exists
  mkdir -p "$(dirname "$LOG_FILE")"

  # Build and append JSONL entry (single jq call handles field extraction + formatting)
  echo "$input" | jq -c \
    --arg ts "$ts" \
    --arg branch "$branch" \
    --arg project "$project" \
    '{
      ts: $ts,
      session: (.session_id // ""),
      project: $project,
      cwd: (.cwd // ""),
      branch: $branch,
      command: (.tool_input.command // ""),
      description: (.tool_input.description // ""),
      exit_code: (
        if (.tool_response | type) == "string" then
          [.tool_response | scan("[Ee]xit code: *([0-9]+)")] | last // ["0"] | .[0] | tonumber
        elif (.tool_response | type) == "object" then
          .tool_response.exitCode // .tool_response.exit_code // 0
        else 0 end
      ),
      output_preview: (
        if (.tool_response | type) == "string" then
          .tool_response[:200]
        elif (.tool_response | type) == "object" then
          (.tool_response | tostring)[:200]
        else "" end
      ),
      transcript: (.transcript_path // "")
    }' >> "$LOG_FILE"
}

# Run silently — never interfere with Claude Code operation
main "$@" 2>/dev/null
exit 0
