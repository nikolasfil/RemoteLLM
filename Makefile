SHELL := /usr/bin/env bash
COMPOSE ?= docker compose
PROJECT ?= remotellm
BACKUP_ROOT ?= .local/backups
BACKUP_FILE ?= $(BACKUP_ROOT)/remotellm_$$(date +%F_%H%M%S).tar.gz

.DEFAULT_GOAL := help

# ── Setup ──────────────────────────────────────────────────────────────────

init:
	./scripts/setup.sh

wireguard-config:
	COPY_WIREGUARD_CONFIG=1 ./scripts/setup.sh

# ── Build ──────────────────────────────────────────────────────────────────

build:
	$(COMPOSE) build

build-agent:
	$(COMPOSE) build agent

build-bitnet:
	$(COMPOSE) --profile cpu-llm build bitnet

# ── Start ──────────────────────────────────────────────────────────────────

up:
	$(COMPOSE) up -d

up-vpn:
	$(COMPOSE) --profile vpn up -d wireguard vpn-proxy

up-ide:
	$(COMPOSE) --profile ide --profile web-terminal up -d

up-nix:
	$(COMPOSE) --profile nix up -d nix-agent

up-opencode-web:
	$(COMPOSE) --profile opencode-web up -d

up-hermes-web:
	$(COMPOSE) --profile hermes-web up -d

up-observability:
	$(COMPOSE) --profile observability up -d

up-playwright:
	$(COMPOSE) --profile playwright up -d

up-cpu-llm:
	$(COMPOSE) --profile cpu-llm up -d bitnet

up-full:
	$(COMPOSE) --profile vpn --profile ide --profile web-terminal --profile codex --profile claude --profile hermes --profile hermes-web --profile opencode-web --profile observability --profile playwright --profile nix --profile cpu-llm up -d

# ── Stop ───────────────────────────────────────────────────────────────────

down:
	$(COMPOSE) down

down-vpn:
	$(COMPOSE) --profile vpn stop vpn-proxy wireguard

down-full:
	$(COMPOSE) --profile vpn --profile ide --profile web-terminal --profile codex --profile claude --profile hermes --profile hermes-web --profile opencode-web --profile observability --profile playwright --profile nix --profile cpu-llm down --remove-orphans

# ── Logs & Status ──────────────────────────────────────────────────────────

ps:
	$(COMPOSE) ps

status:
	$(COMPOSE) ps
	-$(COMPOSE) exec wireguard wg show

logs:
	$(COMPOSE) logs -f

logs-agent:
	$(COMPOSE) logs -f agent

logs-langfuse:
	$(COMPOSE) logs -f langfuse-web langfuse-worker

logs-nginx:
	$(COMPOSE) logs -f nginx

# ── Agents ─────────────────────────────────────────────────────────────────

agent:
	$(COMPOSE) exec agent opencode

codex:
	$(COMPOSE) --profile codex run --rm codex

claude:
	$(COMPOSE) --profile claude run --rm claude

hermes:
	$(COMPOSE) --profile hermes run --rm hermes

# ── Shells ─────────────────────────────────────────────────────────────────

shell:
	$(COMPOSE) exec agent zsh -l

shell-nix:
	$(COMPOSE) --profile nix exec nix-agent zsh -l

devbox-shell:
	$(COMPOSE) --profile nix exec nix-agent devbox shell

# ── Health & Security ──────────────────────────────────────────────────────

test-vpn:
	$(COMPOSE) exec agent sh -lc 'curl -fsS --proxy "$${OLLAMA_PROXY:-socks5h://wireguard:1080}" "$${OLLAMA_BASE_URL:-http://ollama.example.internal:11434}/api/tags"'

audit-deps:
	$(COMPOSE) exec agent safe-package-check /workspace/projects

check-dev-env:
	$(COMPOSE) exec agent safe-dev-env-check /workspace/projects

security-review:
	./scripts/security-review.sh

security-review-mcp:
	@bash -c 'source scripts/security-review.sh && check_mcp_configs; exit "$$status"'

# ── Operations ─────────────────────────────────────────────────────────────

refresh-agent:
	$(COMPOSE) exec agent setup-agent true

restart-litellm:
	$(COMPOSE) restart litellm

download-bitnet-model:
	./scripts/download-bitnet-model.sh

litellm-keys:
	@[ -n "$$LITELLM_MASTER_KEY" ] || { echo "Error: LITELLM_MASTER_KEY is not set. Run: export LITELLM_MASTER_KEY=<your-key>"; exit 1; }
	@echo "Creating virtual keys via LiteLLM API..."
	@AGENT=$$(curl -sf -X POST http://127.0.0.1:8088/api/litellm/key/generate \
	  -H "Authorization: Bearer $$LITELLM_MASTER_KEY" \
	  -H "Content-Type: application/json" \
	  -d '{"key_alias":"agents","models":["ollama-default"],"rpm_limit":60}' | jq -r '.key') && \
	HERMES=$$(curl -sf -X POST http://127.0.0.1:8088/api/litellm/key/generate \
	  -H "Authorization: Bearer $$LITELLM_MASTER_KEY" \
	  -H "Content-Type: application/json" \
	  -d '{"key_alias":"hermes","models":["hermes"],"rpm_limit":30}' | jq -r '.key') && \
	CLAUDE=$$(curl -sf -X POST http://127.0.0.1:8088/api/litellm/key/generate \
	  -H "Authorization: Bearer $$LITELLM_MASTER_KEY" \
	  -H "Content-Type: application/json" \
	  -d '{"key_alias":"claude-agent","models":["claude-default"],"rpm_limit":20}' | jq -r '.key') && \
	echo "" && \
	echo "Add these to .env:" && \
	echo "AGENT_VIRTUAL_KEY=$$AGENT" && \
	echo "HERMES_VIRTUAL_KEY=$$HERMES" && \
	echo "CLAUDE_VIRTUAL_KEY=$$CLAUDE"

