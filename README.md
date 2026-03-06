# Agentium

Persistent Chrome browser for AI agents. A shared Chromium instance with CDP that multiple agent sessions connect to via Playwright MCP.

## Features

- **Shared browser** -- multiple agent sessions use one Chrome instance via CDP on port 9222
- **Focus suppression** -- injected dylib prevents Chrome from stealing window focus
- **Custom branding** -- "Chrome for Claude" name and icon, auto-heals after Playwright updates
- **Auto-start** -- LaunchAgent starts the browser on login
- **Persistent profile** -- cookies, sessions, and history survive restarts

## Install

### As a skill (recommended)

```bash
npx skills add tal-sqrr/agentium
```

Then run the system setup:

```bash
git clone https://github.com/tal-sqrr/agentium.git /tmp/agentium && /tmp/agentium/scripts/install.sh && rm -rf /tmp/agentium
```

### Manual

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
git clone https://github.com/tal-sqrr/agentium.git /tmp/agentium && /tmp/agentium/scripts/uninstall.sh && rm -rf /tmp/agentium
```

## License

MIT
