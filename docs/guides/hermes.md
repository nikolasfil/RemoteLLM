# Hermes Agent

Hermes is a self-improving autonomous agent by Nous Research. It runs under the `hermes` and `hermes-web` Compose profiles. In addition to the CLI agent, it exposes a browser dashboard with a Kanban board for multi-agent task tracking, a skills browser, and a live PTY terminal.

## Features

- Self-improving autonomous coding agent (Nous Research Hermes)
- Kanban board for multi-agent task management
- Skills browser for viewing and managing agent skills
- Live PTY terminal in the browser dashboard
- Two install methods: PyPI (pinned, reproducible) or official installer (latest release)
- 64k context window enforced by LiteLLM (`num_ctx: 65536`)
- Scoped LiteLLM virtual key (`HERMES_VIRTUAL_KEY`) separate from general agents
- Persistent state at `.local/volumes/hermes-home/`

## Services

### `hermes`

One-shot CLI agent. Starts, runs a task interactively, exits. Uses `run-hermes-agent` wrapper.

```sh
make hermes
```

### `hermes-web`

Browser dashboard server. Runs persistently, exposing the Kanban board at port `HERMES_WEB_PORT` (default 8645).

```sh
make up-hermes-web
```

Open:

```text
http://127.0.0.1:8645/
```

## Functionalities

### Enabling Hermes

Choose an install method in `.env` before rebuilding.

**PyPI — pinned version (reproducible):**

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

Then rebuild:

```sh
make build
```

### Optional LiteLLM Virtual Key for Hermes

Use `hermes model` to configure a native provider by default. If you explicitly
choose gateway routing, start `make up-onlineagents` first. Create a scoped key restricted to the `hermes` model alias (which forces 64k context):

```sh
curl -s -X POST http://127.0.0.1:8088/api/litellm/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"key_alias":"hermes","models":["hermes"],"rpm_limit":30}' \
  | jq -r '.key'
```

Set in `.env`:

```dotenv
HERMES_VIRTUAL_KEY=sk-...
```

This stores the optional key only. Configure Hermes with the custom provider,
`http://litellm:4000/v1`, this scoped key, and the chosen model explicitly.
The role variable alone does not change Hermes routing.

### Model Configuration

```dotenv
HERMES_OLLAMA_MODEL=hermes3:8b    # optional gateway alias only; supports ≥64k context
```

Apply after changing:

```sh
make restart-litellm
```

### Dashboard Access Controls

When `NGINX_BIND=0.0.0.0` (LAN exposure), nginx protects the dashboard with basic auth:

```dotenv
HERMES_DASHBOARD_USER=admin
HERMES_DASHBOARD_PASSWORD=your-password
```

Run `make init` after changing these to regenerate the htpasswd file.

### Persistent State

Hermes state (Kanban database, skills, configuration) is stored at `.local/volumes/hermes-home/`, mounted at `/home/agent/.hermes`.

### Logs

```sh
docker compose logs hermes --tail=50
docker compose logs hermes-web --tail=50
```

## Orchestrating Codex / Claude / OpenCode via Kanban

Hermes can dispatch a kanban card directly to Codex CLI, Claude Code, or OpenCode via the
`devops/kanban-dispatch` skill (seeded from `config/agent/hermes-skills/`, additive
alongside Hermes's own bundled kanban skills, never overriding them). Codex and Claude
use their own subscription logins when configured that way; OpenCode uses the normal
RemoteLLM LiteLLM route.

**Routing:** the card body's first line must be `backend: codex`, `backend: claude-code`,
or `backend: opencode`. A missing or unrecognized label blocks the card rather than
guessing.

**Prerequisites:**

1. `INSTALL_CODEX_CLI=1` and/or `INSTALL_CLAUDE_CODE=1` built for Codex/Claude — see
   `docs/guides/codex.md` and `docs/guides/claude-code.md`. OpenCode is installed in the
   base agent image.
2. One-time subscription login completed for each CLI you intend to dispatch to (same
   guides, "Authentication (one-time)"). Hermes-launched subprocesses automatically see
   the persisted tokens via the shared `codex-home`/`claude-home` volumes — no separate
   auth step inside Hermes. OpenCode does not need this; it needs LiteLLM reachable and
   `OPENAI_API_KEY` set to a valid RemoteLLM/LiteLLM key.
3. `make refresh-agent` run so `~/.hermes/skills/devops/kanban-dispatch/SKILL.md` is
   seeded.

**Workspace and results:** code tasks should use a `worktree` kanban workspace so each
task gets its own branch. Output lands in
`/workspace/.aide/dispatch/<task_id>.<backend>.{log,json,err}`. Dispatched CLIs commit
locally but never push — there is no git credential helper in the container by default,
so this boundary holds without any extra enforcement code; push the reviewed branch
host-side once the card is unblocked.

See `docs/dev/plans/hermes-kanban-dispatch.md` for the full design and
`config/agent/hermes-skills/devops/kanban-dispatch/SKILL.md` for the worker-facing detail.

## Limitations

- **64k context minimum.** Hermes refuses models with less than 64k context at startup. The `hermes` LiteLLM alias forces `num_ctx: 65536` — only models that actually support 64k context will work correctly.
- **Kanban 404 bug.** If the Kanban board returns a 404, the `python-multipart` dependency may be missing from the Hermes venv. Permanent fix: `make build`. Temporary fix: `docker exec remotellm-hermes-web /opt/hermes/bin/pip install python-multipart && docker restart remotellm-hermes-web`.
- **Only 3 models visible in Hermes UI.** Hermes fetches its model list from LiteLLM. It shows exactly the models defined in `config/litellm/config.yaml`.
- **`official` install method is not pinned.** It installs whatever the Nous Research install script considers "latest" at build time. For reproducible builds, use `pypi` with a specific version.
- **Dashboard is not proxied through nginx by default.** It runs on its own port (`HERMES_WEB_PORT`). Access is via direct port, not `/hermes/`.
- **Hermes CLI profile is one-shot.** The `hermes` container exits when the agent session ends.

## Hardware Requirements

| Service | Idle RAM | Peak RAM |
|---|---|---|
| `hermes` (CLI, one-shot) | 256 MB | 1 GB |
| `hermes-web` (dashboard) | 512 MB | 1 GB |

The Hermes model must support 64k context; typically a 7B–13B model. Inference is on the remote Ollama server.
