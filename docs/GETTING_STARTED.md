# Getting Started

This is the entry point for anyone new to RemoteLLM. It explains what the stack is, why
the VPN piece exists, which tools are required versus optional, and which optional tools
the maintainer built but doesn't personally rely on. If you already know the stack and
just need setup steps, go straight to [Setup](SETUP.md).

## What Is RemoteLLM?

RemoteLLM is a Docker Compose workspace that gives you a browser-based coding
environment (IDE + terminal) wired up to one or more AI coding agents (OpenCode,
Claude Code, Codex, Hermes), all routed through a single model gateway (LiteLLM). It
exists to solve one problem: running an AI coding agent needs somewhere to send model
requests, and you may want that "somewhere" to be a model you host yourself rather than
a third-party API — without turning your whole development machine into a VPN client
or exposing anything to the open internet.

Everything runs in containers on your machine. Project code, agent memory, and secrets
stay local. Only model traffic (and only the traffic for whichever backend you enable)
leaves the machine.

## Before You Start: Pick A Model Backend

The stack does not ship with a working model backend out of the box — you choose one.
None of these are mandatory; the containers build and start regardless.

| Backend | What it needs | Good for |
|---|---|---|
| **Anthropic (Claude)** | An `ANTHROPIC_API_KEY` | Simplest to start with — no hardware, no networking. |
| **BitNet (local CPU model)** | Nothing external — runs on your machine's CPU | Fully offline fallback; no accounts, no VPN, modest hardware. |
| **Your own Ollama instance** | An Ollama server (local network, or private/remote behind your own WireGuard server) | Full control over the model, larger models than BitNet supports. |

If you skip all three, the stack still starts, but agents will fail to get a model
response until you configure at least one. See [LiteLLM](LITELLM.md) and
[BitNet](guides/bitnet.md) for setup, and the section below for the Ollama+WireGuard
option specifically.

## Why WireGuard And vpn-proxy Exist

These two services only matter if your Ollama instance is **not** directly reachable —
for example, it runs on a home server behind NAT, or on a machine you don't want to
expose to the internet with an open port. The problem they solve:

- You want the agent container to reach that private Ollama instance.
- You do **not** want to put your whole development machine on a VPN — that would route
  all of its traffic (or DNS) through the tunnel, affecting everything else you run
  locally, not just the agent stack.
- You do **not** want to expose Ollama's HTTP port to the public internet just so a
  container can reach it.

The `wireguard` container joins the VPN *instead of your host*, and `vpn-proxy` exposes
that tunnel as a plain address (`wireguard:11434`) and a SOCKS5 proxy
(`wireguard:1080`) on the internal Docker network only. Only LiteLLM's Ollama traffic
uses this path — everything else (git, npm, pip, the browser IDE) still uses your
normal internet connection directly. Both containers stay off unless you run
`make up-vpn`.

If your Ollama instance is already reachable directly (same LAN, or you don't mind
exposing it), you don't need any of this — just point `OLLAMA_BASE_URL` at it and
never touch the `vpn` profile. Full details, including how to set up your own WireGuard
server if you don't have one, are in the [WireGuard guide](guides/wireguard.md).

## First Run, Step By Step

For someone who has never touched this repository before:

