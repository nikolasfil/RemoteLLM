# syntax=docker/dockerfile:1.7
#
# Stage layout (BuildKit builds independent stages in parallel and caches each
# one on its own, so bumping one tool only rebuilds that tool's stage):
#
#   npm-opencode / npm-codex / npm-claude / npm-pi   one stage per npm tool
#   go-tools, python-tools                           security scanners
#   fetch -> ttyd-bin, jcode-bin, oh-my-zsh,         release-binary downloads
#            mise-bin, uv-bin, neovim-bin
#   base -> hermes -> runtime                        final image: base OS layer,
#                                                    Hermes, then tool COPYs and
#                                                    local config (changes most)
#
# Hermes sits before the tool COPYs on purpose: it is the slowest step, so a
# tool version bump must not invalidate it.

ARG GO_VERSION=1.26.2
# Node >=22.19 is required by @earendil-works/pi-coding-agent. One version for
# the npm stages and the runtime base so the copied tools run on the same Node
# they were installed with.
ARG NODE_IMAGE=node:22.20.0-bookworm-slim

# ── npm tools: one stage each, installed into its own prefix ────────────────
# A disabled tool leaves an empty /opt/npm/<tool> so the runtime COPY is valid.

FROM ${NODE_IMAGE} AS npm-opencode
ARG OPENCODE_VERSION=1.15.12
ARG SOCKET_VERSION=1.1.102
RUN --mount=type=cache,target=/root/.npm \
    npm install -g --prefix /opt/npm/opencode "opencode-ai@${OPENCODE_VERSION}" "socket@${SOCKET_VERSION}"

FROM ${NODE_IMAGE} AS npm-codex
ARG INSTALL_CODEX_CLI=0
ARG CODEX_CLI_PACKAGE=
RUN --mount=type=cache,target=/root/.npm \
    mkdir -p /opt/npm/codex \
    && if [ "${INSTALL_CODEX_CLI}" = "1" ]; then \
         test -n "${CODEX_CLI_PACKAGE}" || { echo "CODEX_CLI_PACKAGE must be pinned when INSTALL_CODEX_CLI=1" >&2; exit 2; }; \
         npm install -g --prefix /opt/npm/codex "${CODEX_CLI_PACKAGE}"; \
       fi

FROM ${NODE_IMAGE} AS npm-claude
ARG INSTALL_CLAUDE_CODE=0
ARG CLAUDE_CODE_PACKAGE=
RUN --mount=type=cache,target=/root/.npm \
    mkdir -p /opt/npm/claude \
    && if [ "${INSTALL_CLAUDE_CODE}" = "1" ]; then \
         test -n "${CLAUDE_CODE_PACKAGE}" || { echo "CLAUDE_CODE_PACKAGE must be pinned when INSTALL_CLAUDE_CODE=1" >&2; exit 2; }; \
         npm install -g --prefix /opt/npm/claude "${CLAUDE_CODE_PACKAGE}"; \
       fi

# Pi's install instructions call for --ignore-scripts.
FROM ${NODE_IMAGE} AS npm-pi
ARG INSTALL_PI_AGENT=0
ARG PI_AGENT_PACKAGE=
RUN --mount=type=cache,target=/root/.npm \
    mkdir -p /opt/npm/pi \
    && if [ "${INSTALL_PI_AGENT}" = "1" ]; then \
         test -n "${PI_AGENT_PACKAGE}" || { echo "PI_AGENT_PACKAGE must be pinned when INSTALL_PI_AGENT=1" >&2; exit 2; }; \
         npm install -g --ignore-scripts --prefix /opt/npm/pi "${PI_AGENT_PACKAGE}"; \
       fi

# ── Scanners ────────────────────────────────────────────────────────────────

FROM golang:${GO_VERSION}-bookworm AS go-tools
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

# ── Release-binary downloads share one base with curl and git installed ─────

FROM debian:bookworm-slim AS fetch
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git

FROM fetch AS ttyd-bin
ARG TTYD_VERSION=1.7.7
RUN curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" -o /ttyd \
    && chmod +x /ttyd

