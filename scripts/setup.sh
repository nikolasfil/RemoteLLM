#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

seed_if_missing() {
  local src="$1" dst="$2"
  [[ -f "$dst" ]] && return 0
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

ensure_writable_dir() {
  local dir="$1"
  mkdir -p "$dir"
  if [[ ! -w "$dir" && -z "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    rmdir "$dir"
    mkdir -p "$dir"
  fi
}

mkdir -p \
  "$ROOT_DIR/.local/volumes/mise-cache" \
  "$ROOT_DIR/.local/volumes/langfuse/postgres" \
  "$ROOT_DIR/.local/volumes/langfuse/clickhouse" \
  "$ROOT_DIR/.local/volumes/langfuse/minio" \
  "$ROOT_DIR/.local/volumes/langfuse/redis"

ensure_writable_dir "$ROOT_DIR/.local/volumes/devbox-cache"
ensure_writable_dir "$ROOT_DIR/.local/volumes/nix"

seed_if_missing \
  "$ROOT_DIR/config/continue/config.yaml" \
  "$ROOT_DIR/.local/volumes/vscode-config/continue/config.yaml"

seed_if_missing \
  "$ROOT_DIR/config/code-server/settings.json" \
  "$ROOT_DIR/.local/volumes/vscode-config/Code/User/settings.json"

exec "$ROOT_DIR/scripts/setup-host.sh" "$@"
