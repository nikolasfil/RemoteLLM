#!/usr/bin/env bash
# Build (or pull) images referenced by deploy/mini/compose.yml on this machine,
# then pipe them over SSH to the mini PC. No build step runs on the Celeron.
#
# Usage:
#   MINI_HOST=user@192.168.x.x ./scripts/push-images-to-mini.sh
#   MINI_HOST=user@mini-pc.tailnet ./scripts/push-images-to-mini.sh
#
# Environment:
#   MINI_HOST       (required) SSH destination for the mini PC
#   COMPOSE_FILE    path to the mini compose file (default: deploy/mini/compose.yml)
#   BUILD           set to 1 to (re)build images before transferring (default: 1)
#   SSH_OPTS        extra SSH options (e.g. "-i ~/.ssh/id_mini")

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$REPO_ROOT/deploy/mini/compose.yml}"
BUILD="${BUILD:-1}"
SSH_OPTS="${SSH_OPTS:-}"

if [ -z "${MINI_HOST:-}" ]; then
    printf 'Error: MINI_HOST is not set.\n' >&2
    printf 'Usage: MINI_HOST=user@host %s\n' "$0" >&2
    exit 1
fi

log() { printf '\n\033[1;34m[push-images]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }

cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Step 1: Build images on this machine
# ---------------------------------------------------------------------------
if [ "$BUILD" = "1" ]; then
    log "Building images from $COMPOSE_FILE"
    docker compose -f "$COMPOSE_FILE" build
    ok "build complete"
fi

# ---------------------------------------------------------------------------
# Step 2: Collect image names from the compose file
# ---------------------------------------------------------------------------
log "Resolving image names"
IMAGES=$(docker compose -f "$COMPOSE_FILE" config --images 2>/dev/null)

if [ -z "$IMAGES" ]; then
    printf 'Error: no images found in %s\n' "$COMPOSE_FILE" >&2
    exit 1
fi

printf '  Images to transfer:\n'
printf '    %s\n' $IMAGES

# ---------------------------------------------------------------------------
# Step 3: Save + pipe images to the mini PC over SSH
# ---------------------------------------------------------------------------
log "Transferring images to $MINI_HOST"
printf '  (piping via SSH — no intermediate file on either side)\n'

# shellcheck disable=SC2086
docker save $IMAGES | gzip | ssh $SSH_OPTS "$MINI_HOST" 'docker load'

ok "all images loaded on $MINI_HOST"

# ---------------------------------------------------------------------------
# Step 4: Remind about next steps
# ---------------------------------------------------------------------------
log "Done"
printf '\nOn the mini PC, start (or restart) the stack:\n'
printf '  cd deploy/mini\n'
printf '  docker compose up -d\n'