# jcode (github.com/1jehuang/jcode): prebuilt Rust binary, checksum-verified.
# The tarball holds a launcher script plus the real ELF (<launcher>.bin) that it
# execs from its own directory, so both are installed together under
# /usr/local/lib/jcode with a bin/jcode symlink (the launcher resolves symlinks).
# /out is an empty tree when INSTALL_JCODE=0 so the runtime COPY is always valid.
FROM fetch AS jcode-bin
ARG INSTALL_JCODE=0
ARG JCODE_VERSION=
RUN mkdir -p /out/usr/local/bin /out/usr/local/lib/jcode \
    && if [ "${INSTALL_JCODE}" = "1" ]; then \
         test -n "${JCODE_VERSION}" || { echo "JCODE_VERSION must be pinned when INSTALL_JCODE=1" >&2; exit 2; }; \
         base="https://github.com/1jehuang/jcode/releases/download/${JCODE_VERSION}" \
         && mkdir -p /tmp/jcode && cd /tmp/jcode \
         && curl -fsSLO "${base}/jcode-linux-x86_64.tar.gz" \
         && curl -fsSLO "${base}/SHA256SUMS" \
         && sha256sum -c --ignore-missing SHA256SUMS \
         && tar -xzf jcode-linux-x86_64.tar.gz \
         && test -x jcode-linux-x86_64 && test -x jcode-linux-x86_64.bin \
         && install -m 0755 jcode-linux-x86_64 jcode-linux-x86_64.bin /out/usr/local/lib/jcode/ \
         && ln -s ../lib/jcode/jcode-linux-x86_64 /out/usr/local/bin/jcode; \
       fi

FROM fetch AS oh-my-zsh
ARG OH_MY_ZSH_REF=master
ARG ZSH_AUTOSUGGESTIONS_REF=v0.7.1
ARG ZSH_SYNTAX_HIGHLIGHTING_REF=0.8.0
RUN git clone --depth 1 --branch "${OH_MY_ZSH_REF}" https://github.com/ohmyzsh/ohmyzsh.git /oh-my-zsh \
    && rm -rf /oh-my-zsh/.git \
    && git clone --depth 1 --branch "${ZSH_AUTOSUGGESTIONS_REF}" \
       https://github.com/zsh-users/zsh-autosuggestions.git \
       /oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && rm -rf /oh-my-zsh/custom/plugins/zsh-autosuggestions/.git \
    && git clone --depth 1 --branch "${ZSH_SYNTAX_HIGHLIGHTING_REF}" \
       https://github.com/zsh-users/zsh-syntax-highlighting.git \
       /oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
    && rm -rf /oh-my-zsh/custom/plugins/zsh-syntax-highlighting/.git

FROM fetch AS mise-bin
ARG MISE_VERSION=2025.5.14
RUN curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64" \
       -o /usr/local/bin/mise \
    && chmod +x /usr/local/bin/mise

FROM fetch AS uv-bin
ARG UV_VERSION=0.11.32
RUN curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
       | tar -xz -C /tmp \
    && mv "/tmp/uv-x86_64-unknown-linux-gnu/uv" "/tmp/uv-x86_64-unknown-linux-gnu/uvx" /usr/local/bin/

FROM fetch AS neovim-bin
ARG NEOVIM_VERSION=0.11.0
RUN curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
       | tar -xz -C /opt \
    && mv /opt/nvim-linux-x86_64 /opt/nvim

# ── base: OS packages and users. Changes only with apt-packages.txt ─────────

FROM ${NODE_IMAGE} AS base
ARG PUID=1000
ARG PGID=1000
ARG DEV_PASSWORD=change-me

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    LC_CTYPE=C.UTF-8 \
    PATH="/usr/local/go/bin:/opt/nvim/bin:/opt/python-tools/bin:/usr/local/bin:${PATH}" \
    PYTHONPATH="/opt/python-tools/lib/python3.11/site-packages" \
    HOME=/home/agent \
    SHELL=/usr/bin/zsh \
    ZSH=/opt/oh-my-zsh \
    ZSH_THEME=remotellm-agnoster \
    UV_LINK_MODE=copy

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

# ── hermes: slowest step, so it sits before every tool COPY below ───────────
# It depends only on `base`, never on the tool stages, so bumping Pi/Codex/etc.
# leaves this layer cached. It runs in the same environment as before (the
# official installer writes to several places: /usr/local/lib/hermes-agent
# (pinned via HERMES_INSTALL_DIR, since the installer's own default nests the
# checkout under HERMES_HOME), /usr/local/share/uv, a $HOME/.local/bin/hermes
# launcher that we symlink into /usr/local/bin, and HERMES_HOME itself), which
# is why it is not split into a separate build stage with copied-out paths.
# The installer builds its own web/tui products as part of the run now, so no
# separate npm build step is needed here.

