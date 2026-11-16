# LiteLLM

LiteLLM is an optional model gateway. Native provider login/configuration is
the default. `make up`, agent CLI targets, and `agent-here` do not start LiteLLM.

## Enable the gateway

Set the optional gateway credentials and upstream model settings in `.env`, then:

```sh
make build-onlineagents
make up-onlineagents
```

This starts LiteLLM and its PostgreSQL service through the `onlineagents` profile.
It does not switch any agent's provider. For an OpenAI-compatible client, explicitly
configure `http://litellm:4000/v1`, a scoped virtual key, and a model alias.
`OPENAI_BASE_URL`, `OPENAI_API_KEY`, and `LOCAL_ENDPOINT` are empty by default;
no master key is substituted into an agent.

For OpenCode, add an optional provider to its persisted `opencode.jsonc`:

```json
{
  "provider": {
    "litellm": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Optional LiteLLM",
      "options": {
        "baseURL": "http://litellm:4000/v1",
        "apiKey": "{env:OPENAI_API_KEY}"
      },
      "models": { "ollama-default": { "name": "Ollama Default" } }
    }
  }
}
```

Merge this into the existing config, preserving other settings. Set
`OPENAI_API_KEY` to the scoped key and select `litellm/ollama-default` explicitly.
Existing persisted configurations are not overwritten by a rebuild. Review and
remove old gateway/model selections manually when switching to native providers.

Stop the optional gateway with `make down-onlineagents`.

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
model allow-list and optional rate/budget limits. The master key is not injected into agents. Native direct-provider mode can
pass a real upstream API key to an agent; gateway-only setups should configure
upstream credentials separately from agent credentials.

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

Using `LITELLM_MASTER_KEY` as an agent API key would give that agent full
admin access to LiteLLM. There is no automatic master-key fallback. A compromised container can create
new keys, view all usage, and modify settings.

Virtual keys are scoped: model-locked, rate-limited, and instantly revocable.
If one leaks the blast radius is contained to the allowed models at the
configured rate, and you can revoke it without touching any other service.

### Creating keys

The `make litellm-keys` target generates one key per role and prints the values
to save securely. Role variables alone do not configure an agent:

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

Explicitly configure the selected key as `OPENAI_API_KEY` or through the chosen
agent's provider settings, then recreate that service. Role variables are optional
storage names, not automatic routing controls.

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
This value supplies the gateway upstream key and can also supply agents in direct-provider mode. Agents use a scoped virtual
key (`CLAUDE_VIRTUAL_KEY`) pointed at `http://litellm:4000/v1`.

For the `claude` profile (Claude Code CLI), set:

```dotenv
# Route Claude Code through LiteLLM instead of Anthropic directly
ANTHROPIC_BASE_URL=http://litellm:4000
ANTHROPIC_API_KEY=<scoped-gateway-key-for-this-agent>
```

Keep the real upstream key in the gateway environment or credential store;
do not replace its upstream key with the agent virtual key. The shared `.env`
uses one `ANTHROPIC_API_KEY`, so use a service-specific override for gateway routing.

For Claude Code to call Anthropic directly, set `ANTHROPIC_API_KEY`
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
