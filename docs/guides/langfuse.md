# Langfuse Observability

Langfuse is an optional observability layer started with the `observability` Compose profile. It gives you a searchable record of every LLM call that passes through LiteLLM: model used, latency, token counts, inputs, outputs, errors, and trace history.

Agents never talk to Langfuse directly. The flow is:

```text
agent / Continue / opencode / Codex / Claude
        |
        v
LiteLLM (success_callback + failure_callback)
        |
        v
Langfuse (traces, errors, usage metrics)
```

## Features

- Trace every LiteLLM request (success and failure) with full metadata
- Per-request: model alias, latency, input/output tokens, error details
- Searchable trace list — filter by model, agent identity, date range, status
- Dashboard with usage aggregates and spend-by-model charts
- Local self-hosted — traces never leave your machine
- Optional; default stack runs without it

## Services

| Service | Role |
|---|---|
| `langfuse-web` | Next.js UI and REST API on port 3000 |
| `langfuse-worker` | Background trace processor |
| `langfuse-postgres` | Metadata storage (PostgreSQL 17) |
| `langfuse-clickhouse` | Trace and analytics storage |
| `langfuse-minio` | Object storage (event/media data) |
| `langfuse-redis` | Queue and ephemeral cache |
| `langfuse-minio-init` | One-shot MinIO bucket initializer |

All services run under the `observability` Compose profile.

## Functionalities

### First-Time Setup

Generate secrets (required before first boot):

```sh
openssl rand -base64 32    # → LANGFUSE_NEXTAUTH_SECRET
openssl rand -base64 32    # → LANGFUSE_SALT
```

Set in `.env`:

```dotenv
LANGFUSE_NEXTAUTH_SECRET=<value>
LANGFUSE_SALT=<value>
LANGFUSE_BIND=127.0.0.1
LANGFUSE_PORT=3000
LANGFUSE_NEXTAUTH_URL=http://localhost:3000
LANGFUSE_HOST=http://langfuse-web:3000
```

Start the observability profile:

```sh
make up-observability
```

Open `http://localhost:3000/`, create the first account, create a project, generate API keys for the project, then put the keys in `.env`:

```dotenv
LANGFUSE_PUBLIC_KEY=pk-...
LANGFUSE_SECRET_KEY=sk-...
```

Restart LiteLLM to pick up the keys:

```sh
docker compose restart litellm
```

### Daily Use

Run any agent request (opencode, Continue, Codex, direct API call) and inspect traces in the Langfuse UI:

- Which agent made the request (model alias from the virtual key)
- Whether the call succeeded or failed, and at which stage
- Exact latency and token counts
- Full request/response metadata for debugging low-quality outputs

### Operations

```sh
make logs-langfuse                                                    # follow web + worker logs
make ps                                                               # check container status
docker compose restart litellm                                        # re-enable tracing after key changes
docker compose --profile observability restart langfuse-web langfuse-worker
```

Langfuse data is stored at `.local/volumes/langfuse/` — machine-local, git-ignored.

### LAN or Reverse-Proxy Access

If `LANGFUSE_BIND` changes to `0.0.0.0`, also update:

```dotenv
LANGFUSE_NEXTAUTH_URL=http://<your-ip>:3000
```

Replace all default internal passwords (`LANGFUSE_DB_PASSWORD`, `LANGFUSE_CLICKHOUSE_PASSWORD`, `LANGFUSE_MINIO_USER`, `LANGFUSE_MINIO_PASSWORD`) before exposing to the network.

## Limitations

- **ClickHouse is memory-heavy.** 1 GB minimum just to start; 2–3 GB under active tracing. If RAM is tight, skip the observability profile and use `make logs` for basic visibility.
- **Startup order dependency.** Langfuse web will not boot until Postgres, ClickHouse, MinIO, and Redis are all healthy. On slow hardware, first boot can take 2–3 minutes.
- **MinIO bucket must be initialized.** If `langfuse-minio-init` fails or is skipped, upload-related errors appear. Re-run: `docker compose --profile observability up langfuse-minio-init`.
- **`LANGFUSE_NEXTAUTH_URL` must match the external browser URL.** Mismatches cause login redirect failures.
- **Traces store prompts and responses.** Treat `.local/volumes/langfuse/` as sensitive data — do not commit, share screenshots carelessly, or expose with default passwords.
- **Not routed through nginx** by default. Langfuse runs on its own port (3000) because it requires a root URL; sub-path deployment requires additional Langfuse configuration.

## Hardware Requirements

| Service | Idle RAM | Peak RAM |
|---|---|---|
| `langfuse-web` | 512 MB | 1 GB |
| `langfuse-worker` | 256 MB | 512 MB |
| `langfuse-postgres` | 256 MB | 1 GB |
| `langfuse-clickhouse` | 1 GB | 3 GB |
| `langfuse-minio` | 128 MB | 256 MB |
| `langfuse-redis` | 32 MB | 128 MB |
| **Total** | **~2.2 GB** | **~6 GB** |

Recommended system RAM for running the full stack with observability: 16 GB. Minimum: 6 GB (tight; ClickHouse will be slow).