FROM base AS hermes
ARG PUID=1000
ARG PGID=1000
ARG INSTALL_HERMES_AGENT=0
ARG HERMES_AGENT_VERSION=
ARG HERMES_INSTALL_METHOD=pypi
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    if [ "${INSTALL_HERMES_AGENT}" = "1" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends python3 python3-venv ripgrep ffmpeg curl; \
      if [ "${HERMES_INSTALL_METHOD}" = "official" ]; then \
        mkdir -p /opt/hermes-home \
        && curl -fsSL https://hermes-agent.nousresearch.com/install.sh \
           | HOME=/opt/hermes-home HERMES_INSTALL_DIR=/usr/local/lib/hermes-agent bash -s -- --channel stable \
        && test -x /opt/hermes-home/.local/bin/hermes || { echo "Official hermes install did not produce a hermes binary" >&2; exit 2; } \
        && ln -sf /opt/hermes-home/.local/bin/hermes /usr/local/bin/hermes \
        && chown -R "${PUID}:${PGID}" /usr/local/lib/hermes-agent /opt/hermes-home; \
      else \
        test -n "${HERMES_AGENT_VERSION}" || { echo "HERMES_AGENT_VERSION must be set when HERMES_INSTALL_METHOD=pypi" >&2; exit 2; }; \
        python3 -m venv /opt/hermes \
        && /opt/hermes/bin/pip install --no-cache-dir "hermes-agent[messaging]==${HERMES_AGENT_VERSION}" python-multipart \
        && ln -sf /opt/hermes/bin/hermes /usr/local/bin/hermes; \
      fi; \
    fi

# ── runtime: tools and local config. Changes most, so it comes last ─────────

FROM hermes AS runtime

# npm tools: each prefix holds bin/ (relative symlinks) and lib/node_modules/,
# which merge into /usr/local. Node itself comes from the base image.
COPY --from=npm-opencode /opt/npm/opencode/ /usr/local/
COPY --from=npm-codex /opt/npm/codex/ /usr/local/
COPY --from=npm-claude /opt/npm/claude/ /usr/local/
COPY --from=npm-pi /opt/npm/pi/ /usr/local/
COPY --from=go-tools /usr/local/go /usr/local/go
COPY --from=go-tools /go/bin/osv-scanner /usr/local/bin/osv-scanner
COPY --from=go-tools /go/bin/scorecard /usr/local/bin/scorecard
COPY --from=python-tools /opt/python-tools /opt/python-tools
COPY --from=ttyd-bin /ttyd /usr/local/bin/ttyd
COPY --from=jcode-bin /out/ /
COPY --from=oh-my-zsh /oh-my-zsh /opt/oh-my-zsh
COPY --from=mise-bin /usr/local/bin/mise /usr/local/bin/mise
COPY --from=neovim-bin /opt/nvim /opt/nvim
COPY --from=uv-bin /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/

COPY config/agent/themes/remotellm-agnoster.zsh-theme /opt/oh-my-zsh/custom/themes/remotellm-agnoster.zsh-theme
COPY scripts/container/ /usr/local/bin/
COPY config/agent/AGENTS.md /etc/remotellm/AGENTS.md
COPY config/agent/remotellm.zsh /etc/remotellm/remotellm.zsh
COPY config/agent/tmux.conf /etc/remotellm/tmux.conf
COPY config/agent/skills/ /etc/remotellm/skills/
COPY config/agent/opencode/ /etc/remotellm/opencode/
COPY config/agent/claude/ /etc/remotellm/claude/
COPY config/agent/codex/ /etc/remotellm/codex/
COPY config/agent/pi/ /etc/remotellm/pi/
COPY config/agent/jcode/ /etc/remotellm/jcode/
COPY config/agent/hermes/ /etc/remotellm/hermes/
COPY config/agent/hermes-skills/ /etc/remotellm/hermes-skills/

RUN chmod +x /usr/local/bin/setup-agent /usr/local/bin/safe-npm-install /usr/local/bin/safe-pip-install /usr/local/bin/safe-package-check /usr/local/bin/safe-dev-env-check \
    && chmod +x /usr/local/bin/run-codex-agent /usr/local/bin/run-claude-agent /usr/local/bin/run-pi-agent /usr/local/bin/run-jcode-agent /usr/local/bin/run-hermes-agent /usr/local/bin/dispatch-cli \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd

USER agent
WORKDIR /workspace/projects
ENTRYPOINT ["/usr/bin/tini", "--", "setup-agent"]
CMD ["zsh", "-l"]
