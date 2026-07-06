# Deploy Variants

Two compose variants are maintained, side-by-side, for different hardware targets.

## Variants

| Variant | Path | Hardware target |
|---------|------|-----------------|
| Full | `compose.yml` (repo root) | GPU workstation / server with ≥16 GB RAM |
| Mini | `deploy/mini/compose.yml` | Intel Celeron, 2 cores, 8 GB RAM, no GPU |

## Full stack

The root `compose.yml` is the full stack. See `deploy/full/README.md` for details and hardware requirements.

## Mini stack

The `deploy/mini/` variant strips the stack down to the three services that fit on the Celeron: nginx, LiteLLM, and the agent. LLM inference is handled by an external Hermes API rather than a local model. See `deploy/mini/README.md` for setup instructions.
