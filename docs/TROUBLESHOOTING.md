# Troubleshooting

## Browser Terminal Does Not Open

Use this URL:

```text
http://127.0.0.1:8088/terminal/
```

Use `http`, not `https`, unless nginx has been configured for TLS.

Check that the terminal profile is running:

```sh
docker compose --profile web-terminal ps
```

Start the IDE and terminal profile:

```sh
make up-ide
```

Check logs:

```sh
docker compose logs web-terminal --tail=100
docker compose logs nginx --tail=100
```

The terminal is served by ttyd with base path `/terminal`. nginx must preserve subpaths such as `/terminal/token` and `/terminal/ws`; otherwise the terminal page may load but the WebSocket session will close.

After changing nginx config:

```sh
docker compose restart nginx
```

## WireGuard Does Not Start

Confirm the config exists:

```sh
ls -l .local/volumes/wireguard/wg_confs/wg0.conf
```

If it is missing, copy it manually:

```sh
mkdir -p .local/volumes/wireguard/wg_confs
cp /path/to/wireguard.conf .local/volumes/wireguard/wg_confs/wg0.conf
chmod 600 .local/volumes/wireguard/wg_confs/wg0.conf
```

Or set `.env`:

```dotenv
WIREGUARD_SOURCE=/path/to/wireguard.conf
COPY_WIREGUARD_CONFIG=1
```

Then run:

```sh
make wireguard-config
```

Check logs:

```sh
docker compose logs wireguard --tail=100
```

## Ollama Is Not Reachable

Ollama is optional — if you don't need it, ignore this section and use Anthropic
(`ANTHROPIC_API_KEY`) or BitNet (`make up-cpu-llm`) instead.

Check `.env`:

```dotenv
OLLAMA_BASE_URL=http://ollama.example.internal:11434
OLLAMA_MODEL=qwen3-coder:30b
```

Then run:

```sh
make test-vpn
```

If DNS only works inside the VPN, keep `OLLAMA_PROXY=socks5h://wireguard:1080`; the `h` makes DNS resolution happen through the proxy. Do not set `ALL_PROXY`, `HTTP_PROXY`, or `HTTPS_PROXY` in the agent unless you intentionally want all package managers and tools to use the VPN.

## Code Server Login Fails

Use the password from:

```dotenv
CODE_SERVER_PASSWORD=change-me
```

Restart after changing it:

```sh
docker compose --profile ide up -d code-server
```

## Browser Terminal Login Fails

Use:

```dotenv
TTYD_USER=agent
TTYD_PASSWORD=change-me
```

Restart after changing it:

```sh
docker compose --profile web-terminal up -d web-terminal
```

## sudo Does Not Work In The Agent

The agent image grants passwordless sudo to the `agent` user. If sudo fails with a message about privileges, confirm the running Compose config for `agent` and `web-terminal` does not include `no-new-privileges:true`; sudo needs setuid escalation.

Recreate the containers after changing that setting:

```sh
docker compose --profile ide --profile web-terminal up -d agent web-terminal
```

## Hermes Kanban Shows 404

The error `Failed to load Kanban board: 404: {"detail":"No such API endpoint: /api/plugins/kanban/board"}` means the kanban plugin failed to load at startup, usually because `python-multipart` is missing from the Hermes venv.

To fix without rebuilding (does not survive container restart):

```sh
docker exec remotellm-hermes-web /opt/hermes/bin/pip install python-multipart
docker restart remotellm-hermes-web
```

The permanent fix is to rebuild the image — `python-multipart` is now included in the Dockerfile's Hermes install step:

```sh
make build
docker compose --profile hermes-web up -d hermes-web
```

If the 404 persists after rebuilding, check whether the plugin loaded at startup:

```sh
docker exec remotellm-hermes-web /opt/hermes/bin/python3 -c "
import importlib.util, sys
p = '/opt/hermes/lib/python3.11/site-packages/plugins/kanban/dashboard/plugin_api.py'
spec = importlib.util.spec_from_file_location('kanban_test', p)
mod = importlib.util.module_from_spec(spec)
sys.modules['kanban_test'] = mod
spec.loader.exec_module(mod)
print('router OK:', mod.router)
"
```

Any `ImportError` or `RuntimeError` in that output explains why the route was not mounted.

## Hermes Shows Only 3 Models

When explicitly configured for the optional gateway, Hermes fetches its model list from LiteLLM at `http://litellm:4000/v1`. It shows exactly the models defined in `config/litellm/config.yaml`. Add new entries there and run `make restart-litellm` to make them appear.

## Running Behind Another nginx

Direct access works at:

```text
http://127.0.0.1:8088/
```

For an outer nginx path like `/remotellm/`, configure the outer nginx to strip `/remotellm` before proxying to this stack. Prefix-preserving proxying is not yet supported because ttyd, code-server, redirects, and root-page links all need matching base-path configuration.
