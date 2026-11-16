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

The `deploy/mini/` variant strips the stack down to the agent and nginx services, plus an optional LiteLLM gateway under the `onlineagents` profile. Configure a direct provider or explicitly enable the gateway for an external API. See `deploy/mini/README.md` for setup instructions.
