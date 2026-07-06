# Code-Server (Browser IDE)

`code-server` provides a browser-accessible VS Code IDE. It runs under the `ide` Compose profile and is proxied through nginx at `/code/`.

## Features

- Full VS Code experience in the browser
- Extension marketplace access (VS Code Open VSX registry)
- Continue AI assistant extension for in-editor chat, autocomplete, and code edits
- Access to the same workspace mounts as the agent container (`/workspace/projects`, `/workspace/inputs`, `/workspace/outputs`)
- Password-protected login
- Persistent VS Code config, settings, and extension state at `.local/volumes/vscode-config`

## Functionalities

### Starting Code-Server

```sh
make up-ide          # starts agent + code-server + web-terminal + nginx
```

Open:

```text
http://127.0.0.1:8088/code/
```

Login with `CODE_SERVER_PASSWORD` from `.env`.

### Changing the Password

Edit `.env`:

```dotenv
CODE_SERVER_PASSWORD=your-password
```

Restart the service:

```sh
docker compose --profile ide up -d code-server
```

### Continue Extension

The AI assistant extension connects to LiteLLM. On first `make init`, the Continue config is seeded from `config/continue/config.yaml` to:

```text
.local/volumes/vscode-config/continue/config.yaml
```

The seeded config uses the `ollama-default` model alias from LiteLLM for chat, edit, apply, and autocomplete.

If you change `OPENAI_API_KEY` or `LITELLM_MASTER_KEY` after setup, update the Continue secret file:

```text
.local/volumes/vscode-config/continue/.env
```

To reset the Continue config to the seeded defaults (only if you have not customized it):

```sh
cp config/continue/config.yaml .local/volumes/vscode-config/continue/config.yaml
```

See [Continue](continue.md) for the full guide.

### Persistent State

| Host Path | Container Path | Contents |
|---|---|---|
| `.local/volumes/vscode-config` | `/home/coder/.config` | VS Code settings, keybindings, extension state |
| `.local/volumes/vscode-config/continue` | `/home/coder/.continue` | Continue config and local secrets |

Extensions installed from the browser persist in `.local/volumes/vscode-config` and survive container recreation.

### Logs

```sh
docker compose logs code-server --tail=100
```

## Limitations

- **No GPU access.** code-server runs as a plain container; GPU passthrough is not configured.
- **Extensions run in-browser, not natively.** Some extensions that require native binaries (e.g., language servers that download platform binaries) may behave differently or fail to install on non-matching architectures.
- **Extension installation pulls from Open VSX**, not the Microsoft VS Code Marketplace. Most popular extensions are available, but some Microsoft-exclusive extensions are not.
- **Memory grows with extensions.** Each language server or extension that runs in the background adds 50–500 MB. For resource-limited setups, install only needed extensions.
- **No shared shell with the `agent` container.** Code-server is a separate container. Terminal tabs inside code-server are scoped to the code-server container, not the agent. Use the web terminal (`/terminal/`) or `make shell` for the agent shell.
- **No WebSocket-over-HTTPS without TLS.** The IDE's live features (file watch, terminal) require WebSocket. If you add TLS to nginx, ensure `proxy_set_header Upgrade` and `Connection "upgrade"` are preserved.

## Hardware Requirements

| Metric | Value |
|---|---|
| RAM (idle, no extensions) | 512 MB |
| RAM (with language servers) | 2–4 GB |
| CPU (idle) | 0.5 cores |
| CPU (active editing) | up to 4 cores |

Recommended: 4 GB dedicated to code-server when running multiple language servers.
