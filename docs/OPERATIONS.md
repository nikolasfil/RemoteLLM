# Operations

## Common Commands

Initialize directories and `.env`:

```sh
make init
```

Copy the WireGuard config from `WIREGUARD_SOURCE`:

```sh
make wireguard-config
```

Build local images:

```sh
make build
```

Start the core stack:

```sh
make up
```

Start the VPN proxy manually:

```sh
make up-vpn
```

Start with browser IDE and terminal:

```sh
make up-ide
```

Start with IDE, terminal, and extra profiles:

```sh
make up-full
```

Enter the agent shell:

```sh
make shell
```

Install a one-off package inside the agent:

```sh
sudo apt-get update
sudo apt-get install <package>
```

Add a package permanently to the image by editing:

```text
docker/agent/apt-packages.txt
```

Then rebuild and recreate:

```sh
docker compose build agent
docker compose --profile ide --profile web-terminal up -d agent web-terminal
```

Run opencode inside the agent:

```sh
make agent
```

Run optional agent profiles after enabling and rebuilding them:

```sh
make codex
make claude
make hermes
```

Start the Hermes browser dashboard:

```sh
make up-hermes-web
```

Run local exposure checks:

```sh
make security-review
```

Refresh the managed shell profile in an existing agent home:

```sh
docker compose exec agent setup-agent true
```

Start tmux:

```sh
tmux new -A -s remotellm
```

Refresh the seeded Continue config if it has not been customized:

```sh
cp config/continue/config.yaml .local/volumes/vscode-config/continue/config.yaml
```

Show containers:

```sh
make ps
```

Show logs:

```sh
make logs
```

Render Compose config:

```sh
make config
```

Stop the stack:

```sh
make down
```

## Health Checks

Check WireGuard:

```sh
docker compose exec wireguard wg show
```

Check Ollama through the proxy:

```sh
make test-vpn
```

Check the terminal container:

```sh
docker compose logs web-terminal --tail=100
```

Check nginx:

```sh
docker compose logs nginx --tail=100
```

## Dependency Workflows

From inside the agent container:

```sh
safe-package-check /workspace/projects
safe-npm-install <package>
safe-pip-install <package>
```

These tools are intended to catch known vulnerable or suspicious packages before they are added.

## Backups

Create a local backup of persistent state and outputs:

```sh
make backup
```

Backups are written under `.local/backups/`.

## LiteLLM Key Management

List all virtual keys:

```sh
curl -s http://127.0.0.1:8088/api/litellm/key/list \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  | jq '[.keys[] | {alias:.key_alias, models:.models, rpm:.rpm_limit}]'
```

Check spend for a key:

```sh
curl -s "http://127.0.0.1:8088/api/litellm/key/info?key=sk-..." \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  | jq '{alias:.info.key_alias, spend:.info.spend}'
```

Revoke a compromised key:

```sh
curl -s -X DELETE http://127.0.0.1:8088/api/litellm/key/delete \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"keys":["sk-..."]}'
```

Regenerate all virtual keys (after revoking compromised ones):

```sh
make litellm-keys
```

Copy the new values into `.env`, then restart affected containers:

```sh
docker compose up -d agent hermes claude
```

Check LiteLLM and its database:

```sh
docker compose logs litellm --tail=50
docker compose logs litellm-postgres --tail=50
```

## Updating Tool Versions

Tool versions are controlled by `.env` build args:

```dotenv
OPENCODE_VERSION=1.15.12
SOCKET_VERSION=1.1.102
PIP_AUDIT_VERSION=2.10.0
OSV_SCANNER_VERSION=v2.3.8
SCORECARD_VERSION=v5.2.1
TTYD_VERSION=1.7.7
LITELLM_VERSION=1.86.2
CODEX_CLI_PACKAGE=@openai/codex@<version>
CLAUDE_CODE_PACKAGE=@anthropic-ai/claude-code@<version>
HERMES_AGENT_VERSION=<version>          # only used when HERMES_INSTALL_METHOD=pypi
```

After changing them:

```sh
make build
make up-ide
```

To update Hermes to the latest official release, set `HERMES_INSTALL_METHOD=official` (drops the version pin) and rebuild:

```sh
make build
```
