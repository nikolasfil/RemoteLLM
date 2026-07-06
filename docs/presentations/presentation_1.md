---
marp: true
theme: default
paginate: true
size: 16:9
title: RemoteLLM Project Overview
description: Presentation deck for the RemoteLLM Docker Compose coding-agent workspace
---

<!-- _class: lead -->

# RemoteLLM

Docker Compose workspace for remote coding agents, private model access, browser tools, and local operational control.

---

## The Problem

Remote coding agents need a development environment that is:

- connected to a remote Ollama endpoint reachable only through WireGuard
- isolated from the host machine
- durable across container restarts
- usable from both terminal and browser workflows
- auditable before exposing it on a host or LAN

---

## Project Goal

RemoteLLM packages the agent workspace as a local Docker Compose stack.

It keeps the host off the VPN, routes model traffic through LiteLLM, persists agent state under `.local/`, and gives operators a repeatable way to start, inspect, and harden the system.

---

## Core Architecture

```text
Browser / shell
    |
    v
nginx -> code-server
      -> web-terminal
      -> LiteLLM API

agent / opencode / Codex / Claude
    |
    v
LiteLLM -> WireGuard SOCKS proxy -> remote Ollama
```

---

## Main Services

- `wireguard`: owns the VPN network path
- `vpn-proxy`: exposes SOCKS5 at `wireguard:1080`
- `litellm`: OpenAI-compatible model gateway
- `agent`: long-running coding-agent shell
- `nginx`: local browser entry point
- `code-server`: optional browser IDE
- `web-terminal`: optional ttyd browser terminal

---

## Optional Profiles

- `codex`: one-shot Codex CLI profile
- `claude`: one-shot Claude Code profile
- `opencode-web`: OpenCode browser UI
- `playwright`: browser automation MCP profile
- `observability`: Langfuse tracing stack
- `nix`: Devbox and Nix-enabled development profile

Optional agents are disabled by default and installed only from pinned package specs.

---

## Network Flow

Only LiteLLM uses the WireGuard proxy.

```dotenv
OLLAMA_PROXY=socks5h://wireguard:1080
OPENAI_BASE_URL=http://litellm:4000/v1
NO_PROXY=localhost,127.0.0.1,agent,nginx,code-server,litellm,wireguard
```

Package managers, Git, and normal development tooling stay on the host network path unless explicitly configured otherwise.

---

## Local Browser Entry Points

nginx exposes the stack from one local port:

- `/` project landing page
- `/code/` browser IDE
- `/terminal/` browser terminal
- `/api/litellm/` LiteLLM API proxy

The default binding is local-only: `127.0.0.1:${NGINX_PORT:-8088}`.

---

## Persistent State

Runtime data is generated under `.local/` and ignored by git.

- `.local/workspace/projects`: editable project code
- `.local/workspace/inputs`: read-only input material
- `.local/workspace/outputs`: generated outputs
- `.local/volumes/agent-home`: shell and agent home
- `.local/volumes/*-home`: per-agent state
- `.local/volumes/aide-memory`: shared local memory

---

## Agent Environment

The agent image includes:

- zsh, tmux, Git, build tools, Python, Node, and common CLI utilities
- opencode by default
- optional Codex CLI and Claude Code builds
- Neovim and seeded editor config
- mise for runtime pinning
- package safety tools for npm, pip, and multi-ecosystem scans

---

## Dependency Guardrails

RemoteLLM treats agent-driven dependency changes as a supply-chain risk.

Included tools:

- `safe-package-check`
- `safe-npm-install`
- `safe-pip-install`
- `pip-audit`
- `osv-scanner`
- `scorecard`

The default workflow is to check before adding dependencies from inside the agent.

---

## Security Posture

Security is based on container boundaries, local binding, explicit profiles, and review commands.

- host does not join the WireGuard VPN
- writable shell services can use gVisor `runsc`
- non-shell services use `no-new-privileges:true`
- Docker socket is not mounted into agent containers
- browser tools default to localhost
- secrets and runtime state stay in `.local/`

---

## Security Review Workflow

```sh
make security-review
```

The review checks for:

- placeholder credentials
- accidental LAN exposure
- Docker socket mounts
- missing privilege restrictions
- missing `runsc` isolation on shell services
- missing or loose WireGuard config permissions

---

## Observability

Langfuse is an optional profile connected through LiteLLM callbacks.

```text
agent / Continue / opencode / Codex / Claude
        |
        v
LiteLLM
   |        \
   v         v
Ollama     Langfuse traces
```

It records model names, latency, token counts, request metadata, failures, and trace history.

---

## Developer Workflow

```sh
make init
make build
make up-ide
make shell
```

Then:

- use `/code/` for browser IDE work
- use `/terminal/` or `make shell` for shell work
- run `make agent` for opencode
- run optional profiles only after enabling them in `.env`

---

## Operations

Common operational commands:

```sh
make ps
make logs
make test-vpn
make backup
make down
```

Persistent volumes and outputs can be backed up with `make backup`.

---

## Current Roadmap

Planned extensions:

- BitNet CPU inference profile for GPU-free local fallback
- Obsidian second-brain profile for persistent knowledge capture
- continued hardening of MCP and browser automation profiles
- cleaner smoke tests for first-run setup and optional profiles

---

## Why It Matters

RemoteLLM gives coding agents a controlled workspace that separates:

- host access from container access
- model routing from development traffic
- committed configuration from machine-local state
- default workflows from optional higher-risk capabilities

The result is a reproducible agent environment that can be operated, audited, and extended deliberately.

