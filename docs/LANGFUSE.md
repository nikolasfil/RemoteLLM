# Langfuse

Langfuse is the optional observability layer for RemoteLLM. It records LLM calls
that pass through LiteLLM so you can inspect what the agents asked, which model
was used, whether the call succeeded, how long it took, and how many tokens it
used.

In this stack, agents do not talk to Langfuse directly. The flow is:

```text
agent / Continue / opencode / Codex / Claude
        |
        v
LiteLLM at http://litellm:4000/v1
        |
        +--> remote Ollama through WireGuard
        |
        +--> Langfuse callback for traces and errors
```

## What It Does

Langfuse gives you a searchable record of model activity:

- Traces each successful and failed LiteLLM request.
- Shows model name, latency, token counts, request/response metadata, and errors.
- Helps compare agent behavior across tools that share the LiteLLM gateway.
- Gives you a local UI for debugging slow, expensive, failing, or low-quality calls.
- Keeps observability optional; the default stack runs without Langfuse.

RemoteLLM runs Langfuse behind the `observability` Compose profile. Starting that
profile adds:

- `langfuse-web`: the browser UI and API on `${LANGFUSE_BIND}:${LANGFUSE_PORT}`.
- `langfuse-worker`: background processing.
- `langfuse-postgres`: metadata storage.
- `langfuse-clickhouse`: trace and analytics storage.
- `langfuse-minio`: object storage for event/media data.
- `langfuse-redis`: queue and cache.
- `langfuse-minio-init`: one-shot bucket initialization.

The service is exposed directly on port `3000` by default instead of through nginx
because Langfuse is easiest to run at a root URL.

## Enable It

Initialize the project if you have not already:

```sh
make init
```

Generate real secrets for `.env`:

```sh
openssl rand -base64 32
openssl rand -base64 32
```

Put those values in:

```dotenv
LANGFUSE_NEXTAUTH_SECRET=<first generated value>
LANGFUSE_SALT=<second generated value>
```

For local-only use, these defaults are fine:

```dotenv
LANGFUSE_BIND=127.0.0.1
LANGFUSE_PORT=3000
LANGFUSE_NEXTAUTH_URL=http://localhost:3000
LANGFUSE_HOST=http://langfuse-web:3000
```

Start Langfuse:

```sh
make up-observability
```

Open:

```text
http://localhost:3000/
```

Create the first Langfuse account, create a project, then create API keys for
that project. Copy the keys into `.env`:

```dotenv
LANGFUSE_PUBLIC_KEY=pk-...
LANGFUSE_SECRET_KEY=sk-...
LANGFUSE_HOST=http://langfuse-web:3000
```

Restart LiteLLM so it picks up the keys:

```sh
docker compose restart litellm
```

After the next agent request, traces should appear in the Langfuse project.

## Use It

Start the normal workspace and the observability profile:

```sh
make up-ide
make up-observability
```

Run a model request from any agent or browser tool that uses LiteLLM. Examples:

- Continue in code-server.
- opencode from `make agent`.
- Codex or Claude profiles, if enabled.
- Direct calls to LiteLLM through `http://127.0.0.1:8088/api/litellm/`.

Then open Langfuse and inspect the latest traces:

```text
http://localhost:3000/
```

Use the trace list to answer practical questions:

- Which agent made the request?
- Which model alias was used?
- Did the request fail before or after reaching Ollama?
- How long did the model call take?
- How many input and output tokens were used?
- Did retries or tool calls inflate the request count?

## Configuration Reference

The LiteLLM callback is enabled in `config/litellm/config.yaml`:

```yaml
litellm_settings:
  success_callback: ["langfuse"]
  failure_callback: ["langfuse"]
```

The callback is harmless when Langfuse keys are empty. Tracing starts only after
these values are set in `.env` and LiteLLM is restarted:

```dotenv
LANGFUSE_HOST=http://langfuse-web:3000
LANGFUSE_PUBLIC_KEY=pk-...
LANGFUSE_SECRET_KEY=sk-...
```

Host binding:

```dotenv
LANGFUSE_BIND=127.0.0.1
LANGFUSE_PORT=3000
LANGFUSE_NEXTAUTH_URL=http://localhost:3000
```

Internal service credentials:

```dotenv
LANGFUSE_DB_PASSWORD=langfuse
LANGFUSE_CLICKHOUSE_PASSWORD=langfuse
LANGFUSE_MINIO_USER=langfuse
LANGFUSE_MINIO_PASSWORD=langfuse
```

For anything beyond localhost, replace all default passwords and secrets first.
If `LANGFUSE_BIND` changes to `0.0.0.0`, also update `LANGFUSE_NEXTAUTH_URL` to
the URL users will open in their browser.

## Operations

Follow Langfuse logs:

```sh
make logs-langfuse
```

Show container status:

```sh
make ps
```

Restart only LiteLLM after changing Langfuse keys:

```sh
docker compose restart litellm
```

Restart the observability services:

```sh
docker compose --profile observability restart langfuse-web langfuse-worker
```

Stop the stack:

```sh
make down
```

Langfuse data is stored under:

```text
.local/volumes/langfuse/
```

That directory is machine-local runtime state and is ignored by git.

## Troubleshooting

If `http://localhost:3000/` does not open:

```sh
make ps
make logs-langfuse
```

Check whether Postgres and ClickHouse are healthy. Langfuse will not finish
booting until its storage services are ready.

If the UI works but no traces appear:

1. Confirm `.env` contains `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, and
   `LANGFUSE_HOST=http://langfuse-web:3000`.
2. Restart LiteLLM with `docker compose restart litellm`.
3. Make a fresh agent request after the restart.
4. Check LiteLLM logs with `docker compose logs litellm --tail=100`.

If login redirects or callback URLs look wrong, check:

```dotenv
LANGFUSE_NEXTAUTH_URL=http://localhost:3000
```

For LAN or reverse-proxy access, this must match the external browser URL.

If MinIO-related errors appear, make sure the bucket initializer ran:

```sh
docker compose --profile observability up langfuse-minio-init
```

## Security Notes

Langfuse can store prompts, responses, errors, metadata, and token usage. Treat
it as sensitive application data.

- Keep `LANGFUSE_BIND=127.0.0.1` unless you intentionally expose it.
- Replace all `change-me` and default Langfuse credentials before LAN access.
- Do not commit `.env` or `.local/volumes/langfuse/`.
- Review traces before sharing screenshots or exports.
