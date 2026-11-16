# RemoteLLM

Docker Compose workspace for running coding agents (OpenCode, Claude Code, Codex, Hermes, Pi, jcode) with native provider login or an optional LiteLLM gateway, with a browser IDE and terminal. Model backends are pluggable: Anthropic's API, a CPU-only local model (BitNet), or your own remote Ollama instance — reached directly or, if it's privately hosted, through an optional WireGuard tunnel that keeps the host machine off the VPN. None of the model backends are required to get started; pick whichever fits your hardware and accounts.

New to this project? Start with [Getting Started](docs/GETTING_STARTED.md) — it walks through what the stack is, why the VPN piece exists, and which tools are mandatory versus optional.

## Documentation

- [Getting Started](docs/GETTING_STARTED.md): a from-zero walkthrough for first-time users, plus the mandatory/optional tool matrix.
- [Setup](docs/SETUP.md): first run, `.env`, WireGuard config, build and start.
- [Architecture](docs/ARCHITECTURE.md): services, networking, volumes, proxy paths, resource requirements.
- [Operations](docs/OPERATIONS.md): useful commands, health checks, backups, updates.
- [LiteLLM](docs/LITELLM.md): model gateway setup, virtual keys, admin UI, Anthropic routing.
- [Langfuse](docs/LANGFUSE.md): what the observability profile records and how to use it.
- [Security Review](docs/SECURITY_REVIEW.md): exposure checks and hardening checklist.
- [Troubleshooting](docs/TROUBLESHOOTING.md): terminal, WireGuard, Ollama, and login issues.

## Quick Start

1. Copy `.env.example` to `.env` and set the password values (`CODE_SERVER_PASSWORD`, `TTYD_PASSWORD`, etc.):

   ```sh
   make init
   ```

   Ollama and WireGuard are both optional — leave those `.env` values as their placeholder defaults for now. See [Getting Started](docs/GETTING_STARTED.md) for how to pick a model backend.

2. Build and start:

   ```sh
   make build
   make up-ide
   ```

3. Open:

   ```text
   http://127.0.0.1:8088/
   http://127.0.0.1:8088/code/
   http://127.0.0.1:8088/terminal/
   ```

4. Enter the agent shell:

   ```sh
   make shell
   ```

5. Only if you want to route to a privately hosted Ollama instance over WireGuard: put a WireGuard client config at `volumes/wireguard/wg_confs/wg0.conf` (or set `COPY_WIREGUARD_CONFIG=1` and `WIREGUARD_SOURCE` in `.env` and rerun `make wireguard-config`), then start the tunnel with `make up-vpn`. See [WireGuard](docs/guides/wireguard.md) for why this exists and how to set up your own server.

## Run an agent in any directory

After `make init` and `make build-agent`, put the launcher on your PATH:

```sh
mkdir -p "$HOME/.local/bin"
ln -s "$(pwd)/scripts/agent-here" "$HOME/.local/bin/agent-here"
```

From a project directory:

```sh
agent-here                           # interactive zsh shell
agent-here opencode                  # run an agent directly
agent-here run-pi-agent
agent-here run-jcode-agent
agent-here -m ~/Datasets:ro git status
```

The current directory mounts at `/workspace/projects/<directory-name>`. Extra mounts
default to `/workspace/mounts/<directory-name>`; use `HOST:TARGET:ro` for a custom
read-only destination. Agent configuration, history, and memory use the usual
persistent volumes. Each invocation creates a separate auto-removed container
and starts no dependency services. See [agent-here](docs/guides/agent-here.md).

## Notes

- `make up` starts the agent and nginx. Configure a provider in each agent; no model gateway is selected automatically.
- LiteLLM is optional: run `make build-onlineagents` and `make up-onlineagents`, then configure its endpoint and a scoped key explicitly. See [LiteLLM](docs/LITELLM.md).
- nginx exposes the browser terminal at `http://127.0.0.1:8088/terminal/`; use `http` unless you add TLS.
- Project code belongs in `workspace/projects`.
- Input-only material belongs in `workspace/inputs`.
- Agent state and memory live under `volumes/`.
- Use `safe-npm-install`, `safe-pip-install`, and `safe-package-check` for dependency changes.
- Continue config for the browser IDE is seeded under `volumes/vscode-config/continue`, but is not part of the maintainer's own workflow — see [Getting Started](docs/GETTING_STARTED.md#tools-present-but-unused-by-the-maintainer).
- Codex CLI, Claude Code, [Pi](docs/guides/pi.md), and [jcode](docs/guides/jcode.md) profiles are opt-in; pin their package specs in `.env` before building them.
- Hermes Agent is opt-in; set `INSTALL_HERMES_AGENT=1` and `HERMES_INSTALL_METHOD` in `.env` before building. The browser dashboard runs with `make up-hermes-web`.

## About This Project

RemoteLLM was designed and directed by a human maintainer, with implementation, refactoring, and documentation carried out with substantial assistance from Claude (Anthropic). Every change was reviewed before landing, but the bulk of the code, configuration, and docs in this repository were AI-assisted rather than written line-by-line by hand. If you spot something that looks off — a stale comment, an inconsistency between docs and behavior, an edge case that wasn't considered — please open an issue; that kind of feedback is genuinely useful for a project built this way.

## License

[MIT](LICENSE)
