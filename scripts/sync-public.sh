#!/usr/bin/env bash
# Mirrors this (private) repo into the public release repo checkout.
#
# Safety model: this script NEVER runs the real sync unless --execute is
# passed. Without it, rsync runs with --dry-run so you can review exactly
# what would change before anything touches the destination.
#
# Usage:
#   ./scripts/sync-public.sh                # dry run against ../Public-RemoteLLM
#   ./scripts/sync-public.sh --execute       # perform the real sync
#   ./scripts/sync-public.sh --execute /path/to/other/checkout
#
# What gets excluded (see below for the full list):
#   - docs/dev/                 internal planning notes, not for public release
#   - .claude/ .codex/           local agent-tool state, not project source
#   - graphify-out/              local graphify output, regenerable
#   - .env, .local/, .venvs/     live secrets and machine-local runtime state
#   - models/                    downloaded model weights (large, user-local)
#   - .git/                      never touch the destination's own git history
#
# rsync --delete keeps the destination in sync with source deletions, but
# never deletes anything matching an --exclude pattern (so the destination's
# own .git/ and anything else excluded below is always safe).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="${REPO_ROOT}/../Public-RemoteLLM"
DRY_RUN=1

for arg in "$@"; do
  case "$arg" in
    --execute)
      DRY_RUN=0
      ;;
    --help|-h)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      DEST_DIR="$arg"
      ;;
  esac
done

if [[ ! -d "$DEST_DIR" ]]; then
  echo "Error: destination '$DEST_DIR' does not exist. Create/clone the public repo checkout first." >&2
  exit 1
fi

if [[ ! -d "$DEST_DIR/.git" ]]; then
  echo "Error: '$DEST_DIR' does not look like a git checkout (.git missing)." >&2
  echo "Refusing to rsync into a directory that isn't the public repo, to avoid clobbering something unrelated." >&2
  exit 1
fi

EXCLUDES=(
  # Never touch the destination's own git history.
  ".git/"

  # Internal-only documentation.
  "docs/dev/"

  # Local agent-tool state; not project source.
  ".claude/"
  ".codex/"

  # Local graphify output; regenerable, not source.
  "graphify-out/"

  # Live secrets / credentials.
  ".env"
  ".local/"

  # Machine-local runtime and build artifacts.
  ".venvs/"
  ".cache/"

  # Downloaded model weights; large and user-local.
  "models/"

  # Generated docs site build output.
  "config/nginx/html/docs/"

  # Editor/OS noise.
  ".DS_Store"
  "*.log"
)

RSYNC_ARGS=(-av --delete)
if [[ "$DRY_RUN" -eq 1 ]]; then
  RSYNC_ARGS+=(--dry-run)
fi

for pattern in "${EXCLUDES[@]}"; do
  RSYNC_ARGS+=(--exclude "$pattern")
done

echo "Source:      $REPO_ROOT/"
echo "Destination: $DEST_DIR/"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Mode:        DRY RUN (no files will be changed; pass --execute to apply)"
else
  echo "Mode:        EXECUTE (destination will be modified)"
fi
echo

rsync "${RSYNC_ARGS[@]}" "$REPO_ROOT/" "$DEST_DIR/"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo
  echo "Dry run complete. Review the output above, then re-run with --execute to apply."
fi
