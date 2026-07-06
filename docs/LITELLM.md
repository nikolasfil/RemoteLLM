# LiteLLM

LiteLLM is the model gateway for RemoteLLM. Every agent, IDE extension, and
tool in the stack calls `http://litellm:4000/v1` instead of upstream providers
directly. LiteLLM handles routing, authentication, and (optionally) spend
tracking.

## Architecture

```text
agent / code-server / web-terminal
        |
        v  OPENAI_API_KEY = virtual key (scoped, revocable)
LiteLLM proxy  http://litellm:4000/v1
        |
        +--> ollama-default  →  socat:11434 → WireGuard → remote Ollama
        +--> hermes          →  socat:11434 → WireGuard → remote Ollama
        +--> claude-default  →  Anthropic API (internet, no VPN)
```

Agents authenticate with **virtual keys** — scoped tokens tied to a specific
model allow-list and optional rate/budget limits. The LiteLLM master key and
real upstream credentials (Anthropic API key, Ollama URL) never enter agent
containers.

## Database

LiteLLM uses PostgreSQL (via Prisma ORM) to persist virtual keys, usage logs,
and team settings. Without a database the proxy routes requests but the admin
UI is non-functional and virtual keys are lost on restart.

The `litellm-postgres` service provides a dedicated Postgres instance. Its data
lives at `.local/volumes/litellm-postgres`.

## Admin UI

The built-in dashboard is at:

```text
http://127.0.0.1:8088/api/litellm/ui
```

Login with `LITELLM_UI_USERNAME` (default `admin`) and `LITELLM_UI_PASSWORD`.
Alternatively leave those unset and log in with username `admin` / password =
value of `LITELLM_MASTER_KEY`.

From the UI you can:
- Create, view, edit, and revoke virtual keys
- Set per-key model restrictions, rate limits, and budgets
- Manage teams and assign keys to teams
- View per-key and per-model usage and spend dashboards
- Add provider credentials (stored encrypted in the database)

Advanced settings (guardrails, routing rules) are config.yaml / API only.

**Do not change `LITELLM_SALT_KEY` after first run.** It encrypts the virtual
keys stored in Postgres. Changing it invalidates all stored keys and you will
need to recreate them.

## Virtual Keys

### Why virtual keys

The default fallback — using `LITELLM_MASTER_KEY` as the agent API key — gives
every agent full admin access to LiteLLM. A compromised container can create
new keys, view all usage, and modify settings.

Virtual keys are scoped: model-locked, rate-limited, and instantly revocable.
If one leaks the blast radius is contained to the allowed models at the
configured rate, and you can revoke it without touching any other service.

### Creating keys

The `make litellm-keys` target generates one key per role and prints the values
to copy into `.env`:

```sh
make litellm-keys
```

Or create keys manually via the API:

```sh
# General agents (ollama-default only, 60 req/min)
curl -s -X POST http://127.0.0.1:8088/api/litellm/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"key_alias":"agents","models":["ollama-default"],"rpm_limit":60}' \
  | jq -r '.key'

# Hermes agent (hermes model only, 30 req/min)
curl -s -X POST http://127.0.0.1:8088/api/litellm/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"key_alias":"hermes","models":["hermes"],"rpm_limit":30}' \
  | jq -r '.key'

# Claude agent (claude-default only, 20 req/min)
curl -s -X POST http://127.0.0.1:8088/api/litellm/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"key_alias":"claude-agent","models":["claude-default"],"rpm_limit":20}' \
  | jq -r '.key'
```

Paste the returned `sk-...` values into `.env`:

```dotenv
AGENT_VIRTUAL_KEY=sk-...
HERMES_VIRTUAL_KEY=sk-...
CLAUDE_VIRTUAL_KEY=sk-...
```

Then restart the affected containers:

```sh
docker compose up -d agent hermes claude
```

### Managing keys

```sh
# List all keys with alias, models, and rate limit
curl -s http://127.0.0.1:8088/api/litellm/key/list \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  | jq '[.keys[] | {alias:.key_alias, models:.models, rpm:.rpm_limit}]'

# Check spend for one key
curl -s "http://127.0.0.1:8088/api/litellm/key/info?key=sk-..." \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  | jq '{alias:.info.key_alias, spend:.info.spend}'

# Revoke a compromised key
curl -s -X DELETE http://127.0.0.1:8088/api/litellm/key/delete \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"keys":["sk-..."]}'
```

## Models

Model definitions live in `config/litellm/config.yaml`. Changes require a
LiteLLM restart:

```sh
make restart-litellm
```

| Alias | Provider | Notes |
|---|---|---|
| `ollama-default` | Remote Ollama (optional) | Set `OLLAMA_MODEL` in `.env` to switch models |
| `hermes` | Remote Ollama (optional) | Locked to `HERMES_OLLAMA_MODEL`; num_ctx forced to 65536 |
| `claude-default` | Anthropic API | Requires `ANTHROPIC_API_KEY` set in `.env` |

Ollama is optional — LiteLLM starts cleanly without `OLLAMA_BASE_URL` configured, and the
`ollama-default`/`hermes` aliases simply fail at call time until it's set. Reach Ollama either
directly (same LAN) or over your own WireGuard server via `make up-vpn` (see
[WireGuard guide](guides/wireguard.md)).

## Anthropic (Claude) Routing

When `ANTHROPIC_API_KEY` is set in `.env`, LiteLLM exposes it as `claude-default`.
The real key lives only in the `litellm` container. Agents use a scoped virtual
key (`CLAUDE_VIRTUAL_KEY`) pointed at `http://litellm:4000/v1`.

For the `claude` profile (Claude Code CLI), set:

```dotenv
# Route Claude Code through LiteLLM instead of Anthropic directly
ANTHROPIC_BASE_URL=http://litellm:4000
ANTHROPIC_API_KEY=   # leave empty; the virtual key is used via OPENAI_API_KEY
```

If you prefer Claude Code to call Anthropic directly, set `ANTHROPIC_API_KEY`
to your real key and leave `ANTHROPIC_BASE_URL` empty. In that case the real
key is visible inside the `claude` container.

## Observability

When the `observability` profile is running and Langfuse keys are configured
in `.env`, LiteLLM forwards traces to Langfuse automatically. See
[Langfuse](LANGFUSE.md) for setup.

## Troubleshooting

**"Not connected to DB" on UI login** — `DATABASE_URL` is wrong or
`litellm-postgres` is not healthy yet. Check with:

```sh
docker compose logs litellm-postgres --tail=50
docker compose logs litellm | grep -i "database\|prisma\|error"
```

**Virtual keys rejected after restart** — `LITELLM_SALT_KEY` was changed.
The stored keys are no longer decryptable. Recreate them via the API or UI.

**Prisma engine crash** — LiteLLM has a known intermittent Prisma process
crash in some v1.8x releases. The `restart: unless-stopped` policy on the
service recovers automatically. If restarts are frequent, check
`docker compose logs litellm` for Prisma errors and consider upgrading
`LITELLM_VERSION`.

**UI assets 404 through nginx** — `LITELLM_PROXY_BASE_URL` does not match the
nginx path. It must be set to the full base URL that browsers use to reach
LiteLLM, e.g. `http://127.0.0.1:8088/api/litellm`.
