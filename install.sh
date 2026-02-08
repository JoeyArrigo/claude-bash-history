#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
HOOK_SCRIPT="$HOOKS_DIR/log-bash.sh"

echo "Installing claude-bash-history..."
echo ""

# --- Prerequisites ---

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  echo ""
  echo "For more info: https://jqlang.org/"
  echo ""
  exit 1
fi

# --- Validate existing settings (before making any changes) ---

if [ -f "$SETTINGS_FILE" ]; then
  if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
    echo "Error: $SETTINGS_FILE contains invalid JSON."
    echo ""
    echo "  No changes were made."
    echo "  Fix the file, then re-run this installer."
    echo ""
    echo "  Settings file docs: https://docs.anthropic.com/en/docs/claude-code/settings"
    echo ""
    exit 1
  fi
fi

# --- Install hook script ---

mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/log-bash.sh" "$HOOK_SCRIPT"
chmod +x "$HOOK_SCRIPT"
echo "  Copied hook script to $HOOK_SCRIPT"

# --- Update settings.json ---

# Use absolute path so there's no ambiguity at runtime
HOOK_ENTRY=$(jq -n --arg cmd "$HOOK_SCRIPT" '{
  matcher: "Bash",
  hooks: [{ type: "command", command: $cmd }]
}')

if [ -f "$SETTINGS_FILE" ]; then
  EXISTING=$(cat "$SETTINGS_FILE")

  # Check if PostToolUse array exists
  if echo "$EXISTING" | jq -e '.hooks.PostToolUse' &>/dev/null; then
    # Check if our hook is already registered
    if echo "$EXISTING" | jq -e --arg cmd "$HOOK_SCRIPT" \
        '.hooks.PostToolUse[] | select(.hooks[]?.command == $cmd)' &>/dev/null; then
      echo "  Hook already registered in settings.json (no changes)"
    else
      echo "$EXISTING" | jq --argjson hook "$HOOK_ENTRY" \
        '.hooks.PostToolUse += [$hook]' > "$SETTINGS_FILE"
      echo "  Added hook to existing PostToolUse array"
    fi
  elif echo "$EXISTING" | jq -e '.hooks' &>/dev/null; then
    echo "$EXISTING" | jq --argjson hook "$HOOK_ENTRY" \
      '.hooks.PostToolUse = [$hook]' > "$SETTINGS_FILE"
    echo "  Added PostToolUse hook to existing hooks config"
  else
    echo "$EXISTING" | jq --argjson hook "$HOOK_ENTRY" \
      '.hooks = { PostToolUse: [$hook] }' > "$SETTINGS_FILE"
    echo "  Added hooks config to settings.json"
  fi
else
  mkdir -p "$CLAUDE_DIR"
  jq -n --argjson hook "$HOOK_ENTRY" \
    '{ hooks: { PostToolUse: [$hook] } }' > "$SETTINGS_FILE"
  echo "  Created settings.json with hook config"
fi

# --- Install skill ---

SKILLS_DIR="$CLAUDE_DIR/skills"
SKILL_LINK="$SKILLS_DIR/bash-history"

mkdir -p "$SKILLS_DIR"

if [ -L "$SKILL_LINK" ] || [ -d "$SKILL_LINK" ]; then
  echo "  Skill already installed at $SKILL_LINK (no changes)"
else
  ln -s "$SCRIPT_DIR/skill/bash-history" "$SKILL_LINK"
  echo "  Linked skill to $SKILL_LINK"
fi

echo ""
echo "Done! Bash commands will be logged starting with your next Claude Code session."
echo ""
echo "  Log file: ~/.claude/bash_history.jsonl"
echo "  Override: export CLAUDE_BASH_HISTORY_FILE=/path/to/custom.jsonl"
echo ""
echo "  The bash-history skill lets Claude search the log automatically."
echo "  You can also invoke it manually with /bash-history."
