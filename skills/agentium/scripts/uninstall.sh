#!/bin/bash
set -euo pipefail

echo "=== Agentium Uninstaller ==="
echo ""

# 1. Stop the browser
PIDFILE="$HOME/.agentium/chrome-cdp.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  kill "$(cat "$PIDFILE")" 2>/dev/null
  rm -f "$PIDFILE"
  echo "[1/4] Chrome CDP stopped"
else
  echo "[1/4] Chrome CDP was not running"
fi

# 2. Unload and remove LaunchAgent
PLIST="$HOME/Library/LaunchAgents/com.agentium.chrome-cdp.plist"
if [ -f "$PLIST" ]; then
  launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
  echo "[2/4] LaunchAgent removed"
else
  echo "[2/4] No LaunchAgent found"
fi

# 3. Remove MCP config from Claude settings
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  if command -v node &>/dev/null; then
    node -e "
      const fs = require('fs');
      const settings = JSON.parse(fs.readFileSync('$SETTINGS', 'utf8'));
      if (settings.mcpServers) delete settings.mcpServers.playwright;
      fs.writeFileSync('$SETTINGS', JSON.stringify(settings, null, 2) + '\n');
    "
  elif command -v jq &>/dev/null; then
    TMP=$(mktemp)
    jq 'del(.mcpServers.playwright)' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  fi
  echo "[3/4] Playwright MCP config removed from Claude settings"
else
  echo "[3/4] No Claude settings found"
fi

# 4. Remove agentium directory
INSTALL_DIR="$HOME/.agentium"
if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  echo "[4/4] Removed $INSTALL_DIR"
else
  echo "[4/4] No agentium directory found"
fi

echo ""
echo "=== Uninstall complete ==="
echo "Note: Playwright Chromium cache and browser profile were preserved."
echo "  Remove Chromium:  rm -rf ~/Library/Caches/ms-playwright"
echo "  Remove profile:   rm -rf ~/.agentium/chrome-profile"