1. **Install prerequisites**: Docker with Compose v2. Optionally, gVisor (`runsc`) for
   stronger container isolation — see [Setup](SETUP.md#gvisor-runtime) if you want it;
   it's not required to get running.
2. **Initialize the repo**:
   ```sh
   make init
   ```
   This creates `.env` from `.env.example` and the runtime directories under `.local/`.
3. **Edit `.env`** and change every `change-me` password
   (`CODE_SERVER_PASSWORD`, `TTYD_PASSWORD`, `LITELLM_MASTER_KEY`, `LITELLM_SALT_KEY`,
   `LITELLM_DB_PASSWORD`, `LITELLM_UI_PASSWORD`, `DEV_PASSWORD`). Leave the Ollama and
   WireGuard sections as their defaults for now — see the model backend section above.
4. **Build and start the core stack plus the browser IDE**:
   ```sh
   make build
   make up-ide
   ```
5. **Open the browser IDE and terminal**:
   ```text
   http://127.0.0.1:8088/
   http://127.0.0.1:8088/code/
   http://127.0.0.1:8088/terminal/
   ```
6. **Or enter a shell directly**:
   ```sh
   make shell
   ```
   Inside, `opencode` is pre-installed and ready to use once a model backend is
   configured (step 3 in the previous section).
7. **Only if you're using a privately hosted Ollama over your own VPN**, follow
   [WireGuard](guides/wireguard.md), then start the tunnel with `make up-vpn`.

From here, [Setup](SETUP.md) covers every option in depth, and
[Operations](OPERATIONS.md) covers day-to-day commands.

## Tool Matrix: Mandatory vs Optional

**Mandatory** — always part of the stack, start with plain `make up`:

| Tool | Role |
|---|---|
| `nginx` | Single browser entry point; reverse-proxies everything else |
| `litellm` + `litellm-postgres` | Model gateway; every agent and IDE tool routes through it |
| `agent` | The base coding-agent container; OpenCode is pre-installed inside it |

**Optional — pick a model backend** (at least one, or agents have nothing to call):

| Tool | Enable with |
|---|---|
| Anthropic (Claude) | Set `ANTHROPIC_API_KEY` in `.env` |
| BitNet (local CPU model) | `make download-bitnet-model` then `make up-cpu-llm` |
| Remote Ollama | Set `OLLAMA_BASE_URL`; add WireGuard (below) if it's private |

**Optional — browser tools**:

| Tool | Enable with |
|---|---|
| Code-Server (browser IDE) | included in `make up-ide` |
| Web Terminal (ttyd) | included in `make up-ide` |
| Continue (IDE autocomplete/chat) | pre-seeded config inside code-server; see note below |

**Optional — agent CLIs** (opt-in build, require a pinned package version in `.env`):

| Tool | Enable with |
|---|---|
| Claude Code | `INSTALL_CLAUDE_CODE=1` + `CLAUDE_CODE_PACKAGE`, rebuild, `make claude` |
| Codex CLI | `INSTALL_CODEX_CLI=1` + `CODEX_CLI_PACKAGE`, rebuild, `make codex` |
| Hermes Agent | `INSTALL_HERMES_AGENT=1` + install method, rebuild, `make hermes` / `make up-hermes-web` |

**Optional — everything else**:

| Tool | Enable with |
|---|---|
| WireGuard + vpn-proxy | `make up-vpn` (see "Why WireGuard" above) |
| Nix Agent (Devbox/Nix envs) | `make up-nix` |
| Playwright MCP | `make up-playwright` |
| Langfuse (observability) | `make up-observability`; see note below |

See [`docs/guides/README.md`](guides/README.md) for the full per-tool guide index with
features, limitations, and hardware requirements.

## Tools Present But Unused By The Maintainer

A few integrations are fully implemented and documented, but the maintainer does not
run them day-to-day — they were built for completeness or as an experiment, not because
they're part of the primary workflow. They should work as documented, but they get less
real-world mileage than the core path, so treat them as community-supported extras:
expect to do more of your own troubleshooting, and please file an issue if something's
off.

- **Langfuse** (`observability` profile) — full tracing stack for LiteLLM requests.
  Heavier than the rest of the stack (ClickHouse alone wants 1–3 GB RAM). Works, but
  the maintainer relies on `make logs` for visibility instead of running this.
- **BitNet** (`cpu-llm` profile) — CPU-only local inference. Useful as a genuinely
  offline fallback, but the maintainer's daily driver is Anthropic or a remote Ollama
  model, not BitNet.
- **Continue** (the code-server IDE extension, paired with LiteLLM) — seeded and wired
  to the `ollama-default` alias, but the maintainer primarily uses the agent CLIs
  (OpenCode, Claude Code) rather than in-editor autocomplete/chat.

Everything else in the tool matrix above — including WireGuard, the other agent CLIs,
Hermes, and Playwright — is actively used and maintained.

## Where To Go Next

- [Setup](SETUP.md) — every configuration option in depth.
- [Architecture](ARCHITECTURE.md) — services, networking, volumes, resource sizing.
- [Guides index](guides/README.md) — one focused guide per tool.
- [Troubleshooting](TROUBLESHOOTING.md) — symptom-based fixes.
