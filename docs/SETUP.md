# Setup

RemoteLLM runs coding agents inside Docker containers and routes outbound model traffic through a WireGuard container. The host does not need to join the VPN.

## Prerequisites

- Docker with Compose v2.
- gVisor `runsc` registered as a Docker runtime.
- Enough disk space for the agent, LiteLLM, and utility images.
- Optional: a WireGuard client configuration, only needed if you plan to reach a
  privately hosted Ollama instance through the VPN profile (see
  [WireGuard](guides/wireguard.md)). Ollama itself is optional — skip both if you
  only plan to use Anthropic or BitNet.

### gVisor Runtime

The `agent` and `web-terminal` services use `runtime: runsc` for kernel-level isolation.
Install and register gVisor on the Docker host before starting the stack:

```sh
curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" \
  | sudo tee /etc/apt/sources.list.d/gvisor.list
sudo apt-get update
sudo apt-get install -y runsc
sudo runsc install
sudo systemctl reload docker
docker run --runtime=runsc --rm hello-world
```

WireGuard and the VPN proxy stay on Docker's default runtime because WireGuard needs
`NET_ADMIN`, `/dev/net/tun`, and a shared network namespace.

## Initialize

```sh
make init
```

This creates `.env`, `.local/workspace/`, `.local/volumes/`, and the WireGuard config directory.

Edit `.env` before starting the stack:

```dotenv
# Ollama is optional. Leave as-is to skip it entirely; see "Model Configuration" below.
OLLAMA_BASE_URL=http://ollama.example.internal:11434
OLLAMA_MODEL=qwen3-coder:30b
OLLAMA_PROXY=socks5h://wireguard:1080
LOCAL_ENDPOINT=http://litellm:4000/v1
OPENAI_BASE_URL=http://litellm:4000/v1
OPENAI_API_KEY=change-me
CODE_SERVER_PASSWORD=change-me
TTYD_USER=agent
TTYD_PASSWORD=change-me
LITELLM_MASTER_KEY=change-me
LITELLM_SALT_KEY=change-me-salt
```

## WireGuard Configuration

The running container sees `./.local/volumes/wireguard` as `/config`. LinuxServer WireGuard reads client configs from `/config/wg_confs/*.conf`, so the host-side path is:

```text
.local/volumes/wireguard/wg_confs/wg0.conf
```

Manual setup:

```sh
mkdir -p .local/volumes/wireguard/wg_confs
cp /home/figaro/Programms/Wireguard/wireguard.conf .local/volumes/wireguard/wg_confs/wg0.conf
chmod 600 .local/volumes/wireguard/wg_confs/wg0.conf
```

Automated setup:

```dotenv
WIREGUARD_SOURCE=/home/figaro/Programms/Wireguard/wireguard.conf
COPY_WIREGUARD_CONFIG=1
```

Then run:

```sh
make init
```

Or rerun only the copy step:

```sh
make wireguard-config
```

Use a normal WireGuard client file with an `[Interface]` section and at least one `[Peer]` section. If your VPN requires DNS or `AllowedIPs`, keep those values in the file exactly as provided by the VPN server.

## Build And Start

```sh
make build
make up-ide
```

Open:

```text
http://127.0.0.1:8088/
http://127.0.0.1:8088/code/
http://127.0.0.1:8088/terminal/
```

Use `http`, not `https`, unless TLS has been added to nginx.

The terminal uses zsh with Oh My Zsh and the `remotellm-agnoster` theme. It is based on `agnoster`, uses a cyan working-directory segment, cyan-on-black `user@host`, and puts the command marker on a second line. If an existing `.local/volumes/agent-home/.zshrc` is already present, startup appends a small RemoteLLM source block instead of replacing your file.

tmux is available in the terminal and direct shell. Start a durable session with:

```sh
tmux new -A -s remotellm
```

The browser IDE can use Continue when the extension is installed. `make init` seeds:

