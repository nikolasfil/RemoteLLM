# Full Stack Deploy

The full stack lives at the repository root: `compose.yml`.

## Hardware requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 16 GB | 32 GB |
| GPU | optional (CPU-only Ollama is slow) | NVIDIA GPU with ≥8 GB VRAM |
| OS | Linux | Linux |

## Quick start

```bash
cp .env.example .env
# From the repository root: edit .env passwords; choose a provider in the agent.
make init
make build-agent
make up
```

See `docs/SETUP.md` for full instructions, WireGuard setup, and service configuration.

## Services

| Service | Purpose |
|---------|---------|
| wireguard | VPN tunnel to remote Ollama host |
| vpn-proxy | SOCKS5 proxy inside the WireGuard network |
| litellm | Optional model gateway (`onlineagents` profile) |
| litellm-postgres | Optional gateway state store (`onlineagents` profile) |
| nginx | Reverse proxy with browser IDE and terminal |
| agent | Main coding agent container (opencode, zsh, nvim) |
| langfuse-* | Observability stack (optional `observability` profile) |
| playwright-mcp | Browser automation MCP server (optional `playwright` profile) |

## Optional services

`make up` starts only the agent and nginx. Pi and jcode are opt-in builds with
`make pi` / `make jcode` launch targets. LiteLLM requires `make build-onlineagents`
and `make up-onlineagents`, followed by explicit agent provider configuration.
The `compose.yml` here mirrors the root variant; use the root checkout for Make
commands and the shared Dockerfiles/configuration.

## Choosing between full and mini

Use the full stack when you have a GPU-equipped machine or a remote Ollama endpoint accessible over WireGuard. Use the mini stack when you are deploying to a low-power machine and routing LLM calls through an external API key.
