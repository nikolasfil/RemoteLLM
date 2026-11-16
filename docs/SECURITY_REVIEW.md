# Security Review

RemoteLLM is a development stack. It contains writable shells and agent state, so review exposure before using it on a shared host or LAN.

## Quick Check

Run:

```sh
make security-review
```

The check renders the Compose config with browser and optional-agent profiles, then warns about common mistakes:

- placeholder credentials
- nginx bound to all interfaces
- Docker socket mounts
- missing `no-new-privileges` settings
- missing `runsc` runtime on writable agent shell services
- missing or loose WireGuard config permissions

Warnings need human review. A blocking error means the rendered stack includes a risk that should not be accidental, such as a Docker socket mount. `TTYD_PASSWORD=change-me` is also blocking because ttyd starts with `-W`, which gives authenticated browser-terminal users a writable live shell.

## Security Properties by Agent

| Command | Isolation |
|---|---|
| `make agent` | Docker + gVisor `runsc` runtime |
| `make codex` | Docker + Codex built-in Linux sandboxing |
| `make claude` | Docker container isolation |
| `make up-ide` browser terminal | Docker + gVisor `runsc` runtime; ttyd is writable after login |

## Manual Checklist

- Keep `NGINX_BIND=127.0.0.1` unless LAN exposure is intended.
- Replace `CODE_SERVER_PASSWORD`, `TTYD_PASSWORD`, `LITELLM_MASTER_KEY`, `LITELLM_SALT_KEY`, `LITELLM_UI_PASSWORD`, and `LITELLM_DB_PASSWORD` before exposing browser tools.
- When enabling optional LiteLLM routing, create scoped keys (`make litellm-keys`) and explicitly configure the selected key in each agent. Agents should never hold `LITELLM_MASTER_KEY`.
- Do not change `LITELLM_SALT_KEY` after first boot — it encrypts stored virtual keys.
- Keep WireGuard config under `.local/volumes/wireguard/wg_confs/wg0.conf` with `0600` permissions.
- Use the selected provider directly, or explicitly enable LiteLLM routing. Keep VPN proxy configuration specific to model traffic.
- Do not mount `/var/run/docker.sock` into agent containers unless a task explicitly needs host Docker control.
- Use `safe-npm-install`, `safe-pip-install`, and `safe-package-check` before adding dependencies.
- Pin optional agent CLI package specs before enabling Codex CLI or Claude Code builds.
- Review `.local/volumes/` before backups or sharing; it may contain shell history, agent transcripts, credentials, and memory files.
- Leave passwordless sudo limited to development shell containers. Non-shell services should keep `no-new-privileges:true`.

## Sudo Policy

The `agent` and `web-terminal` containers grant passwordless sudo to the `agent` user
via `/etc/sudoers.d/agent`. This is intentional: the container is a development sandbox,
and restricting sudo would break package installs and common developer workflows without
meaningful security improvement.

The meaningful isolation boundary is the container wall, not the sudo gate inside it.
All other services (`wireguard`, `nginx`, `litellm`, `vpn-proxy`) use
`no-new-privileges: true` and do not grant elevated privileges.

If deploying on shared infrastructure where the agent container is accessed by untrusted
users, reconsider this policy and replace passwordless sudo with explicit per-command
entries or remove it entirely.
