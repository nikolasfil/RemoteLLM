# Codex CLI

Codex CLI is OpenAI's command-line coding agent. It is an optional, opt-in component installed at image build time when `INSTALL_CODEX_CLI=1`. It runs under the `codex` Compose profile as a one-shot interactive container.

## Features

- OpenAI Codex CLI coding agent
- One-shot profile: runs a task, then exits (not a long-running service)
- Built-in Linux sandboxing (Codex sandbox policy)
- Shared workspace mounts with the core agent container
- Interactive TTY with stdin support
- State persisted to `.local/volumes/codex-home/`

## Functionalities

### Enabling Codex CLI

Set build args in `.env`:

```dotenv
INSTALL_CODEX_CLI=1
CODEX_CLI_PACKAGE=@openai/codex@<version>
```

Rebuild:

```sh
make build
```

### Running Codex

```sh
make codex
```

This starts the `codex` Compose profile container, which runs `run-codex-agent` — a wrapper script that invokes the Codex CLI. The container is interactive (stdin + TTY) and exits when the session ends.

### Authentication (one-time)

Codex CLI supports two unrelated auth paths: a real API key (routed through LiteLLM or
directly to OpenAI — see "Model and API" below) or a ChatGPT Plus/Pro/Business
subscription login, no API key required. To set up the subscription path:

```sh
# Run with the LiteLLM-routed key cleared, so the ChatGPT OAuth flow is what gets
# persisted instead of a placeholder API key:
docker compose --profile codex run --rm -e OPENAI_API_KEY= codex
```

Inside the container, run `codex login` and complete the browser OAuth flow. On a
headless/remote host with no local browser, use the device-code flow it offers and
complete it from your own machine. The resulting token persists to
`.local/volumes/codex-home/auth.json` (bind-mounted), so it survives container recreation
and is visible to any other profile that mounts the same volume — including Hermes, when
it shells out to the standalone `codex` binary via the `kanban-dispatch` skill (see
`docs/guides/hermes.md`).

Verify with `codex login status` inside the container, or check that
`.local/volumes/codex-home/auth.json` exists on the host.

### Model and API

Codex CLI calls `http://litellm:4000/v1` (same as all other agents) using the `OPENAI_API_KEY` environment variable set to `AGENT_VIRTUAL_KEY` or `LITELLM_MASTER_KEY`.

To use an OpenAI model directly instead of routing through LiteLLM, set `OPENAI_API_KEY` to a real OpenAI key and update `OPENAI_BASE_URL` to `https://api.openai.com/v1`.

### State

Codex state (skills, history, config) is stored in `.local/volumes/codex-home/`, mounted at `/home/agent/.codex`. Skills seeded in the image are copied only on first startup so edits in the volume are preserved.

## Limitations

- **Opt-in only.** Not installed unless `INSTALL_CODEX_CLI=1` and a pinned `CODEX_CLI_PACKAGE` are set. The build will fail if `INSTALL_CODEX_CLI=1` is set without a pinned package.
- **One-shot profile.** The container exits when Codex finishes. It is not a persistent service.
- **Requires rebuild after version change.** Updating Codex CLI requires changing `CODEX_CLI_PACKAGE` and running `make build`.
- **External OpenAI account may be required** depending on which model you route to.
- **Linux sandboxing behavior.** Codex applies its own sandbox policy inside the container. Some filesystem operations may be restricted by Codex policy rather than container permissions.

## Hardware Requirements

| Metric | Value |
|---|---|
| RAM (Codex process) | ~100–256 MB |
| CPU | <1 core |

Model inference is on the remote Ollama or OpenAI backend. Container isolation is Docker + Codex sandbox policy.
