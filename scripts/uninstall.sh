#!/bin/bash
# Removes the app, the status line and the Claude Code settings entries added by install.sh.
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

pkill -x ClaudeUsageMeter 2>/dev/null || true
rm -rf "$HOME/Applications/ClaudeUsageMeter.app" "$CLAUDE_DIR/statusline.sh" "$CLAUDE_DIR/usage-meter"
osascript -e 'tell application "System Events" to delete login item "ClaudeUsageMeter"' >/dev/null 2>&1 || true

if [ -f "$SETTINGS" ]; then
  BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"   # never overwrite an earlier backup
cp "$SETTINGS" "$BACKUP"
  jq 'del(.statusLine)
      | if .hooks.SessionEnd then
          .hooks.SessionEnd |= map(select(any(.hooks[]?; (.command // "") | contains("usage-meter/sessions")) | not))
        else . end
      | if (.hooks.SessionEnd // [1]) == [] then del(.hooks.SessionEnd) else . end' \
    "$BACKUP" > "$SETTINGS"
fi
echo "removed. Previous settings saved at $BACKUP"
