# Agent Security

This document covers what the agent containers can and cannot do, where the real
isolation boundaries are, what can go wrong, and which controls are non-negotiable.

## What an Agent Container Is

The `agent` service (and all derived containers — `codex`, `claude`, `hermes`,
`web-terminal`, `nix-agent`) is a full Debian Bookworm environment with a writable
shell, a standard package manager, `sudo`, build tools, `curl`, `git`, and every
major AI CLI pre-installed. It is deliberately powerful. The design trade-off is
that developer ergonomics (arbitrary installs, live debugging, unrestricted workspace
writes) take priority over surface-area minimisation inside the container.

The meaningful security boundary is the **container wall**, not anything inside it.

---

## Permissions and Isolation Per Service

| Service | User | `no-new-privileges` | Read-only FS | gVisor (`runsc`) | Sudo inside |
|---|---|---|---|---|---|
| `agent` | `PUID:PGID` (1000:1000) | no | no | optional (commented) | yes, passwordless |
| `web-terminal` | `PUID:PGID` | no | no | optional (commented) | yes, passwordless |
| `codex` | `PUID:PGID` | no | no | optional (commented) | yes, passwordless |
| `claude` | `PUID:PGID` | no | no | no | yes, passwordless |
| `hermes` | `PUID:PGID` | no | no | optional (commented) | yes, passwordless |
| `nix-agent` | `PUID:PGID` | no | no | optional (commented) | yes, passwordless |
| `nginx` | root (image default) | yes | yes | no | no |
| `litellm` | root (image default) | yes | no | no | no |
| `wireguard` | root (required) | no | no | no | no |
| `vpn-proxy` | root (image default) | yes | yes | no | no |
| `code-server` | `PUID:PGID` | yes | no | no | no |
| `bitnet` | root (image default) | yes | yes | no | no |

### Why agent containers have passwordless sudo

The agent user already owns the entire `/workspace` tree and its own home directory.
Restricting `sudo` would not prevent writes to the workspace — it would only block
system-level operations that developer workflows legitimately need (package manager
installs, `apt-get`, changing file permissions). The container is a sandbox; the
`sudo` gate inside it does not add a meaningful security layer because anyone with a
shell inside the container already controls everything the agent user can reach.

Restricting or removing sudo is worth doing if untrusted users share the web terminal.

### wireguard has `NET_ADMIN` and runs as root

`NET_ADMIN` is required by the WireGuard kernel module. It cannot be dropped. This
service should never have any other capability added, and it must never share network
namespace with untrusted services.

### No Docker socket mount

No service mounts `/var/run/docker.sock`. Mounting the Docker socket gives a container
full root on the host. The `security-review` script blocks this and flags it as an error.

---

## What the Agent Can Reach

### Filesystem

| Path | Access | Notes |
|---|---|---|
| `/workspace/projects` | read-write | Shared with all agent variants |
| `/workspace/inputs` | read-only | Source material only |
| `/workspace/outputs` | read-write | Results, reports, exports |
| `/workspace/.aide` | read-write | Agent memory and MCP state |
| `/home/agent` | read-write | Shell history, config, transcripts, credentials cached by CLIs |
| Host filesystem outside mounts | none | Docker volume isolation |

The host filesystem is not accessible. An agent cannot escape to the host through the
filesystem unless an additional bind-mount is added to `compose.yml`.

### Network

All agent containers are on the `remotellm` Docker bridge network. From inside the
container, the agent can reach:

- `litellm:4000` — LiteLLM API (intended, authenticated by virtual key)
- `nginx:8080` — inner nginx (unintended but low risk)
- `code-server:8080` — browser IDE API (unintended, no auth at the network layer)
- `wireguard:11434` — the VPN-side Ollama forward port (via `vpn-proxy`)
- Any host service reachable from the Docker bridge (`172.x.x.1` range by default)
- The internet, via the host's default route

The agent has **full outbound internet access** by default. This is intentional for
package installs, `git clone`, and API calls — but it means a compromised or
misbehaving agent can exfiltrate data and make arbitrary external requests.

### LiteLLM Key

When explicitly configured for LiteLLM, the agent authenticates with
`OPENAI_API_KEY`. No key is assigned by default and there is no master-key fallback. Using a scoped virtual key
(`make litellm-keys`) limits the agent to specific models and rate limits. Using the
master key gives the agent full admin access to LiteLLM, including the ability to
generate new keys, view spend, and modify configuration.

**The master key must never be used as the agent's runtime key.**

---

## What Can Go Wrong

### Prompt injection / tool poisoning

An agent reading a file, web page, or repository controlled by a third party can be
instructed to run arbitrary shell commands via injected text that looks like a user
instruction. Because the agent has a live shell with `sudo`, the injected command
executes immediately.

Mitigations already in place:
- `AGENTS.md` instructs agents not to auto-run unreviewed `.envrc`, Nix flakes, or shell hooks.
- `safe-dev-env-check` scans project directories for hook files before activation.
- `safe-npm-install` and `safe-pip-install` route installs through Socket.dev and pip-audit.
- MCP servers are opt-in and pinned (see `docs/dev/mcp-policy.md`).

