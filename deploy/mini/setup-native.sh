#!/usr/bin/env bash
# Native (non-Docker) setup for the mini PC.
# Installs: zsh, oh-my-zsh, neovim, btop, ranger, opencode.
# Writes opencode config pointing at LiteLLM and a .env template.
#
# Requires: Debian/Ubuntu-based Linux, sudo access.
# Idempotent — safe to re-run.

set -euo pipefail

OPENCODE_VERSION="${OPENCODE_VERSION:-1.15.12}"
LITELLM_URL="${LITELLM_URL:-http://127.0.0.1:4000/v1}"
LITELLM_API_KEY="${LITELLM_API_KEY:-change-me}"
HERMES_MODEL="${HERMES_MODEL:-hermes}"

log() { printf '\n\033[1;34m[setup-native]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Phase 1: Shell environment (zsh, oh-my-zsh, neovim, btop, ranger)
# ---------------------------------------------------------------------------
log "Phase 1: shell environment"

sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
    zsh \
    btop \
    ranger \
    curl \
    git \
    ca-certificates

ok "system packages installed"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing oh-my-zsh"
    RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "oh-my-zsh installed"
else
    ok "oh-my-zsh already present"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone --depth 1 \
        https://github.com/zsh-users/zsh-autosuggestions.git \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    ok "zsh-autosuggestions installed"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone --depth 1 \
        https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    ok "zsh-syntax-highlighting installed"
fi

if ! grep -q "zsh-autosuggestions" "$HOME/.zshrc" 2>/dev/null; then
    sed -i 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting)/' \
        "$HOME/.zshrc" 2>/dev/null || true
fi

# Neovim — prefer AppImage for a current stable version
if ! command -v nvim &>/dev/null; then
    log "Installing Neovim"
    sudo apt-get install -y --no-install-recommends neovim || {
        log "apt neovim unavailable, falling back to AppImage"
        NVIM_TMP=$(mktemp -d)
        curl -fsSL \
            "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" \
            | tar -xz -C "$NVIM_TMP"
        sudo mv "$NVIM_TMP"/nvim-linux-x86_64 /opt/nvim
        sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
        rm -rf "$NVIM_TMP"
    }
    ok "neovim installed"
else
    ok "neovim already present ($(nvim --version | head -1))"
fi

# ---------------------------------------------------------------------------
# Phase 2: opencode binary install
# ---------------------------------------------------------------------------
log "Phase 2: opencode install"

if ! command -v node &>/dev/null; then
    log "Node.js not found — installing via NodeSource (LTS)"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y --no-install-recommends nodejs
    ok "Node.js installed"
fi

if ! command -v opencode &>/dev/null || \
   ! opencode --version 2>/dev/null | grep -q "${OPENCODE_VERSION}"; then
    log "Installing opencode@${OPENCODE_VERSION}"
    sudo npm install -g "opencode-ai@${OPENCODE_VERSION}"
    ok "opencode installed"
else
    ok "opencode already at ${OPENCODE_VERSION}"
fi

# ---------------------------------------------------------------------------
# Phase 3: opencode config pointing at LiteLLM proxy
# ---------------------------------------------------------------------------
log "Phase 3: opencode config"

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG="$OPENCODE_CONFIG_DIR/opencode.jsonc"
mkdir -p "$OPENCODE_CONFIG_DIR"

if [ ! -f "$OPENCODE_CONFIG" ]; then
    cat > "$OPENCODE_CONFIG" <<EOF
{
  "\$schema": "https://opencode.ai/config.schema.json",
  "share": "disabled",
  "provider": {
    "litellm": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LiteLLM (mini)",
      "options": {
        "baseURL": "${LITELLM_URL}",
        "apiKey": "{env:OPENAI_API_KEY}"
      },
      "models": {
        "${HERMES_MODEL}": {
          "name": "Hermes (remote)"
        }
      }
    }
  },
  "model": "litellm/${HERMES_MODEL}",
  "disabled_providers": ["openai", "anthropic", "google", "bedrock", "azure"]
}
EOF
    ok "opencode config written to $OPENCODE_CONFIG"
else
    ok "opencode config already exists — skipping (edit manually if needed)"
fi

# ---------------------------------------------------------------------------
# Phase 4: .env template with HERMES_API_KEY placeholder
# ---------------------------------------------------------------------------
log "Phase 4: environment file"

ENV_FILE="$HOME/.config/remotellm-mini.env"

if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" <<'EOF'
# Source this file before running opencode natively:
#   source ~/.config/remotellm-mini.env
#
# Fill in the values below before sourcing.

# LiteLLM API key (LITELLM_MASTER_KEY set in deploy/mini/.env).
export OPENAI_API_KEY=change-me

# LiteLLM base URL — use 127.0.0.1:4000 (direct) or :8088/api/litellm (via nginx).
export OPENAI_BASE_URL=http://127.0.0.1:4000/v1
EOF
    ok "env template written to $ENV_FILE"
    printf '\033[1;33m  → Edit %s and add your LITELLM_MASTER_KEY as OPENAI_API_KEY.\033[0m\n' "$ENV_FILE"
else
    ok "env file already exists at $ENV_FILE"
fi

# ---------------------------------------------------------------------------
# Phase 5: optional Docker install
# ---------------------------------------------------------------------------
log "Phase 5: Docker (optional)"

if command -v docker &>/dev/null; then
    ok "Docker already installed ($(docker --version))"
else
    printf '\033[1;33m  Docker not found. To install Docker for the hybrid (Docker + native) mode:\033[0m\n'
    printf '  curl -fsSL https://get.docker.com | sh\n'
    printf '  sudo usermod -aG docker %s\n' "$USER"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log "Setup complete"
printf '\nNext steps:\n'
printf '  1. Source the env file:  source %s\n' "$ENV_FILE"
printf '  2. Start LiteLLM:        cd deploy/mini && docker compose up -d litellm\n'
printf '  3. Run opencode:         opencode\n'
printf '\nOr use zsh as your default shell:  chsh -s /usr/bin/zsh\n'
