# LiteLLM Gateway

LiteLLM is the OpenAI-compatible model gateway at the center of RemoteLLM. Every agent, IDE extension, and tool in the stack routes model calls through LiteLLM rather than calling upstream providers directly. This gives you a single authentication and routing layer, virtual key scoping, spend tracking, and optional Langfuse tracing.

## Features

- OpenAI-compatible API (`/v1/chat/completions`, `/v1/models`, etc.) accepted by all OpenAI SDK clients
- Routes to remote Ollama (directly or via the opt-in WireGuard proxy), Anthropic API, and local BitNet — in one config
- Virtual keys: scoped tokens with per-key model allow-lists, rate limits, and revocation
- Admin dashboard at `/api/litellm/ui` for key management and usage inspection
- PostgreSQL backend for durable key storage and usage logs
- Langfuse callback integration for LLM observability
- Per-model aliases that decouple agent config from provider details
- `drop_params: true` strips provider-unsupported params automatically

## Services

### `litellm`

The proxy process. Built from `docker/litellm/Dockerfile` with a pinned version (`LITELLM_VERSION`). Reads `config/litellm/config.yaml` mounted read-only.

Starts after `litellm-postgres` is ready. The WireGuard proxy is optional and can be started separately with `make up-vpn`.

### `litellm-postgres`

PostgreSQL 17 backing LiteLLM. Stores virtual keys, usage logs, and team settings. Data lives at `.local/volumes/litellm-postgres`.

**Do not change `LITELLM_SALT_KEY` after first run.** It encrypts the stored virtual keys. Changing it invalidates all existing keys.

## Functionalities

### Accessing LiteLLM

Internal (from agent containers): `http://litellm:4000/v1`

External (via nginx, from browser or curl): `http://127.0.0.1:8088/api/litellm/v1/`

Admin UI: `http://127.0.0.1:8088/api/litellm/ui`

Login: `LITELLM_UI_USERNAME` / `LITELLM_UI_PASSWORD` (or `admin` / `LITELLM_MASTER_KEY`).

### Model Aliases

| Alias | Provider | Route |
|---|---|---|
| `ollama-default` | Remote Ollama | Direct `OLLAMA_BASE_URL`, or `wireguard:11434` after `make up-vpn` |
| `hermes` | Remote Ollama | same as above; `num_ctx` forced to 65536 |
| `claude-default` | Anthropic API | direct internet; requires `ANTHROPIC_API_KEY` |
| `bitnet-2b` | Local BitNet | `http://bitnet:8080`; only when `cpu-llm` profile active |

Switch the Ollama model without rebuilding:

```dotenv
OLLAMA_MODEL=qwen3-coder:30b
```

Then run `make restart-litellm`.

### Virtual Keys

Virtual keys are scoped tokens. Agents hold a virtual key, never the master key.

Generate all standard keys at once:

```sh
make litellm-keys
```

Copy the printed values into `.env`:

```dotenv
AGENT_VIRTUAL_KEY=sk-...
HERMES_VIRTUAL_KEY=sk-...
CLAUDE_VIRTUAL_KEY=sk-...
```

Restart affected containers:

```sh
docker compose up -d agent hermes claude
```

Manual key creation (example):

```sh
curl -s -X POST http://127.0.0.1:8088/api/litellm/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"key_alias":"agents","models":["ollama-default"],"rpm_limit":60}' \
  | jq -r '.key'
```

List, inspect, and revoke keys:

```sh
# list
curl -s http://127.0.0.1:8088/api/litellm/key/list \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  | jq '[.keys[] | {alias:.key_alias, models:.models, rpm:.rpm_limit}]'

# revoke
curl -s -X DELETE http://127.0.0.1:8088/api/litellm/key/delete \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"keys":["sk-..."]}'
```

### Anthropic (Claude) Routing

Set `ANTHROPIC_API_KEY` in `.env`. The key stays in the `litellm` container; agents use a scoped `CLAUDE_VIRTUAL_KEY` pointed at LiteLLM.

To route Claude Code CLI through LiteLLM:

```dotenv
ANTHROPIC_BASE_URL=http://litellm:4000
ANTHROPIC_API_KEY=      # leave empty; virtual key is used via OPENAI_API_KEY
```

### Observability

When `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, and `LANGFUSE_HOST` are set in `.env`, LiteLLM forwards every trace to Langfuse automatically. Restart LiteLLM after setting these:

```sh
docker compose restart litellm
```

See [Langfuse](langfuse.md).

### Restarting LiteLLM

```sh
make restart-litellm
```

Required after changing `config/litellm/config.yaml`, `OLLAMA_MODEL`, `HERMES_OLLAMA_MODEL`, or Langfuse keys.

## Limitations

- **`LITELLM_SALT_KEY` is immutable after first run.** Changing it invalidates all stored virtual keys; they must be recreated.
- **Prisma ORM crashes intermittently** in some v1.8x releases. The `restart: unless-stopped` policy recovers automatically; frequent crashes indicate a Prisma version bug — upgrade `LITELLM_VERSION`.
- **Admin UI assets may 404 through nginx** if `LITELLM_PROXY_BASE_URL` does not match the nginx path. It must be `http://127.0.0.1:8088/api/litellm`.
- **Database dependency at startup.** LiteLLM waits for `litellm-postgres` to pass its health check. First-boot Postgres initialization takes ~30 seconds.
- **Rate limiting in `config.yaml` is commented out by default.** For multi-user deployments, uncomment and tune `router_settings.rpm_limit`.
- BitNet model (`bitnet-2b`) is only reachable when the `cpu-llm` profile is active. LiteLLM starts cleanly without it; requests to `bitnet-2b` fail until the profile is running.
- Ollama (`ollama-default`, `hermes`) is optional. LiteLLM starts cleanly without `OLLAMA_BASE_URL` configured; requests to those aliases fail until it points at a real instance, directly or via `make up-vpn` (see [WireGuard](wireguard.md)).

## Hardware Requirements

| Metric | Value |
|---|---|
| RAM (idle) | 384 MB |
| RAM (peak) | 1 GB |
| CPU (idle) | 0.2 cores |
| CPU (peak) | 1.0 cores |

PostgreSQL adds 128–384 MB. Both services are always part of the core stack — no way to run the stack without them.
