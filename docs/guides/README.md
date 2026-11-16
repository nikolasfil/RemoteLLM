# Guides

One guide per application and service in the RemoteLLM stack. Each guide covers features, functionalities, limitations, and hardware requirements.

## Core Stack

| Guide | Service | Profile |
|---|---|---|
| [WireGuard](wireguard.md) | VPN tunnel + SOCKS5 proxy | opt-in with `make up-vpn` |
| [Nginx](nginx.md) | Reverse proxy and browser entry point | always on |
| [LiteLLM](litellm.md) | OpenAI-compatible model gateway | always on |
| [Agent](agent.md) | Base development container (zsh, tools, workspace) | always on |

## Browser Tools

| Guide | Service | Profile |
|---|---|---|
| [Code-Server](code-server.md) | Browser VS Code IDE | `ide` |
| [Web Terminal](web-terminal.md) | Browser terminal (ttyd) | `web-terminal` |
| [Continue](continue.md) | AI autocomplete and chat extension for code-server | extension inside `ide` |

## Agent CLIs

| Guide | Service | Profile |
|---|---|---|
| [OpenCode](opencode.md) | Default AI coding agent (pre-installed) | always on (runs inside `agent`) |
| [Claude Code](claude-code.md) | Anthropic Claude Code CLI | `claude` (opt-in build) |
| [Codex](codex.md) | OpenAI Codex CLI | `codex` (opt-in build) |
| [Hermes](hermes.md) | Nous Research Hermes autonomous agent + web dashboard | `hermes`, `hermes-web` (opt-in build) |

## Optional Services

| Guide | Service | Profile |
|---|---|---|
| [Langfuse](langfuse.md) | LLM observability and trace browser | `observability` |
| [BitNet](bitnet.md) | CPU-only local inference (GPU-free fallback) | `cpu-llm` |
| [Playwright](playwright.md) | Browser automation via MCP | `playwright` |
| [Nix Agent](nix-agent.md) | Devbox / Nix reproducible dev environments | `nix` |

- [agent-here](agent-here.md): launch in any host project directory.
- [Pi](pi.md): optional Pi coding agent.
- [jcode](jcode.md): optional jcode CLI.
