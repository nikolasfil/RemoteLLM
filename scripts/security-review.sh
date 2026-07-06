#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

COMPOSE_CMD="${COMPOSE:-docker compose}"
config_file="${TMPDIR:-/tmp}/remotellm-security-review.yml"

status=0

warn() {
  printf 'warning: %s\n' "$*" >&2
}

fail() {
  printf 'error: %s\n' "$*" >&2
  status=1
}

github_mcp_enabled() {
  local f="$1"

  awk '
    function count_char(s, c,    n, i) {
      n = 0
      for (i = 1; i <= length(s); i++) {
        if (substr(s, i, 1) == c) n++
      }
      return n
    }
    /"github"[[:space:]]*:/ {
      in_github = 1
      disabled = 0
      depth = 0
    }
    in_github {
      if ($0 ~ /"disabled"[[:space:]]*:[[:space:]]*true/) disabled = 1
      depth += count_char($0, "{")
      depth -= count_char($0, "}")
      if (depth <= 0 && $0 ~ /}/) {
        done = 1
        exit disabled ? 1 : 0
      }
    }
    END {
      if (!done) exit 1
    }
  ' "$f"
}

check_mcp_configs() {
  local mcp_files
  mcp_files=$(find . \( -name 'mcp.json' -o -name '.mcp.json' -o -name 'opencode.jsonc' \) 2>/dev/null)

  for f in $mcp_files; do
    # Flag @latest in any MCP command definition.
    if grep -q '@latest' "$f"; then
      warn "MCP config $f contains @latest package reference; pin the version"
    fi

    # Flag remote MCP URLs without HTTPS.
    if grep -qE '"url":\s*"http://' "$f"; then
      warn "MCP config $f has a remote server URL without TLS"
    fi

    # Flag filesystem MCP servers with roots outside /workspace.
    if grep -qE '"filesystem"' "$f" && grep -qE '"roots"' "$f"; then
      if ! grep -qE '"/workspace' "$f"; then
        warn "MCP filesystem server in $f may have roots outside /workspace"
      fi
    fi

    # Flag MCP servers declared to run as root.
    if grep -qE '"user":\s*"root"' "$f"; then
      fail "MCP server in $f is declared to run as root"
    fi

    if [[ -n "${GITHUB_MCP_TOKEN:-}" ]] && github_mcp_enabled "$f"; then
      warn "GitHub MCP appears enabled in $f while GITHUB_MCP_TOKEN is set; use a least-privilege token with repo and read:org scopes"
    fi
  done
}

main() {
  local litellm_master_key_seen=0

  $COMPOSE_CMD --profile ide --profile web-terminal --profile codex --profile claude --profile cpu-llm config > "$config_file"

  if [[ -f .env ]]; then
    while IFS='=' read -r key value; do
      case "$key" in
        GITHUB_MCP_TOKEN)
          export GITHUB_MCP_TOKEN="$value"
          ;;
        TTYD_PASSWORD)
          case "$value" in
            change-me|"")
              fail "$key is a placeholder value; ttyd is started writable (-W), exposing a live shell"
              ;;
          esac
          ;;
        OPENCODE_SERVER_PASSWORD)
          case "$value" in
            change-me|"")
              warn "$key still uses a placeholder — opencode web UI is exposed without auth"
              ;;
          esac
          ;;
        OPENAI_API_KEY|CODE_SERVER_PASSWORD|LITELLM_MASTER_KEY|LITELLM_SALT_KEY|DEV_PASSWORD)
          if [[ "$key" == "LITELLM_MASTER_KEY" ]]; then
            litellm_master_key_seen=1
          fi
          case "$value" in
            change-me|change-me-salt|"")
              warn "$key still uses a placeholder value"
              ;;
          esac
          ;;
        LANGFUSE_NEXTAUTH_SECRET|LANGFUSE_SALT)
          case "$value" in
            change-me-langfuse|change-me-langfuse-salt|"")
              warn "$key still uses a placeholder value"
              ;;
          esac
          ;;
      esac
    done < <(grep -E '^[A-Z0-9_]+=' .env || true)
    if [[ "$litellm_master_key_seen" -eq 0 ]]; then
      fail "LITELLM_MASTER_KEY is missing from .env"
    fi
  else
    fail ".env is missing; run make init"
  fi

  if grep -q '/var/run/docker.sock' "$config_file"; then
    fail "Docker socket is mounted in the rendered Compose config"
  fi

  if grep -q 'host_ip: 0.0.0.0' "$config_file"; then
    warn "nginx is bound to 0.0.0.0; confirm LAN exposure is intended"
  fi

  if ! grep -q 'no-new-privileges:true' "$config_file"; then
    warn "no-new-privileges is not present in rendered Compose config"
  fi

  if ! awk '
  /^  agent:/ { in_service=1; found=0; next }
  /^  [A-Za-z0-9_-]+:/ {
    if (in_service && !found) exit 1
    in_service=0
  }
  in_service && /runtime: runsc/ { found=1 }
  END {
    if (in_service && !found) exit 1
  }
' "$config_file"; then
    warn "agent service is not using the runsc runtime"
  fi

  if ! awk '
  /^  web-terminal:/ { in_service=1; found=0; next }
  /^  [A-Za-z0-9_-]+:/ {
    if (in_service && !found) exit 1
    in_service=0
  }
  in_service && /runtime: runsc/ { found=1 }
  END {
    if (in_service && !found) exit 1
  }
' "$config_file"; then
    warn "web-terminal service is not using the runsc runtime"
  fi

  check_mcp_configs

  if grep -q 'bitnet:' "$config_file"; then
    if ! awk '
      /^  bitnet:/ { in_service=1; cpus=0; mem=0; next }
      /^  [A-Za-z0-9_-]+:/ { if (in_service && (!cpus || !mem)) exit 1; in_service=0 }
      in_service && /cpus:/ { cpus=1 }
      in_service && /memory:/ { mem=1 }
      END { if (in_service && (!cpus || !mem)) exit 1 }
    ' "$config_file"; then
      fail "bitnet service is missing deploy.resources.limits (cpus/memory); set these to prevent CPU exhaustion"
    fi
  fi

  if [[ ! -f .local/volumes/wireguard/wg_confs/wg0.conf ]]; then
    warn "WireGuard config is missing: .local/volumes/wireguard/wg_confs/wg0.conf"
  else
    mode="$(stat -c '%a' .local/volumes/wireguard/wg_confs/wg0.conf)"
    if [[ "$mode" != "600" ]]; then
      warn "WireGuard config permissions are $mode; expected 600"
    fi
  fi

  if [[ "$status" -eq 0 ]]; then
    echo "Security review checks completed."
  else
    echo "Security review found blocking issues." >&2
  fi

  exit "$status"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
