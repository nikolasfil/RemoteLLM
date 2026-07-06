# Playwright MCP

The `playwright-mcp` service provides browser automation through the Model Context Protocol (MCP). It runs under the `playwright` Compose profile and allows agent tools to control a headless Chromium browser for visual testing, web scraping, and screenshot capture.

## Features

- Headless Chromium browser automation via MCP
- OpenAI-compatible MCP server (playwright-mcp)
- Shared workspace mounts for project files, reports, and test results
- Used by AI agents via MCP tool calls (not direct HTTP)
- No host port published by default — internal to the Docker network

## Functionalities

### Starting Playwright MCP

```sh
make up-playwright
```

The service starts under the `playwright` Compose profile. It does not publish a host port; agents access it over the `remotellm` Docker network via MCP.

### Enabling in Agent MCP Config

The Playwright MCP server must be enabled in each agent's MCP config:

**For Claude Code** — edit `config/agent/claude/mcp.json` and uncomment the playwright entry:

```json
{
  "playwright": {
    "command": "...",
    "args": ["..."]
  }
}
```

**For OpenCode** — edit `config/agent/opencode/opencode.jsonc` and enable the playwright MCP entry.

The seeded configs include the entry but have it disabled by default. Start the `playwright` profile before enabling the entry, otherwise the agent will fail to connect.

### Output Directories

| Host Path | Container Path | Purpose |
|---|---|---|
| `.local/workspace/projects` | `/workspace/projects` | Project source files |
| `.local/workspace/outputs/playwright-report` | `/workspace/outputs/playwright-report` | HTML test reports |
| `.local/workspace/outputs/test-results` | `/workspace/outputs/test-results` | Raw test result artifacts |

### Logs

```sh
docker compose logs playwright-mcp --tail=50
```

## Limitations

- **MCP-only access.** Playwright MCP is not directly callable via HTTP from agent code. Agents use it through MCP tool calls. Direct Playwright API usage requires a different setup.
- **No host port by default.** The service is intentionally isolated to the Docker network. Exposing it requires adding a `ports` mapping to `compose.yml`.
- **Must be enabled per-agent.** Each agent CLI (Claude, OpenCode, Codex) has its own MCP config. Enabling playwright in one does not enable it in others.
- **Chromium is memory-heavy.** A single browser instance uses 500 MB–2 GB. Multiple parallel browser contexts will exhaust RAM quickly on low-memory hosts.
- **No GPU acceleration.** Headless Chromium runs without GPU hardware acceleration inside the container.
- **X11/display not available.** The browser is strictly headless. Visual rendering is possible via screenshots, but no display window can be shown.

## Hardware Requirements

| Metric | Value |
|---|---|
| RAM (idle, no browser) | 512 MB |
| RAM (active browser session) | 1–2 GB |
| CPU (idle) | 0.5 cores |
| CPU (active) | up to 2 cores |

Chromium's memory usage grows with the number of open pages and DOM complexity. Start it only for projects that require browser automation.
