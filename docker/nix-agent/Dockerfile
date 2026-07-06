# syntax=docker/dockerfile:1.7

FROM remotellm/agent:local

ARG PUID=1000
ARG PGID=1000
ARG DEVBOX_VERSION=0.17.2
ARG NIX_VERSION=2.29.1

USER root

ENV NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    NIX_PATH=nixpkgs=channel:nixpkgs-unstable \
    PATH="/nix/var/nix/profiles/per-user/agent/profile/bin:/home/agent/.nix-profile/bin:${PATH}"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) devbox_arch="amd64"; nix_system="x86_64-linux" ;; \
      arm64) devbox_arch="arm64"; nix_system="aarch64-linux" ;; \
      *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/jetify-com/devbox/releases/download/${DEVBOX_VERSION}/devbox_${DEVBOX_VERSION}_linux_${devbox_arch}.tar.gz" \
      -o /tmp/devbox.tar.gz; \
    tar -xzf /tmp/devbox.tar.gz -C /usr/local/bin devbox; \
    chmod +x /usr/local/bin/devbox; \
    rm -f /tmp/devbox.tar.gz; \
    curl -fsSL "https://releases.nixos.org/nix/nix-${NIX_VERSION}/nix-${NIX_VERSION}-${nix_system}.tar.xz" \
      -o /tmp/nix.tar.xz; \
    mkdir -p /tmp/nix-installer; \
    tar -xJf /tmp/nix.tar.xz -C /tmp/nix-installer --strip-components=1; \
    mkdir -m 0755 /nix; \
    chown "${PUID}:${PGID}" /nix; \
    su agent -c "USER=agent HOME=/home/agent sh /tmp/nix-installer/install --no-daemon --no-channel-add"; \
    tar -C / -cJf /opt/remotellm-nix-seed.tar.xz nix; \
    rm -rf /tmp/nix.tar.xz /tmp/nix-installer

RUN set -eux; \
    nix_bin_dir="$(dirname "$(find /nix/store -path '*/bin/nix' -type f | head -n 1)")"; \
    for name in nix nix-build nix-channel nix-collect-garbage nix-copy-closure nix-daemon nix-env nix-hash nix-instantiate nix-prefetch-url nix-shell nix-store; do \
      ln -sf "${nix_bin_dir}/${name}" "/usr/local/bin/${name}"; \
    done

COPY docker/nix-agent/setup-nix-agent /usr/local/bin/setup-nix-agent

RUN chmod +x /usr/local/bin/setup-nix-agent \
    && chown -R "${PUID}:${PGID}" /nix

USER root
ENTRYPOINT ["/usr/bin/tini", "--", "setup-nix-agent"]
CMD ["zsh", "-l"]
