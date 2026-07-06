# Web Terminal

The `web-terminal` service provides a browser-accessible terminal using [ttyd](https://github.com/tsl0922/ttyd). It runs the same agent image as the core `agent` container, sharing all workspace mounts, so it provides full access to the development environment from a browser tab.

## Features

- Full zsh shell with Oh My Zsh, `remotellm-agnoster` theme, autosuggestions, and syntax highlighting — identical to `make shell`
- tmux available for persistent multiplexed sessions
- Shared workspace mounts (`/workspace/projects`, `/workspace/inputs`, `/workspace/outputs`)
- Same environment variables and tool PATH as the agent container
- Password-protected login
- WebSocket-based — works in any modern browser without a local SSH client
- Runs under the `web-terminal` Compose profile

## Functionalities

### Starting the Terminal

```sh
make up-ide     # starts agent + code-server + web-terminal + nginx
```

Open:

```text
http://127.0.0.1:8088/terminal/
```

Login with `TTYD_USER` / `TTYD_PASSWORD` from `.env`.

### Changing Credentials

Edit `.env`:

```dotenv
TTYD_USER=agent
TTYD_PASSWORD=your-password
```

Restart:

```sh
docker compose --profile web-terminal up -d web-terminal
```

### Persistent tmux Session

Start a durable session that survives browser tab closes:

```sh
tmux new -A -s remotellm
```

Reattach after reopening the browser terminal: `tmux attach -t remotellm`.

### Running Agent CLIs

From the browser terminal, you can run any tool installed in the agent image:

```sh
opencode                 # start OpenCode AI agent
claude                   # start Claude Code (if installed)
codex                    # start Codex CLI (if installed)
safe-npm-install <pkg>   # install with preflight check
```

### Logs

```sh
docker compose logs web-terminal --tail=100
```

## Security Notes

ttyd starts with `-W` (writable mode). Anyone who authenticates gets a live shell with full workspace access and passwordless sudo. Because of this:

- Never use the default `TTYD_PASSWORD=change-me` if nginx is exposed beyond localhost.
- `make security-review` blocks on `TTYD_PASSWORD=change-me`.
- Keep `NGINX_BIND=127.0.0.1` unless LAN access is intentional.
- The gVisor `runsc` runtime can be enabled for kernel-level isolation (uncomment `runtime: runsc` in `compose.yml` after registering gVisor on the host).

## Limitations

- **Password authentication only.** ttyd does not support certificate or SSH key auth in this configuration.
- **Single shared shell environment.** Multiple browser tabs open parallel shells in the same container, sharing the same filesystem. Concurrent writes to the same files from multiple tabs will conflict.
- **No clipboard integration by default.** Browser clipboard access depends on the browser's permissions and whether the page is served over HTTPS.
- **nginx must preserve full URI path.** The terminal requires `/terminal/token` and `/terminal/ws` to reach ttyd. Custom nginx configs that strip or rewrite these paths will break the WebSocket session.
- **Writable shell = elevated risk.** Passwordless sudo is available. A stolen or brute-forced password gives full container access.

## Hardware Requirements

| Metric | Value |
|---|---|
| RAM (idle) | 128 MB |
| RAM (active shell) | 256–512 MB |
| CPU (idle) | <0.1 cores |
| CPU (active) | up to 1 core |

The web-terminal shares the agent image. The RAM figures above are for the ttyd process and shell. Running heavy build tasks from the browser terminal will use agent-level resources.
