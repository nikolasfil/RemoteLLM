#!/bin/sh
set -e

BITNET_MODEL="${BITNET_MODEL:-/models/ggml-model-i2_s.gguf}"
BITNET_CTX_SIZE="${BITNET_CTX_SIZE:-4096}"
BITNET_THREADS="${BITNET_THREADS:-4}"

exec /app/llama-server \
    --model "$BITNET_MODEL" \
    --ctx-size "$BITNET_CTX_SIZE" \
    --threads "$BITNET_THREADS" \
    --host 0.0.0.0 \
    --port 8080
