# Mini PC Setup Guide

Target hardware: Intel Celeron, 2 cores, 8 GB RAM, no GPU, Debian/Ubuntu-based Linux.

## Architecture

```
OpenCode (native or in agent container)
    ↓
Optional LiteLLM proxy (explicit gateway mode)
    ↓
External Hermes API (remote machine, via Tailscale or LAN)
```

No local model weights. No GPU required. The machine is a thin agent runner.

## Prerequisites

- Docker + Docker Compose v2 installed
- SSH access from your build machine to the mini PC
- A configured agent provider; external Hermes API URL/key only for optional gateway mode

## Option A — Docker setup (recommended)

### 1. Build and transfer images from your fast machine

```bash
# On the build machine
MINI_HOST=user@mini-pc-ip ./scripts/push-images-to-mini.sh
```

After Tailscale is configured:

```bash
MINI_HOST=user@mini-pc.tailnet ./scripts/push-images-to-mini.sh
```

### 2. Configure environment on the mini PC

```bash
cd deploy/mini
cp .env.example .env
# Edit .env: choose native provider login or explicitly configure an API endpoint.
# Optional gateway only: set HERMES_API_URL, HERMES_API_KEY, LITELLM_MASTER_KEY
```

### 3. Start services

```bash
# From deploy/mini/
docker compose up -d

# Verify all containers are healthy
docker compose ps
docker compose logs -f agent
```

If explicitly enabled, LiteLLM is available through nginx at `http://127.0.0.1:8088/api/litellm`.

### 4. Attach to the agent container and run opencode

```bash
docker compose exec agent zsh
opencode
```

### Updating images

Re-run `push-images-to-mini.sh` from the build machine after any Dockerfile change. On the mini PC:

```bash
docker compose down
# (images already loaded by push-images-to-mini.sh)
docker compose up -d
```

## Option B — Native setup (no Docker)

Use when Docker overhead is unacceptable or a tool needs direct hardware access.

```bash
./setup-native.sh
```

This installs: zsh, oh-my-zsh, neovim, btop, ranger, and opencode. It writes a provider-neutral OpenCode config. Configure your provider with `opencode auth login`; no gateway is required.

## RAM budget

| Service | Limit |
|---------|-------|
| nginx | 64 MB |
| litellm | 768 MB |
| agent | 1 GB |
| **Total containers** | **~1.8 GB** |
| OS + native tools | ~2–3 GB |
| **Free headroom** | **~3–4 GB** |

## Ports

| Port | Service |
|------|---------|
| 127.0.0.1:8088 | nginx (reverse proxy) |
| Docker network only: litellm:4000 | Optional LiteLLM API |

Access via SSH tunnel (`ssh -L 8088:127.0.0.1:8088 user@mini-pc`) or Tailscale.

## Image variants

LiteLLM uses `docker/litellm/Dockerfile.slim` (Debian bookworm-slim) in this stack. An Alpine variant (`Dockerfile.alpine`) exists as an experimental fallback but is not the default because LiteLLM's Python dependencies require glibc binary wheels.

## Optional gateway

Default `docker compose up -d` starts nginx and the agent. Configure a provider
using OpenCode login. To use the local gateway explicitly:

```sh
docker compose --profile onlineagents up -d litellm
```

Then configure OpenCode with the provider snippet in [LiteLLM](../../docs/LITELLM.md).
The mini gateway has no PostgreSQL or virtual-key store; use its configured local
key for this minimal deployment. No agent key or endpoint is assigned automatically.

## Troubleshooting

**LiteLLM fails to start** — check `HERMES_API_URL` and `HERMES_API_KEY` in `.env`. LiteLLM logs: `docker compose logs litellm`.

**opencode cannot reach LiteLLM** — verify the agent's `OPENAI_BASE_URL=http://litellm:4000/v1` and that LiteLLM is healthy: `docker compose exec agent curl -s http://litellm:4000/health`.

**Out of memory** — check `docker stats`. The compose file enforces memory limits; if a container is OOM-killed, reduce its limit or close other processes on the host.
