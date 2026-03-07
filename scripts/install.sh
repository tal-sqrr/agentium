#!/bin/bash
set -euo pipefail

# Agentium installer — sets up persistent Chrome CDP for AI agents.
# Works when run from the skill directory (bundled via npx skills add)
# or from the repo root.
#
# Usage: install.sh [--claude] [--codex] [--cursor] [--windsurf] [--amp] [--all] [--skip-mcp]
#   No flags = interactive prompt to choose agents

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="$HOME/.agentium"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.agentium.chrome-cdp.plist"
PW_CACHE="$HOME/Library/Caches/ms-playwright"

STEPS=7

# --- Parse flags ---
AGENTS=()
SKIP_MCP=false
INTERACTIVE=true

for arg in "$@"; do
  case "$arg" in
    --claude)   AGENTS+=("claude");   INTERACTIVE=false ;;
    --codex)    AGENTS+=("codex");    INTERACTIVE=false ;;
    --cursor)   AGENTS+=("cursor");   INTERACTIVE=false ;;
    --windsurf) AGENTS+=("windsurf"); INTERACTIVE=false ;;
    --amp)      AGENTS+=("amp");      INTERACTIVE=false ;;
    --all)      AGENTS+=("all");      INTERACTIVE=false ;;
    --skip-mcp) SKIP_MCP=true;        INTERACTIVE=false ;;
    --help|-h)
      echo "Usage: install.sh [--claude] [--codex] [--cursor] [--windsurf] [--amp] [--all] [--skip-mcp]"
      echo "  No flags = interactive prompt"
      exit 0 ;;
  esac
done

# ------------------------------------------------------------------
# 1. Copy core files
# ------------------------------------------------------------------
echo "[1/$STEPS] Copying core files to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# Resolve source directories — support both skill dir and repo root layouts
if [ -d "$SKILL_DIR/src" ]; then
  SRC_DIR="$SKILL_DIR/src"
  ASSETS_DIR="$SKILL_DIR/assets"
elif [ -d "$SKILL_DIR/../src" ]; then
  SRC_DIR="$(cd "$SKILL_DIR/.." && pwd)/src"
  ASSETS_DIR="$(cd "$SKILL_DIR/.." && pwd)/assets"
else
  echo "ERROR: Cannot find src/ directory relative to install.sh" >&2
  exit 1
fi

cp "$SRC_DIR/chrome-cdp"          "$INSTALL_DIR/chrome-cdp"
cp "$SRC_DIR/nofocus.m"           "$INSTALL_DIR/nofocus.m"
cp "$ASSETS_DIR/chrome-icon.svg"  "$INSTALL_DIR/chrome-icon.svg"
cp "$ASSETS_DIR/chrome-icon.icns" "$INSTALL_DIR/chrome-icon.icns"
cp "$SCRIPT_DIR/uninstall.sh"     "$INSTALL_DIR/uninstall.sh"
chmod +x "$INSTALL_DIR/chrome-cdp"
chmod +x "$INSTALL_DIR/uninstall.sh"

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
    <string>com.agentium.chrome-cdp</string>
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
    <string>/tmp/agentium.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/agentium.log</string>
</dict>
</plist>
PLIST

launchctl load "$LAUNCH_AGENT"
echo "  LaunchAgent loaded."

# ------------------------------------------------------------------
# 5. Configure Playwright MCP
# ------------------------------------------------------------------
echo "[5/$STEPS] Configuring Playwright MCP ..."

MCP_COMMAND="npx"
MCP_ARGS='["@playwright/mcp@latest","--cdp-endpoint","http://localhost:9222"]'
MCP_ENV='{"PLAYWRIGHT_MCP_CDP_ENDPOINT":"http://localhost:9222"}'

# Agent registry: key -> "Display Name|config path"
declare -A AGENT_REGISTRY=(
  [claude]="Claude Code|$HOME/.claude/settings.json"
  [codex]="Codex|$HOME/.codex/config.toml"
  [cursor]="Cursor|$HOME/.cursor/mcp.json"
  [windsurf]="Windsurf|$HOME/.codeium/windsurf/mcp_config.json"
  [amp]="Amp|$HOME/.amp/mcp.json"
)
AGENT_ORDER=(claude codex cursor windsurf amp)

# Detect which agents are installed
declare -a DETECTED=()
for key in "${AGENT_ORDER[@]}"; do
  config_path="${AGENT_REGISTRY[$key]#*|}"
  config_dir="$(dirname "$config_path")"
  [ -d "$config_dir" ] && DETECTED+=("$key")
done

# Resolve which agents to configure
declare -a SELECTED=()

if [ "$SKIP_MCP" = true ]; then
  echo "  Skipped (--skip-mcp)."
