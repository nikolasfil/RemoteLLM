# BitNet CPU Inference

BitNet provides GPU-free local model inference using Microsoft's BitNet.cpp engine. It runs under the `cpu-llm` Compose profile and is proxied through LiteLLM as the `bitnet-2b` model alias. It is designed as an offline fallback when the remote Ollama GPU endpoint is unavailable.

## Features

- CPU-only inference — no GPU required at all
- 1-bit (ternary) weight quantization: ~0.4 GB RAM for the 2B model (non-embedding)
- OpenAI-compatible API via `llama-server` (BitNet.cpp's built-in server)
- LiteLLM integration: agents use `bitnet-2b` like any other model alias
- Configurable thread count and context size via environment variables
- Health check on `http://localhost:8080/health`
- Resource limits: 4 CPU cores, 4 GB RAM (enforced in Compose)
- Works offline — no VPN or internet required once the model is downloaded

## How It Works

BitNet.cpp uses 1-bit (ternary: -1, 0, +1) weights natively trained in this format. This is not post-hoc quantization of a float16 model; only models specifically trained in 1-bit format are compatible.

The `bitnet` service runs `llama-server` — BitNet.cpp's built-in inference server that exposes an OpenAI-compatible API at port 8080. LiteLLM proxies it via the `openai` provider:

```yaml
- model_name: bitnet-2b
  litellm_params:
    model: openai/bitnet-2b
    api_base: http://bitnet:8080
    api_key: "none"
```

## Functionalities

### Downloading a Model

Before starting the service, download a compatible GGUF model file. The recommended starting model:

```sh
# Install huggingface-cli if needed
pip install huggingface-hub

# Download the 2B model
huggingface-cli download microsoft/bitnet-b1.58-2B-4T-gguf \
  --local-dir ./models/bitnet/
```

The model files land in `./models/bitnet/` and are mounted read-only into the container.

### Starting BitNet

```sh
docker compose --profile cpu-llm up -d bitnet
```

The `make up-full` target starts all profiles including `cpu-llm`.

### Configuration

```dotenv
BITNET_MODEL=/models/ggml-model-i2_s.gguf   # path inside container
BITNET_CTX_SIZE=4096                          # context window in tokens
BITNET_THREADS=4                              # CPU threads for inference
```

Adjust `BITNET_THREADS` to match available CPU cores. More threads → faster tokens/second, up to the core count.

### Using BitNet from an Agent

From inside the agent container:

```sh
# Direct API test
curl -s http://bitnet:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"bitnet-2b","messages":[{"role":"user","content":"hello"}]}'

# Through LiteLLM
curl -s http://litellm:4000/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"bitnet-2b","messages":[{"role":"user","content":"hello"}]}'
```

To use BitNet in OpenCode, switch the model alias to `bitnet-2b`. To use it in Continue, update the model field in the Continue config.

### Health Check

```sh
docker compose ps bitnet
curl -s http://127.0.0.1:4000/v1/models | jq '.data[].id'
```

The container takes up to 60 seconds on first load while `llama-server` reads the model file.

## Available Models

Only natively 1-bit-trained models are compatible with BitNet.cpp.

| Model | Params | CPU RAM | Notes |
|---|---|---|---|
| `microsoft/bitnet-b1.58-2B-4T-gguf` | 2B | ~1–2 GB | Default; stable and fast |
| `HF1BitLLM/Llama3-8B-1.58-100B-tokens` | 8B | ~4–5 GB | Best coding quality |
| `tiiuae/Falcon3-7B-Instruct-1.58bit` | 7B | ~3–4 GB | Best reasoning option |

Start with the 2B model. Use 8B+ only if RAM allows.

**Performance (approximate, modern CPU):**

- 2B model: 5–20 tokens/second on 4–8 cores
- 8B model: 2–8 tokens/second on 4–8 cores
- AVX-512 (Intel) gives 2–6× speedup over AVX2

## Limitations

- **Only native 1-bit models.** Arbitrary float16 models cannot be quantized into BitNet format. The model selection is small compared to Ollama.
- **4,096 token default context.** The 2B model's context is limited. Increase `BITNET_CTX_SIZE` at the cost of more RAM (diminishing performance above 8k).
- **Single-user throughput.** CPU inference is single-threaded per request. 5–20 t/s is fine for one agent; concurrent requests queue and slow down significantly.
- **Build complexity.** The BitNet Dockerfile uses Clang 18 (GCC is not supported). The build image is ~10 GB; the runtime image ~2 GB. First build takes 10–20 minutes.
- **ARM64 known bug.** `ggml-bitnet-mad.cpp` line 811 has a known ARM64 issue. The Dockerfile includes a workaround. Performance on ARM may be lower than the published benchmarks.
- **Limited non-English quality.** Microsoft reports elevated error rates on non-English prompts, particularly for the 2B model.
- **LiteLLM starts cleanly without BitNet.** The `cpu-llm` profile is opt-in. Requests to `bitnet-2b` fail with a 502 when BitNet is not running; other model aliases are unaffected.

## Hardware Requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| CPU architecture | x86-64 with AVX2 | x86-64 with AVX-512 or ARM with NEON |
| CPU cores | 2 | 4–8 |
| System RAM (2B model) | 4 GB | 8 GB |
| System RAM (8B model) | 8 GB | 16 GB |
| Disk (model files) | 1 GB | 2 GB |
| GPU | Not needed | Not needed |

The Compose resource limits enforce `cpus: "4"` and `memory: 4g`. Adjust in `compose.yml` for larger models.
