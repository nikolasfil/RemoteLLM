# syntax=docker/dockerfile:1.7

FROM node:22.13.1-bookworm-slim AS node-tools
ARG OPENCODE_VERSION=1.15.12
ARG SOCKET_VERSION=1.1.102
ARG INSTALL_CODEX_CLI=0
ARG CODEX_CLI_PACKAGE=
ARG INSTALL_CLAUDE_CODE=0
ARG CLAUDE_CODE_PACKAGE=
RUN --mount=type=cache,target=/root/.npm \
    packages="opencode-ai@${OPENCODE_VERSION} socket@${SOCKET_VERSION}" \
    && if [ "${INSTALL_CODEX_CLI}" = "1" ]; then \
         test -n "${CODEX_CLI_PACKAGE}" || { echo "CODEX_CLI_PACKAGE must be pinned when INSTALL_CODEX_CLI=1" >&2; exit 2; }; \
         packages="$packages ${CODEX_CLI_PACKAGE}"; \
       fi \
    && if [ "${INSTALL_CLAUDE_CODE}" = "1" ]; then \
         test -n "${CLAUDE_CODE_PACKAGE}" || { echo "CLAUDE_CODE_PACKAGE must be pinned when INSTALL_CLAUDE_CODE=1" >&2; exit 2; }; \
         packages="$packages ${CLAUDE_CODE_PACKAGE}"; \
       fi \
    && npm install -g $packages \
    && npm cache clean --force

FROM golang:1.26.2-bookworm AS go-tools
ARG OSV_SCANNER_VERSION=v2.3.8
ARG SCORECARD_VERSION=v5.2.1
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go install "github.com/google/osv-scanner/v2/cmd/osv-scanner@${OSV_SCANNER_VERSION}" \
    && go install "github.com/ossf/scorecard/v5@${SCORECARD_VERSION}"

FROM python:3.11.11-slim-bookworm AS python-tools
ARG PIP_AUDIT_VERSION=2.10.0
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefix=/opt/python-tools --no-compile "pip-audit==${PIP_AUDIT_VERSION}" \
    && sed -i '1s|^#!.*|#!/usr/bin/env python3|' /opt/python-tools/bin/pip-audit

FROM debian:bookworm-slim AS ttyd-bin
ARG TTYD_VERSION=1.7.7
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" -o /ttyd \
    && chmod +x /ttyd

FROM debian:bookworm-slim AS oh-my-zsh
ARG OH_MY_ZSH_REF=master
ARG ZSH_AUTOSUGGESTIONS_REF=v0.7.1
ARG ZSH_SYNTAX_HIGHLIGHTING_REF=0.8.0
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && git clone --depth 1 --branch "${OH_MY_ZSH_REF}" https://github.com/ohmyzsh/ohmyzsh.git /oh-my-zsh \
    && rm -rf /oh-my-zsh/.git \
    && git clone --depth 1 --branch "${ZSH_AUTOSUGGESTIONS_REF}" \
       https://github.com/zsh-users/zsh-autosuggestions.git \
       /oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && rm -rf /oh-my-zsh/custom/plugins/zsh-autosuggestions/.git \
    && git clone --depth 1 --branch "${ZSH_SYNTAX_HIGHLIGHTING_REF}" \
       https://github.com/zsh-users/zsh-syntax-highlighting.git \
       /oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
    && rm -rf /oh-my-zsh/custom/plugins/zsh-syntax-highlighting/.git

FROM debian:bookworm-slim AS mise-bin
ARG MISE_VERSION=2025.5.14
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64" \
       -o /usr/local/bin/mise \
    && chmod +x /usr/local/bin/mise

FROM debian:bookworm-slim AS neovim-bin
ARG NEOVIM_VERSION=0.11.0
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
       | tar -xz -C /opt \
    && mv /opt/nvim-linux-x86_64 /opt/nvim

FROM node:22.13.1-bookworm-slim AS runtime
ARG PUID=1000
ARG PGID=1000
ARG DEV_PASSWORD=change-me
ARG INSTALL_HERMES_AGENT=0
ARG HERMES_AGENT_VERSION=
ARG HERMES_INSTALL_METHOD=pypi

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    LC_CTYPE=C.UTF-8 \
    PATH="/opt/nvim/bin:/opt/python-tools/bin:/usr/local/bin:${PATH}" \
    PYTHONPATH="/opt/python-tools/lib/python3.11/site-packages" \
    HOME=/home/agent \
    SHELL=/usr/bin/zsh \
    ZSH=/opt/oh-my-zsh \
    ZSH_THEME=remotellm-agnoster