backup:
	mkdir -p "$(BACKUP_ROOT)"
	tar -czf "$(BACKUP_FILE)" .local/volumes .local/workspace/outputs
	@echo "Wrote $(BACKUP_FILE)"

config:
	$(COMPOSE) config

docs:
	./scripts/build-docs.sh

# ── Help ───────────────────────────────────────────────────────────────────

help:
	@printf '%s\n' \
	  'RemoteLLM — docker compose workspace for running coding agents via WireGuard' \
	  '' \
	  'Setup' \
	  '  make init                  Create .env and .local runtime directories' \
	  '  make wireguard-config      Copy WIREGUARD_SOURCE into wg_confs/wg0.conf' \
	  '' \
	  'Build' \
	  '  make build                 Build all custom images' \
	  '  make build-agent           Rebuild only the agent image (also used by codex, claude, web-terminal)' \
	  '  make build-bitnet          Build the BitNet CPU inference image (cpu-llm profile)' \
	  '' \
	  'Start' \
	  '  make up                    Core stack (litellm, agent, nginx; VPN stays off)' \
	  '  make up-vpn                Manually start WireGuard and vpn-proxy' \
	  '  make up-ide                Core + browser IDE (code-server) + web terminal (ttyd)' \
	  '  make up-nix                Nix-enabled agent (devbox support)' \
	  '  make up-hermes-web         Hermes dashboard UI at /hermes/' \
	  '  make up-opencode-web       OpenCode browser UI on port 4040' \
	  '  make up-observability      Langfuse tracing stack on port 3000' \
	  '  make up-playwright         Playwright MCP for browser-driven agent tasks' \
	  '  make up-cpu-llm            BitNet CPU-only LLM (run make download-bitnet-model first)' \
	  '  make up-full               All profiles at once, including VPN' \
	  '' \
	  'Agents' \
	  '  make agent                 Run opencode in the agent container' \
	  '  make codex                 Run Codex CLI (set INSTALL_CODEX_CLI=1 and rebuild first)' \
	  '  make claude                Run Claude Code (set INSTALL_CLAUDE_CODE=1 and rebuild first)' \
	  '  make hermes                Run Hermes Agent (set INSTALL_HERMES_AGENT=1 and rebuild first)' \
	  '' \
	  'Shells' \
	  '  make shell                 zsh in the main agent container' \
	  '  make shell-nix             zsh in the Nix-enabled agent (run make up-nix first)' \
	  '  make devbox-shell          devbox shell in the Nix-enabled agent' \
	  '' \
	  'Logs & Status' \
	  '  make ps                    List running containers' \
	  '  make status                Containers + WireGuard peer state' \
	  '  make logs                  Follow all container logs' \
	  '  make logs-agent            Follow agent logs' \
	  '  make logs-langfuse         Follow Langfuse web and worker logs' \
	  '  make logs-nginx            Follow nginx logs' \
	  '' \
	  'Health & Security' \
	  '  make test-vpn              Probe Ollama through the VPN proxy' \
	  '  make audit-deps            Check workspace projects for vulnerable dependencies' \
	  '  make check-dev-env         Report dev environment files in workspace projects' \
	  '  make security-review       Check rendered Compose config for exposure risks' \
	  '  make security-review-mcp   Check MCP config files for common risks' \
	  '' \
	  'Operations' \
	  '  make refresh-agent         Re-run setup-agent to update the shell profile in a live container' \
	  '  make restart-litellm       Restart the LiteLLM gateway (needed after adding Langfuse keys)' \
	  '  make download-bitnet-model Download the 2B BitNet GGUF model into models/bitnet/' \
	  '  make litellm-keys          Generate per-role virtual keys and print values for .env' \
	  '  make backup                Archive .local/volumes and outputs to .local/backups/' \
	  '  make config                Print the rendered Docker Compose configuration' \
	  '  make docs                  Rebuild the static docs site served at /docs/ (run after editing docs/)' \
	  '' \
	  'Stop' \
	  '  make down                  Stop the core stack' \
	  '  make down-vpn              Stop WireGuard and vpn-proxy' \
	  '  make down-full             Stop all profiles and remove orphan containers'

.PHONY: init wireguard-config \
        build build-agent build-bitnet \
        up up-vpn up-ide up-nix up-hermes-web up-opencode-web up-observability up-playwright up-cpu-llm up-full \
        down down-vpn down-full \
        ps status logs logs-agent logs-langfuse logs-nginx \
        agent codex claude hermes \
        shell shell-nix devbox-shell \
        test-vpn audit-deps check-dev-env security-review security-review-mcp \
        refresh-agent restart-litellm litellm-keys download-bitnet-model backup config docs help
