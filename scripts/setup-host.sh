#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example"
fi

mkdir -p \
  .local/volumes/agent-home \
  .local/volumes/agent-home/.cache \
  .local/volumes/agent-home/.config \
  .local/volumes/agent-home/.local/share \
  .local/volumes/opencode-home \
  .local/volumes/codex-home \
  .local/volumes/claude-home \
  .local/volumes/hermes-home \
  .local/volumes/aide-memory \
  .local/volumes/mise-cache \
  .local/volumes/nginx-auth \
  .local/volumes/vscode-config \
  .local/volumes/vscode-config/continue \
  .local/volumes/litellm \
  .local/volumes/litellm-postgres \
  .local/volumes/wireguard/wg_confs \
  .local/workspace/projects \
  .local/workspace/inputs \
  .local/workspace/outputs \
  .local/backups

touch \
  .local/volumes/.gitkeep \
  .local/workspace/.gitkeep \
  .local/workspace/projects/.gitkeep \
  .local/workspace/inputs/.gitkeep \
  .local/workspace/outputs/.gitkeep

if [[ ! -f .local/volumes/vscode-config/continue/config.yaml ]]; then
  cp config/continue/config.yaml .local/volumes/vscode-config/continue/config.yaml
fi

chmod 700 .local/volumes .local/volumes/wireguard .local/volumes/wireguard/wg_confs
chmod 750 .local/workspace .local/workspace/projects .local/workspace/outputs
chmod 755 .local/workspace/inputs

for dir in \
  .local/volumes/agent-home \
  .local/volumes/agent-home/.config \
  .local/volumes/agent-home/.local \
  .local/volumes/agent-home/.local/share \
  .local/volumes/mise-cache
do
  if [[ ! -w "$dir" ]]; then
    echo "Directory is not writable by the current user: $dir" >&2
    echo "Fix ownership, then rerun make init:" >&2
    echo "  sudo chown -R \$(id -u):\$(id -g) .local/volumes/agent-home .local/volumes/mise-cache" >&2
    exit 1
  fi
done

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ && -z "${!key+x}" ]]; then
    export "$key=$value"
  fi
done < .env

required_vars=(
  COMPOSE_PROJECT_NAME
  NGINX_BIND
  NGINX_PORT
  OLLAMA_BASE_URL
  OLLAMA_MODEL
  OLLAMA_PROXY
  LOCAL_ENDPOINT
  OPENAI_BASE_URL
  LITELLM_MASTER_KEY
  LITELLM_SALT_KEY
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required .env value: $var" >&2
    exit 1
  fi
done

placeholder_values=(
  OPENAI_API_KEY
  CODE_SERVER_PASSWORD
  TTYD_PASSWORD
  LITELLM_MASTER_KEY
  LITELLM_SALT_KEY
  HERMES_DASHBOARD_PASSWORD
)

for var in "${placeholder_values[@]}"; do
  case "${!var:-}" in
    change-me|change-me-salt|"")
      echo "warning: $var still uses a placeholder value" >&2
      ;;
  esac
done

if [[ "${INSTALL_CODEX_CLI:-0}" == "1" && -z "${CODEX_CLI_PACKAGE:-}" ]]; then
  echo "INSTALL_CODEX_CLI=1 requires CODEX_CLI_PACKAGE, for example @openai/codex@<version>" >&2
  exit 1
fi

if [[ "${INSTALL_CLAUDE_CODE:-0}" == "1" && -z "${CLAUDE_CODE_PACKAGE:-}" ]]; then
  echo "INSTALL_CLAUDE_CODE=1 requires CLAUDE_CODE_PACKAGE, for example @anthropic-ai/claude-code@<version>" >&2
  exit 1
fi

if [[ "${COPY_WIREGUARD_CONFIG:-0}" == "1" ]]; then
  src="${WIREGUARD_SOURCE:-/home/figaro/Programms/Wireguard/wireguard.conf}"
  dst=".local/volumes/wireguard/wg_confs/wg0.conf"
  if [[ -f "$src" ]]; then
    cp "$src" "$dst"
    chmod 600 "$dst"
    echo "Copied WireGuard config to $dst"
  else
    echo "COPY_WIREGUARD_CONFIG=1 but source was not found: $src" >&2
    exit 1
  fi
fi

wg_config=".local/volumes/wireguard/wg_confs/wg0.conf"
if [[ ! -f "$wg_config" ]]; then
  echo "warning: WireGuard config is missing: $wg_config" >&2
  echo "warning: copy it manually or run: make wireguard-config" >&2
fi

continue_env=".local/volumes/vscode-config/continue/.env"
if [[ ! -f "$continue_env" ]]; then
  printf 'OPENAI_API_KEY=%s\n' "${OPENAI_API_KEY:-change-me}" > "$continue_env"
  chmod 600 "$continue_env"
fi

hermes_htpasswd=".local/volumes/nginx-auth/hermes.htpasswd"
hermes_user="${HERMES_DASHBOARD_USER:-hermes}"
hermes_pass="${HERMES_DASHBOARD_PASSWORD:-change-me}"
if command -v openssl &>/dev/null; then
  hash=$(openssl passwd -apr1 "$hermes_pass")
  printf '%s:%s\n' "$hermes_user" "$hash" > "$hermes_htpasswd"
  chmod 644 "$hermes_htpasswd"
else
  echo "warning: openssl not found — cannot generate $hermes_htpasswd" >&2
  echo "warning: create it manually: htpasswd -c $hermes_htpasswd <user>" >&2
fi

echo "Initialized RemoteLLM workspace directories."
echo
echo "Next commands:"
echo "  make build"
echo "  make up-ide"
echo
echo "Local URLs:"
echo "  http://${NGINX_BIND}:${NGINX_PORT}/"
echo "  http://${NGINX_BIND}:${NGINX_PORT}/code/"
echo "  http://${NGINX_BIND}:${NGINX_PORT}/terminal/"