COPY docker/agent/apt-packages.txt /tmp/apt-packages.txt

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends $(grep -Ev '^\s*(#|$)' /tmp/apt-packages.txt) \
    && rm -rf /var/lib/apt/lists/*

RUN if ! getent group "${PGID}" >/dev/null; then groupadd --gid "${PGID}" agent; fi \
    && if getent passwd "${PUID}" >/dev/null; then \
         existing_user="$(getent passwd "${PUID}" | cut -d: -f1)" \
         && usermod --login agent --home /home/agent --move-home --shell /usr/bin/zsh "$existing_user" \
         && usermod --gid "${PGID}" agent; \
       else \
         useradd --uid "${PUID}" --gid "${PGID}" --create-home --shell /usr/bin/zsh agent; \
       fi \
    && mkdir -p /workspace/projects /workspace/inputs /workspace/outputs \
    && chown -R "${PUID}:${PGID}" /home/agent /workspace \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent \
    && useradd --uid 1001 --gid "${PGID}" --create-home --shell /usr/bin/zsh dev \
    && echo "dev:${DEV_PASSWORD}" | chpasswd \
    && echo "dev ALL=(ALL:ALL) ALL" > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

COPY --from=node-tools /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node-tools /usr/local/bin /usr/local/bin
COPY --from=go-tools /go/bin/osv-scanner /usr/local/bin/osv-scanner
COPY --from=go-tools /go/bin/scorecard /usr/local/bin/scorecard
COPY --from=python-tools /opt/python-tools /opt/python-tools
COPY --from=ttyd-bin /ttyd /usr/local/bin/ttyd
COPY --from=oh-my-zsh /oh-my-zsh /opt/oh-my-zsh
COPY --from=mise-bin /usr/local/bin/mise /usr/local/bin/mise
COPY --from=neovim-bin /opt/nvim /opt/nvim

# Hermes install runs before the volatile local COPYs below (scripts/container,
# config/agent/*) so editing those files never invalidates this expensive layer.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/root/.npm \
    if [ "${INSTALL_HERMES_AGENT}" = "1" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends python3 python3-venv ripgrep ffmpeg curl; \
      if [ "${HERMES_INSTALL_METHOD}" = "official" ]; then \
        mkdir -p /opt/hermes-home \
        && curl -fsSL https://hermes-agent.nousresearch.com/install.sh | HOME=/opt/hermes-home bash \
        && test -x /usr/local/bin/hermes || { echo "Official hermes install did not produce a hermes binary" >&2; exit 2; } \
        && cd /usr/local/lib/hermes-agent \
        && npm install --workspace web --workspace ui-tui \
        && npm run build -w web \
        && npm run build -w ui-tui \
        && chown -R "${PUID}:${PGID}" /usr/local/lib/hermes-agent /opt/hermes-home; \
      else \
        test -n "${HERMES_AGENT_VERSION}" || { echo "HERMES_AGENT_VERSION must be set when HERMES_INSTALL_METHOD=pypi" >&2; exit 2; }; \
        python3 -m venv /opt/hermes \
        && /opt/hermes/bin/pip install --no-cache-dir "hermes-agent[messaging]==${HERMES_AGENT_VERSION}" python-multipart \
        && ln -sf /opt/hermes/bin/hermes /usr/local/bin/hermes; \
      fi; \
    fi

COPY config/agent/themes/remotellm-agnoster.zsh-theme /opt/oh-my-zsh/custom/themes/remotellm-agnoster.zsh-theme
COPY scripts/container/ /usr/local/bin/
COPY config/agent/AGENTS.md /etc/remotellm/AGENTS.md
COPY config/agent/remotellm.zsh /etc/remotellm/remotellm.zsh
COPY config/agent/tmux.conf /etc/remotellm/tmux.conf
COPY config/agent/skills/ /etc/remotellm/skills/
COPY config/agent/opencode/ /etc/remotellm/opencode/
COPY config/agent/claude/ /etc/remotellm/claude/
COPY config/agent/codex/ /etc/remotellm/codex/
COPY config/agent/hermes/ /etc/remotellm/hermes/
COPY config/agent/hermes-skills/ /etc/remotellm/hermes-skills/

RUN chmod +x /usr/local/bin/setup-agent /usr/local/bin/safe-npm-install /usr/local/bin/safe-pip-install /usr/local/bin/safe-package-check /usr/local/bin/safe-dev-env-check \
    && chmod +x /usr/local/bin/run-codex-agent /usr/local/bin/run-claude-agent /usr/local/bin/run-hermes-agent /usr/local/bin/dispatch-cli \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd

USER agent
WORKDIR /workspace/projects
ENTRYPOINT ["/usr/bin/tini", "--", "setup-agent"]
CMD ["zsh", "-l"]