```text
.local/volumes/vscode-config/continue/config.yaml
.local/volumes/vscode-config/continue/.env
```

The seeded Continue config points at LiteLLM with model alias `ollama-default`. Update `.local/volumes/vscode-config/continue/.env` after changing `OPENAI_API_KEY` or `LITELLM_MASTER_KEY`.

## Dev Environments

Use project-local environment files instead of installing project tools globally in the
agent container.

For simple runtime pinning, use mise from the normal agent shell:

```sh
make shell
cd /workspace/projects/<project>
mise install
```

Commit a project `.mise.toml` or `.tool-versions` with the runtime versions the project
needs.

For reproducible multi-tool environments, use Devbox from the Nix-enabled profile:

```sh
docker compose --profile nix up -d nix-agent
make shell-nix
cd /workspace/projects/<project>
devbox init
devbox shell
```

Commit `devbox.json` and `devbox.lock` with the project. Run `make check-dev-env` to
report `.mise.toml`, `.tool-versions`, `devbox.json`, `flake.nix`, `devenv.nix`, and
`.envrc` files before activating an unfamiliar project environment.

## Optional Agent CLIs

The default image installs opencode only. Codex CLI and Claude Code are opt-in because they require external accounts and change more frequently than the base stack.

To enable Codex CLI, set a pinned package spec in `.env`:

```dotenv
INSTALL_CODEX_CLI=1
CODEX_CLI_PACKAGE=@openai/codex@<version>
```

To enable Claude Code:

```dotenv
INSTALL_CLAUDE_CODE=1
CLAUDE_CODE_PACKAGE=@anthropic-ai/claude-code@<version>
ANTHROPIC_API_KEY=<key-if-needed>
ANTHROPIC_BASE_URL=<compatible-endpoint-if-needed>
```

### Hermes Agent

Hermes is a self-improving autonomous agent by Nous Research. It runs on a dedicated Compose profile and exposes a browser dashboard with a Kanban board for multi-agent task tracking.

Two install methods are available. Choose one in `.env`:

**PyPI — pinned version (reproducible builds):**

```dotenv
INSTALL_HERMES_AGENT=1
HERMES_INSTALL_METHOD=pypi
HERMES_AGENT_VERSION=0.16.0
```

**Official installer — always latest:**

```dotenv
INSTALL_HERMES_AGENT=1
HERMES_INSTALL_METHOD=official
```

The official installer fetches the current release from the Nous Research install script at build time. `HERMES_AGENT_VERSION` is ignored in this mode.

Then rebuild:

```sh
make build
```

Run the profiles with:

```sh
make codex
make claude
make hermes
```

Start the Hermes web dashboard:

```sh
make up-hermes-web
```

Open:

```text
http://127.0.0.1:8645/
```

When `NGINX_BIND=0.0.0.0`, the nginx auth gate uses `HERMES_DASHBOARD_USER` and `HERMES_DASHBOARD_PASSWORD`. Run `make init` after changing those values to regenerate the htpasswd file.

Set `HERMES_OLLAMA_MODEL` to the Ollama model Hermes should use. The model must support ≥64k context (LiteLLM forces `num_ctx=65536` for the `hermes` alias). Run `make restart-litellm` after changing this value.

