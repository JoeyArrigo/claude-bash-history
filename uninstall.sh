#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
HOOK_SCRIPT="$HOOKS_DIR/log-bash.sh"

echo "Uninstalling claude-bash-history..."
echo ""

# --- Remove hook script ---

if [ -f "$HOOK_SCRIPT" ]; then
  rm "$HOOK_SCRIPT"
  echo "  Removed $HOOK_SCRIPT"
else
  echo "  Hook script not found (already removed?)"
fi

# --- Remove from settings.json ---

if [ -f "$SETTINGS_FILE" ] && command -v jq &>/dev/null; then
  if jq -e '.hooks.PostToolUse' "$SETTINGS_FILE" &>/dev/null; then
    # Remove our entry, then clean up empty arrays/objects
    # Remove entries matching either old format (.command) or new format (.hooks[].command)
    jq --arg cmd "$HOOK_SCRIPT" '
      .hooks.PostToolUse |= map(select(
        (.command == $cmd or any(.hooks[]?; .command == $cmd)) | not
      ))
      | if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end
      | if .hooks == {} then del(.hooks) else . end
    ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    echo "  Removed hook from settings.json"
  else
    echo "  No PostToolUse hooks found in settings.json"
  fi
fi

# --- Remove skill symlink ---

SKILL_LINK="$CLAUDE_DIR/skills/bash-history"

if [ -L "$SKILL_LINK" ]; then
  rm "$SKILL_LINK"
  echo "  Removed skill symlink $SKILL_LINK"
elif [ -d "$SKILL_LINK" ]; then
  echo "  Skill directory at $SKILL_LINK is not a symlink — skipping (remove manually if desired)"
else
  echo "  Skill symlink not found (already removed?)"
fi

echo ""
echo "Done! Your log file was preserved:"
echo "  ~/.claude/bash_history.jsonl"
echo ""
echo "Delete it manually if you no longer need it."
