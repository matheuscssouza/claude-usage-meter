#!/bin/bash
# Builds the menu bar app, installs the status line and wires both into Claude Code.
# Usage: scripts/install.sh [--login-item]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HOME/Applications/MedidorClaude.app"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
# Build outside the source tree: synced folders (Dropbox, iCloud) corrupt SwiftPM caches.
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

for bin in swift jq codesign; do
  command -v "$bin" >/dev/null || { echo "error: '$bin' is required" >&2; exit 1; }
done

echo "→ building"
swift build -c release --package-path "$ROOT" --scratch-path "$BUILD_DIR" >/dev/null

echo "→ installing app to $APP"
pkill -x MedidorClaude 2>/dev/null || true
mkdir -p "$APP/Contents/MacOS"
cp "$BUILD_DIR/release/MedidorClaude" "$APP/Contents/MacOS/"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1

echo "→ installing status line"
mkdir -p "$CLAUDE_DIR"
install -m 755 "$ROOT/statusline/statusline.sh" "$CLAUDE_DIR/statusline.sh"

echo "→ updating $SETTINGS"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak"
HOOK='jq -r .session_id | xargs -I{} rm -f "$HOME/.claude/medidor/sessions/{}.json"'
jq --arg hook "$HOOK" '
  .statusLine = {type: "command", command: "~/.claude/statusline.sh", refreshInterval: 60}
  | .hooks.SessionEnd = ((.hooks.SessionEnd // [])
      | if any(.[]?.hooks[]?; .command == $hook) then .
        else . + [{hooks: [{type: "command", command: $hook, timeout: 5}]}] end)
' "$SETTINGS.bak" > "$SETTINGS"

if [ "${1:-}" = "--login-item" ]; then
  echo "→ adding login item"
  osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP\", hidden:true}" >/dev/null
fi

open -g "$APP"
echo "done. Previous settings saved at $SETTINGS.bak"
