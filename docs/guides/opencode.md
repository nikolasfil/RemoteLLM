# OpenCode

OpenCode is the default AI coding agent in RemoteLLM. It is pre-installed in the agent image and is the primary interactive coding tool used from `make agent` or the browser terminal.

## Features

- Interactive terminal-based AI coding agent
- Reads, edits, and runs files directly in the workspace
- Native provider login or explicitly configured OpenAI-compatible backend
- Optional browser web UI mode on a dedicated port
- Session state and history persisted to `.local/volumes/opencode-home/`
- Version-pinned via `OPENCODE_VERSION` build arg
- Supports multi-turn conversations with code context

## Functionalities

### Running OpenCode (Terminal)

From the agent shell or browser terminal:

```sh
make agent     # shortcut: exec into agent and run opencode
# or from inside the shell:
opencode
```

Run `opencode auth login` and select your provider/model. The seeded configuration does not disable native providers or preselect a gateway. See [LiteLLM](../LITELLM.md) for optional gateway configuration.

### Running the Web UI

OpenCode has a browser UI mode accessible on a separate port:

```sh
make up-opencode-web
```

Open:

```text
http://127.0.0.1:4040/
```

Set `OPENCODE_WEB_PORT` in `.env` to change the host port. Set `OPENCODE_SERVER_PASSWORD` from the default before exposing beyond localhost.

The web UI runs under the `opencode-web` Compose profile. It shares the same workspace mounts and environment as the terminal agent.

### State and History

OpenCode persists conversation history and config to `.local/volumes/opencode-home/`, mounted at `/home/agent/.config/opencode`. This volume survives container restarts.

### Switching Models

Select a model in OpenCode. Only when explicitly using the optional LiteLLM `ollama-default` alias, switch the upstream Ollama model with:

```dotenv
OLLAMA_MODEL=another-model:tag
```

Run `make restart-litellm` after changing the model.

### MCP Integration

OpenCode supports MCP (Model Context Protocol) servers. The seeded MCP config is at `config/agent/opencode/opencode.jsonc`. To enable the Playwright MCP server for browser automation, uncomment the relevant entry in that file and start the `playwright` profile.

## Limitations

- Configure and authenticate a provider before requesting a model. LiteLLM is needed only if you select gateway routing.
- **Web UI password** (`OPENCODE_SERVER_PASSWORD`) defaults to `change-me`. Change it before using `make up-opencode-web` on a shared or LAN-exposed host.
- **Session state is local.** OpenCode history in `.local/volumes/opencode-home/` is not shared between the terminal and web UI modes.
- **Single concurrent session.** Running `make agent` and the web UI simultaneously on the same volume may cause state conflicts.
- **Version pinned at build time.** Updating OpenCode requires changing `OPENCODE_VERSION` in `.env` and running `make build`.

## Hardware Requirements

OpenCode itself is a lightweight CLI. Its resource consumption is driven by the LiteLLM + Ollama backend.

| Metric | Value |
|---|---|
| RAM (opencode process) | ~50–100 MB |
| CPU (opencode process) | <0.5 cores |

Model inference (on the remote Ollama server) is not included in these figures.
