---
name: agentium
description: >
  Persistent Chrome browser with CDP for AI agents. Manages a shared Chromium
  instance on port 9222 that multiple agent sessions can connect to via
  Playwright MCP. Includes focus suppression, custom branding, and auto-start.
  Use when navigating websites, filling forms, taking screenshots, or any
  browser automation.
metadata:
  author: tal-sqrr
  version: 1.0.0
  license: MIT
allowed-tools: Bash(~/.claude/browser-use/*:*)
---

# Agentium -- Persistent Browser for Agents

## Auto-Setup

Before doing anything else, check if agentium is installed:

```bash
test -x ~/.claude/browser-use/chrome-cdp && echo "installed" || echo "not installed"
```

If **not installed**, find and run the bundled install script:

```bash
SKILL_DIR="$(find ~/.claude/skills ~/.agents/skills .claude/skills .agents/skills -type d -name agentium 2>/dev/null | head -1)" && "$SKILL_DIR/scripts/install.sh"
```

This compiles the focus-suppression dylib, installs Playwright Chromium, configures
the MCP server, sets up auto-start, and launches the browser. Requires macOS and
Xcode Command Line Tools (`xcode-select --install`).

## Usage

The browser is a persistent Chrome instance with Chrome DevTools Protocol (CDP) on **port 9222**. It auto-starts on login via LaunchAgent.

**Always call `browser_new_tab` before your first navigation** to avoid overriding another session's tab.

### Managing the Browser

```bash
~/.claude/browser-use/chrome-cdp start    # Start (no-op if already running)
~/.claude/browser-use/chrome-cdp stop     # Stop
~/.claude/browser-use/chrome-cdp status   # Check if running
~/.claude/browser-use/chrome-cdp restart  # Restart
```

### How It Works

- Uses Playwright's Chromium (ad-hoc signed, allows dylib injection)
- `nofocus.dylib` suppresses Chrome from stealing window focus
- Custom icon and name ("Chrome for Claude") auto-heal after Playwright updates
- Multiple agent sessions share the same browser via CDP websocket
- Profile persists at `~/.claude/playwright-persistent/`
- Logs at `/tmp/chrome-cdp.log`

### Troubleshooting

- **Browser won't start:** Check `~/.claude/browser-use/chrome-cdp status`. If stopped, run `start`. Check `/tmp/chrome-cdp.log` for errors.
- **"Playwright Chromium not found":** Run `npx playwright install chromium`.
- **Stale singleton locks:** The script auto-removes these on start. If issues persist, manually delete `~/.claude/playwright-persistent/Singleton*`.
- **Icon/name not updated:** Run `restart` -- the script re-patches on every start.
