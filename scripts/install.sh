#!/bin/bash
set -euo pipefail

# Agentium installer — sets up persistent Chrome CDP for Claude Code.
# Run from repo: ./scripts/install.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="$HOME/.claude/browser-use"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.claude.chrome-cdp.plist"
SETTINGS_FILE="$HOME/.claude/settings.json"
PW_CACHE="$HOME/Library/Caches/ms-playwright"

STEPS=7

# ------------------------------------------------------------------
# 1. Copy core files
# ------------------------------------------------------------------
echo "[1/$STEPS] Copying core files to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
cp "$REPO_DIR/src/chrome-cdp"        "$INSTALL_DIR/chrome-cdp"
cp "$REPO_DIR/src/nofocus.m"         "$INSTALL_DIR/nofocus.m"
cp "$REPO_DIR/assets/chrome-icon.svg" "$INSTALL_DIR/chrome-icon.svg"
cp "$REPO_DIR/assets/chrome-icon.icns" "$INSTALL_DIR/chrome-icon.icns"
chmod +x "$INSTALL_DIR/chrome-cdp"

# ------------------------------------------------------------------
# 2. Compile nofocus.dylib
# ------------------------------------------------------------------
echo "[2/$STEPS] Compiling nofocus.dylib ..."
ARCH="$(uname -m)"
if [ "$ARCH" = "x86_64" ]; then
  TARGET="x86_64-apple-macos10.15"
elif [ "$ARCH" = "arm64" ]; then
  TARGET="arm64-apple-macos11.0"
else
  echo "Unsupported architecture: $ARCH" >&2
  exit 1
fi
clang -dynamiclib -framework AppKit -target "$TARGET" \
  -o "$INSTALL_DIR/nofocus.dylib" "$INSTALL_DIR/nofocus.m"
echo "  Compiled for $ARCH ($TARGET)"

# ------------------------------------------------------------------
# 3. Install Playwright Chromium
# ------------------------------------------------------------------
echo "[3/$STEPS] Checking Playwright Chromium ..."
if [ -d "$PW_CACHE" ] && find "$PW_CACHE" -name "Google Chrome for Testing" -path "*/MacOS/*" -print -quit 2>/dev/null | grep -q .; then
  echo "  Playwright Chromium already installed."
else
  echo "  Installing Playwright Chromium ..."
  npx playwright install chromium
fi

# ------------------------------------------------------------------
# 4. Install LaunchAgent
# ------------------------------------------------------------------
echo "[4/$STEPS] Installing LaunchAgent ..."
mkdir -p "$HOME/Library/LaunchAgents"

# Unload existing agent if present (ignore errors)
launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true

cat > "$LAUNCH_AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.chrome-cdp</string>
    <key>ProgramArguments</key>
    <array>
        <string>${INSTALL_DIR}/chrome-cdp</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/chrome-cdp.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/chrome-cdp.log</string>
</dict>
</plist>
PLIST

launchctl load "$LAUNCH_AGENT"
echo "  LaunchAgent loaded."

# ------------------------------------------------------------------
# 5. Merge Playwright MCP config into settings.json
# ------------------------------------------------------------------
echo "[5/$STEPS] Configuring Playwright MCP in $SETTINGS_FILE ..."

MCP_COMMAND="npx"
MCP_ARGS='["@playwright/mcp@latest","--cdp-endpoint","http://localhost:9222"]'
MCP_ENV='{"PLAYWRIGHT_MCP_CDP_ENDPOINT":"http://localhost:9222"}'

merge_with_node() {
  node -e "
const fs = require('fs');
const path = '$SETTINGS_FILE';
let settings = {};
try { settings = JSON.parse(fs.readFileSync(path, 'utf8')); } catch {}
if (!settings.mcpServers) settings.mcpServers = {};
settings.mcpServers.playwright = {
  command: '$MCP_COMMAND',
  args: $MCP_ARGS,
  env: $MCP_ENV
};
fs.writeFileSync(path, JSON.stringify(settings, null, 2) + '\n');
"
}

merge_with_jq() {
  local tmp
  tmp="$(mktemp)"
  if [ -f "$SETTINGS_FILE" ]; then
    jq --argjson args "$MCP_ARGS" \
       --argjson env "$MCP_ENV" \
       '.mcpServers.playwright = {command: "npx", args: $args, env: $env}' \
       "$SETTINGS_FILE" > "$tmp"
  else
    jq -n --argjson args "$MCP_ARGS" \
          --argjson env "$MCP_ENV" \
          '{mcpServers: {playwright: {command: "npx", args: $args, env: $env}}}' > "$tmp"
  fi
  mv "$tmp" "$SETTINGS_FILE"
}

mkdir -p "$(dirname "$SETTINGS_FILE")"
if command -v node &>/dev/null; then
  merge_with_node
elif command -v jq &>/dev/null; then
  merge_with_jq
else
  echo "  WARNING: Neither node nor jq found. Please add Playwright MCP config manually." >&2
fi
echo "  MCP config merged."

# ------------------------------------------------------------------
# 6. Start the browser
# ------------------------------------------------------------------
echo "[6/$STEPS] Starting Chrome CDP ..."
"$INSTALL_DIR/chrome-cdp" start

# ------------------------------------------------------------------
# 7. Summary
# ------------------------------------------------------------------
echo ""
echo "[7/$STEPS] Done!"
echo ""
echo "  Installed to:   $INSTALL_DIR"
echo "  LaunchAgent:    $LAUNCH_AGENT"
echo "  Settings:       $SETTINGS_FILE"
echo "  Chrome CDP:     http://localhost:9222"
echo ""
echo "  Chrome will auto-start on login via LaunchAgent."
echo "  Manage manually: ~/.claude/browser-use/chrome-cdp {start|stop|status|restart}"
