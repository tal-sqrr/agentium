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

# 3. Remove MCP config from all agents
remove_mcp_config() {
  local config_file="$1"
  local agent_name="$2"
  [ -f "$config_file" ] || return 1
  if command -v node &>/dev/null; then
    node -e "
      const fs = require('fs');
      const settings = JSON.parse(fs.readFileSync('$config_file', 'utf8'));
      if (settings.mcpServers) delete settings.mcpServers.playwright;
      fs.writeFileSync('$config_file', JSON.stringify(settings, null, 2) + '\n');
    "
  elif command -v jq &>/dev/null; then
    TMP=$(mktemp)
    jq 'del(.mcpServers.playwright)' "$config_file" > "$TMP" && mv "$TMP" "$config_file"
  else
    return 1
  fi
  echo "  ✓ $agent_name ($config_file)"
}

REMOVED=0
for pair in \
  "$HOME/.claude/settings.json|Claude Code" \
  "$HOME/.cursor/mcp.json|Cursor" \
  "$HOME/.codeium/windsurf/mcp_config.json|Windsurf" \
  "$HOME/.amp/mcp.json|Amp"; do
  config_file="${pair%%|*}"
  agent_name="${pair##*|}"
  if remove_mcp_config "$config_file" "$agent_name"; then
    REMOVED=$((REMOVED + 1))
  fi
done

if [ "$REMOVED" -gt 0 ]; then
  echo "[3/4] Playwright MCP config removed from $REMOVED agent(s)"
else
  echo "[3/4] No agent MCP configs found"
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