Create a scoped LiteLLM virtual key for Hermes (see [LiteLLM](LITELLM.md#virtual-keys)):

```dotenv
HERMES_VIRTUAL_KEY=sk-...
```

## Optional Profiles

### OpenCode Web UI

OpenCode can run its browser UI on a dedicated port:

```sh
make up-opencode-web
```

Open:

```text
http://127.0.0.1:4040/
```

Set `OPENCODE_WEB_PORT` to change the host port. Change
`OPENCODE_SERVER_PASSWORD` from the default before exposing the port beyond localhost.

### Playwright MCP

Playwright MCP runs in the optional `playwright` profile for browser-driven testing and
visual checks. Start it only for web projects that need browser automation:

```sh
make up-playwright
```

The service mounts `.local/workspace/projects`, `.local/workspace/outputs/playwright-report`, and
`.local/workspace/outputs/test-results`. It does not publish a host port or route through
nginx by default. To let an agent use it, explicitly enable the disabled `playwright`
entry in the seeded MCP config for that agent.

### Observability

Langfuse runs as an optional observability profile and receives traces from LiteLLM after
project keys are configured.

First boot:

```sh
make up-observability
```

Open:

```text
http://localhost:3000/
```

Create the first Langfuse account, create a project, then copy the project keys into
`.env`:

```dotenv
LANGFUSE_PUBLIC_KEY=pk-...
LANGFUSE_SECRET_KEY=sk-...
LANGFUSE_HOST=http://langfuse-web:3000
```

Restart LiteLLM so it picks up the keys:

```sh
docker compose restart litellm
```

Use `make logs-langfuse` to follow the Langfuse web and worker logs.

See [Langfuse](LANGFUSE.md) for what it records, daily use, operations, and
troubleshooting.

## LiteLLM Gateway

LiteLLM is the model gateway. It starts by default because it is the only service
that proxies to the remote Ollama endpoint. Agents call `http://litellm:4000/v1`
on the internal Docker network.

LiteLLM uses a dedicated PostgreSQL instance (`litellm-postgres`) to persist
virtual keys, usage logs, and settings. Both services start together as part of
the core stack.

### API access through nginx

```text
http://127.0.0.1:8088/api/litellm/v1/
```

Use a virtual key (or `LITELLM_MASTER_KEY` before keys are created) as the
bearer token.

### Admin UI

```text
http://127.0.0.1:8088/api/litellm/ui
```

Log in with `LITELLM_UI_USERNAME` / `LITELLM_UI_PASSWORD`. From the UI you can
create and revoke virtual keys, inspect usage, and manage model access.

### Virtual keys

After first boot, create per-role virtual keys so agents never hold the master
key:

```sh
make litellm-keys
```

Copy the printed values into `.env` and restart the affected containers. See
[LiteLLM](LITELLM.md) for the full setup guide including manual key creation,
key rotation, and adding Anthropic as a model provider.

## Model Configuration

Ollama is optional. The stack starts and agents work fine without it — use
`ANTHROPIC_API_KEY` for Claude, or `make up-cpu-llm` for the offline BitNet model. The
`ollama-default` and `hermes` LiteLLM aliases simply fail at call time until Ollama is
configured; nothing else depends on them.

If you do have an Ollama instance to route to, there are two setups:

- **Directly reachable** (same LAN, no VPN): set `OLLAMA_BASE_URL` to its base URL,
  without a path suffix, and leave the VPN off.
- **Privately hosted behind your own WireGuard server**: run `make up-vpn`, set
  `OLLAMA_FORWARD_TARGET` to Ollama's address as seen from inside that VPN, and set
  `OLLAMA_BASE_URL=http://wireguard:11434`. See [WireGuard](guides/wireguard.md) for
  notes on running your own WireGuard server.

LiteLLM uses the `ollama` provider which automatically handles the `/api/chat` endpoint.
If your Ollama instance also exposes an OpenAI-compatible `/v1` API, you can use the
`openai` provider type in `config/litellm/config.yaml` and append `/v1` to the base URL, but
this is not required.

## Outer Nginx / Sub-path Deployment

`BASE_PATH` is reserved for deployments behind another nginx at a nested path such as
`/remotellm`. Full envsubst-based nginx and ttyd support is deferred to Phase 5, so the
current workaround is to strip the prefix in the outer nginx before proxying to
RemoteLLM.

Example outer nginx location:

```nginx
location /remotellm/ {
    rewrite ^/remotellm/(.*)$ /$1 break;
    proxy_pass http://127.0.0.1:8088;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

Leave `BASE_PATH=` empty for the current root deployment. Use the strip-prefix
workaround only when you need nested deployment before Phase 5 lands.
