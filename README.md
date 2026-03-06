# Agentium

Persistent Chrome browser for AI agents. A shared Chromium instance with CDP that multiple agent sessions connect to via Playwright MCP.

## Features

- **Shared browser** -- multiple agent sessions use one Chrome instance via CDP on port 9222
- **Focus suppression** -- injected dylib prevents Chrome from stealing window focus
- **Custom branding** -- "Chrome for Claude" name and icon, auto-heals after Playwright updates
- **Auto-start** -- LaunchAgent starts the browser on login
- **Persistent profile** -- cookies, sessions, and history survive restarts

## Install

```bash
npx skills add tal-sqrr/agentium
```

That's it. The skill bundles everything — install script, source files, and assets. On first use, your agent detects it's not set up and runs the bundled installer automatically (compiles dylib, configures MCP, sets up auto-start).

### Manual install (without skills.sh)

```bash
git clone https://github.com/tal-sqrr/agentium.git
cd agentium
./scripts/install.sh
```

## Requirements

- macOS (Apple Silicon or Intel)
- Node.js (for npx / Playwright)
- Xcode Command Line Tools (`xcode-select --install`)

## Uninstall

```bash
npx skills remove agentium
```

To also remove the system components:

```bash
SKILL_DIR="$(find ~/.claude/skills ~/.agents/skills .claude/skills .agents/skills -type d -name agentium 2>/dev/null | head -1)" && "$SKILL_DIR/scripts/uninstall.sh"
```

Or from a clone:

```bash
git clone https://github.com/tal-sqrr/agentium.git /tmp/agentium && /tmp/agentium/scripts/uninstall.sh && rm -rf /tmp/agentium
```

## License

MIT