elif [ ${#AGENTS[@]} -gt 0 ]; then
  # Flags provided
  for a in "${AGENTS[@]}"; do
    if [ "$a" = "all" ]; then
      SELECTED=("${DETECTED[@]}")
      break
    elif [ -n "${AGENT_REGISTRY[$a]+x}" ]; then
      SELECTED+=("$a")
    else
      echo "  WARNING: Unknown agent '$a', skipping." >&2
    fi
  done
elif [ "$INTERACTIVE" = true ] && [ -t 0 ]; then
  # Interactive prompt
  if [ ${#DETECTED[@]} -eq 0 ]; then
    echo "  No supported agents detected."
  else
    echo ""
    echo "  Detected agents:"
    for i in "${!DETECTED[@]}"; do
      key="${DETECTED[$i]}"
      name="${AGENT_REGISTRY[$key]%%|*}"
      path="${AGENT_REGISTRY[$key]#*|}"
      echo "    $((i+1))) $name ($path)"
    done
    echo "    a) All of the above"
    echo "    s) Skip — I'll configure MCP myself"
    echo ""
    read -rp "  Configure MCP for [1-${#DETECTED[@]}/a/s]: " choice

    case "$choice" in
      a|A) SELECTED=("${DETECTED[@]}") ;;
      s|S) ;;
      *)
        # Support comma-separated numbers like "1,3"
        IFS=',' read -ra picks <<< "$choice"
        for p in "${picks[@]}"; do
          p="$(echo "$p" | tr -d ' ')"
          if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le ${#DETECTED[@]} ]; then
            SELECTED+=("${DETECTED[$((p-1))]}")
          fi
        done
        ;;
    esac
  fi
else
  # Non-interactive, no flags — configure all detected
  SELECTED=("${DETECTED[@]}")
fi

merge_mcp_config() {
  local config_file="$1"
  mkdir -p "$(dirname "$config_file")"

  if command -v node &>/dev/null; then
    node -e "
const fs = require('fs');
const path = '$config_file';
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
  elif command -v jq &>/dev/null; then
    local tmp
    tmp="$(mktemp)"
    if [ -f "$config_file" ]; then
      jq --argjson args "$MCP_ARGS" \
         --argjson env "$MCP_ENV" \
         '.mcpServers.playwright = {command: "npx", args: $args, env: $env}' \
         "$config_file" > "$tmp"
    else
      jq -n --argjson args "$MCP_ARGS" \
            --argjson env "$MCP_ENV" \
            '{mcpServers: {playwright: {command: "npx", args: $args, env: $env}}}' > "$tmp"
    fi
    mv "$tmp" "$config_file"
  else
    echo "  WARNING: Neither node nor jq found." >&2
    return 1
  fi
}

configure_codex() {
  # MCP via CLI
  codex mcp remove playwright 2>/dev/null || true
  codex mcp add playwright \
    --env "PLAYWRIGHT_MCP_CDP_ENDPOINT=http://localhost:9222" \
    -- npx @playwright/mcp@latest --cdp-endpoint http://localhost:9222
  echo "  ✓ Codex MCP (codex mcp add)"

  # Find SKILL.md — bundled layout has it at SKILL_DIR/SKILL.md,
  # repo root layout has it at SKILL_DIR/skills/agentium/SKILL.md
  local skill_md=""
  if [ -f "$SKILL_DIR/SKILL.md" ]; then
    skill_md="$SKILL_DIR/SKILL.md"
  elif [ -f "$SKILL_DIR/skills/agentium/SKILL.md" ]; then
    skill_md="$SKILL_DIR/skills/agentium/SKILL.md"
  fi

  if [ -n "$skill_md" ]; then
    local codex_skill_dir="$HOME/.codex/skills/agentium"
    mkdir -p "$codex_skill_dir"
    cp "$skill_md" "$codex_skill_dir/SKILL.md"
    echo "  ✓ Codex skill ($codex_skill_dir)"
  fi
}

if [ ${#SELECTED[@]} -gt 0 ]; then
  for key in "${SELECTED[@]}"; do
    name="${AGENT_REGISTRY[$key]%%|*}"
    path="${AGENT_REGISTRY[$key]#*|}"
    if [ "$key" = "codex" ]; then
      configure_codex
    elif merge_mcp_config "$path"; then
      echo "  ✓ $name ($path)"
    fi
  done
elif [ "$SKIP_MCP" != true ]; then
  echo "  No agents configured. Add the Playwright MCP config manually to your agent:"
  echo "    { \"mcpServers\": { \"playwright\": { \"command\": \"npx\", \"args\": $MCP_ARGS } } }"
fi

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
echo "  Chrome CDP:     http://localhost:9222"
echo ""
echo "  Chrome will auto-start on login via LaunchAgent."
echo "  Manage manually: ~/.agentium/chrome-cdp {start|stop|status|restart}"
