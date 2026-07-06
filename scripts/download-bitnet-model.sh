#!/usr/bin/env bash
# Download a BitNet GGUF model from HuggingFace into ./models/bitnet/.
# Requires: huggingface-cli (pip install huggingface_hub)
#
# Usage:
#   ./scripts/download-bitnet-model.sh           # 2B model (default, ~400 MB)
#   ./scripts/download-bitnet-model.sh 8b        # 8B Llama3 coding model (~2 GB)
#
# The downloaded file is mounted into the bitnet container at /models/ via the
# ./models/bitnet bind mount defined in compose.yml.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT_DIR/models/bitnet"

if ! command -v huggingface-cli &>/dev/null; then
  echo "error: huggingface-cli not found. Install with: pip install huggingface_hub" >&2
  exit 1
fi

VARIANT="${1:-2b}"

mkdir -p "$DEST"

case "$VARIANT" in
  2b|2B)
    REPO="microsoft/bitnet-b1.58-2B-4T-gguf"
    FILE="ggml-model-i2_s.gguf"
    ;;
  8b|8B)
    REPO="HF1BitLLM/Llama3-8B-1.58-100B-tokens-GGUF"
    FILE="ggml-model-i2_s.gguf"
    ;;
  *)
    echo "error: unknown variant '$VARIANT'. Use '2b' or '8b'." >&2
    exit 1
    ;;
esac

echo "Downloading $FILE from $REPO into $DEST ..."
huggingface-cli download "$REPO" "$FILE" --local-dir "$DEST"
echo "Done. Model saved to $DEST/$FILE"
echo ""
echo "Set BITNET_MODEL=/models/$FILE in .env if you changed from the default 2B model."
