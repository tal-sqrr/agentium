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
allowed-tools: Bash(~/.agentium/*:*)
---

# Agentium -- Persistent Browser for Agents

## Prerequisites

Before using this skill, agentium must be installed. Check status:

```bash
~/.agentium/chrome-cdp status
```

If the command is not found, run the bundled install script:

```bash
./scripts/install.sh
```

Requires macOS and Xcode Command Line Tools (`xcode-select --install`).

## Usage

The browser is a persistent Chrome instance with Chrome DevTools Protocol (CDP) on **port 9222**. It auto-starts on login via LaunchAgent.

**Always call `browser_new_tab` before your first navigation** to avoid overriding another session's tab.

### Managing the Browser

```bash
~/.agentium/chrome-cdp start    # Start (no-op if already running)
~/.agentium/chrome-cdp stop     # Stop
~/.agentium/chrome-cdp status   # Check if running
~/.agentium/chrome-cdp restart  # Restart
```

### How It Works

- Uses Playwright's Chromium (ad-hoc signed, allows dylib injection)
- `nofocus.dylib` suppresses Chrome from stealing window focus
- Custom icon and name ("Chrome for Claude") auto-heal after Playwright updates
- Multiple agent sessions share the same browser via CDP websocket
- Profile persists at `~/.agentium/chrome-profile/`
- Logs at `/tmp/agentium.log`

### Troubleshooting

- **Browser won't start:** Check `~/.agentium/chrome-cdp status`. If stopped, run `start`. Check `/tmp/agentium.log` for errors.
- **"Playwright Chromium not found":** Run `npx playwright install chromium`.
- **Stale singleton locks:** The script auto-removes these on start. If issues persist, manually delete `~/.agentium/chrome-profile/Singleton*`.
- **Icon/name not updated:** Run `restart` -- the script re-patches on every start.