Mitigations that depend on the agent's behaviour:
- These are soft controls. A sufficiently injected instruction can override them.

### Credential leakage via agent home

The agent home (`/home/agent`) is a persistent Docker volume. It accumulates:
- Shell history (`.zsh_history`) containing commands, URLs, and sometimes secrets
- AI CLI transcripts (`.claude/`, `.codex/`, `.hermes/`) containing full conversation context
- Cached tokens and config files written by CLIs

If this volume is backed up, shared, or inspected by a third party, those credentials
are exposed. **Review `.local/volumes/agent-home/` before sharing any backup.**

### Agent calls the LiteLLM API as admin

If a user explicitly configures `LITELLM_MASTER_KEY` as the agent key, the
agent can enumerate virtual keys, generate new ones, delete models, and view full spend
history through the LiteLLM admin API. This is the single most important credential
control.

### Web terminal gives any authenticated browser user a live shell

`ttyd` runs with `-W` (writable mode). Anyone who authenticates with `TTYD_PASSWORD`
gets a full shell with `sudo`. If `TTYD_PASSWORD=change-me` is left in place, the
`security-review` script blocks the stack from starting.

### Unrestricted outbound network

The agent can `curl` any URL, `git clone` any repository, and exfiltrate `/workspace`
contents to any external service. A prompt-injected agent that has been given a file
containing exfiltration instructions will comply. gVisor (`runsc`) can reduce but does
not eliminate this risk.

### Docker bridge access to other services

From inside the agent container, `curl http://nginx:8080/` and
`curl http://code-server:8080/` are reachable. Code-server has no network-layer auth
when accessed from within the Docker network — the password gate is only at the nginx
proxy. An agent that discovers these addresses can make arbitrary requests to them.

---

## Controls That Must Be Ironclad

These are the controls where a mistake has direct, serious consequences and cannot be
undone by restarting a container.

### 1. Never use `LITELLM_MASTER_KEY` as the agent's API key

For optional LiteLLM routing, create scoped keys via `make litellm-keys` and
configure the selected key in each agent explicitly. The master key must only be held by the
operator (in `.env`) and the LiteLLM service itself.

### 2. Do not mount `/var/run/docker.sock`

Mounting the Docker socket gives an agent root on the host. The `security-review`
script treats this as a hard error.

### 3. Change all default passwords before any LAN or remote exposure

These must be changed before setting `NGINX_BIND=0.0.0.0` or opening the stack to any
network that is not `127.0.0.1`:

- `CODE_SERVER_PASSWORD`
- `TTYD_PASSWORD`
- `LITELLM_MASTER_KEY`
- `LITELLM_SALT_KEY` (set once; do not change after first boot)
- `LITELLM_UI_PASSWORD`
- `LITELLM_DB_PASSWORD`

Run `make security-review` to verify none of these are at their placeholder values.

### 4. Keep WireGuard config at `0600`

The WireGuard private key is stored in `.local/volumes/wireguard/wg_confs/wg0.conf`.
This file must be readable only by root (`chmod 600`). The `security-review` script
checks this. A readable private key allows anyone with host filesystem access to
impersonate the VPN peer.

### 5. Do not add extra `cap_add` to agent containers

The agent containers have no Linux capabilities beyond the default Docker set. Adding
`CAP_NET_ADMIN`, `CAP_SYS_ADMIN`, `SYS_PTRACE`, etc. to an agent container is a
significant escalation. Only `wireguard` has `NET_ADMIN`, and only because the kernel
module requires it.

### 6. Pin optional CLI packages before enabling them

`INSTALL_CODEX_CLI`, `INSTALL_CLAUDE_CODE`, and `INSTALL_HERMES_AGENT` are disabled
by default. When enabling, always set the corresponding `*_PACKAGE` or `*_VERSION`
variable to a specific pinned version. The Dockerfile enforces this and will fail the
build if the version is omitted.

---

## Optional Hardening

These are not on by default because they break common developer workflows or require
host-level setup. They are worth enabling when the agent is exposed beyond localhost.

### gVisor (`runsc`) kernel isolation

Uncomment `runtime: runsc` in the `agent`, `web-terminal`, `nix-agent`, `codex`, and
`hermes` services. gVisor intercepts syscalls and prevents kernel exploits from
escaping the container. Requires host setup — see `docs/SETUP.md`.

### Replace passwordless sudo with per-command entries

Edit `/etc/sudoers.d/agent` inside the image or override with a bind-mount to limit
which commands can be run as root. Relevant if the web terminal is shared with
untrusted users.

### Restrict outbound network with `iptables` or a firewall

Block the agent's Docker bridge IP from reaching the host network or external IPs
not required for operation. This must be done at the host level; Docker networking
does not support per-container firewall rules without custom iptables rules or a
network policy controller.

### Audit agent transcripts regularly

Agent CLI transcripts in `.local/volumes/agent-home/` contain the full task history.
Review them periodically for unexpected outbound requests, credential references, or
tool calls that were not explicitly requested.
