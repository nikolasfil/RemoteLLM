# Nix Agent (Devbox / Nix Development Environment)

The `nix-agent` service is a variant of the base agent container with Nix and Devbox pre-installed. It runs under the `nix` Compose profile and provides reproducible, declarative per-project development environments without installing tools globally.

## Features

- Nix package manager (single-user, pinned version)
- Devbox for per-project hermetic tool environments from `devbox.json`
- All tools from the base `agent` image (zsh, tmux, mise, safety wrappers, etc.)
- Persistent Nix store at `.local/volumes/nix/` — mounted at `/nix` inside the container
- Persistent Devbox cache at `.local/volumes/devbox-cache/`
- direnv installed (not active by default — must be explicitly allowed per project)
- `safe-dev-env-check` for auditing project environment files before activation

## Functionalities

### Starting the Nix Agent

```sh
docker compose --profile nix up -d nix-agent
make shell-nix
```

`make shell-nix` attaches a shell to the `nix-agent` container.

### Per-Project Environments with Devbox

```sh
cd /workspace/projects/<project>
devbox init          # creates devbox.json for a new project
devbox shell         # activate the hermetic environment
```

Commit `devbox.json` and `devbox.lock` with the project. Any developer (or agent) running `devbox shell` from that directory gets the exact same tool versions.

### Runtime Pinning with mise

The nix-agent also has mise for lightweight runtime pinning:

```sh
mise install         # reads .mise.toml or .tool-versions
```

Use Devbox for reproducible multi-tool environments; use mise for single-runtime pinning (e.g., pin just Node or Python for a project).

### Auditing Project Environments

Before activating an unfamiliar project environment:

```sh
make check-dev-env   # or: safe-dev-env-check inside the container
```

This reports `.mise.toml`, `.tool-versions`, `devbox.json`, `flake.nix`, `devenv.nix`, and `.envrc` files so you can review them before running untrusted setup scripts.

### direnv

direnv is installed but not active by default. Never run `direnv allow` on untrusted projects.

```sh
# After reviewing .envrc content:
direnv allow .
```

### Nix Flakes

Raw `flake.nix` is supported but discouraged unless the project already uses Nix natively or the user explicitly requires it. Prefer `devbox.json` for portability.

### Persistent Volumes

| Host Path | Container Path | Purpose |
|---|---|---|
| `.local/volumes/nix` | `/nix` | Nix store (tool packages, derivations) |
| `.local/volumes/devbox-cache` | `/home/agent/.cache/devbox` | Devbox download cache |

Both volumes persist across container restarts. The Nix store is the most disk-intensive; expect 5–10 GB on first run after activating several Devbox environments.

## Limitations

- **5–10 GB disk on first run.** The Nix store accumulates tool derivations. First activation of a Devbox environment can take 5–15 minutes while Nix downloads and builds dependencies.
- **Single-user Nix.** The container runs Nix in single-user mode. Multi-user daemon mode (standard on Linux hosts) is not used inside the container.
- **gVisor runtime commented out.** Like the base agent, `runtime: runsc` is available but commented out. Enable it in `compose.yml` after registering gVisor if kernel-level isolation is needed.
- **direnv is not active by default.** `.envrc` hooks are not evaluated unless you run `direnv allow` explicitly. This is intentional — automatic activation of untrusted project hooks is a security risk.
- **Devbox and mise are complementary, not interchangeable.** Devbox provides fully hermetic per-project environments; mise provides lightweight per-language-runtime pinning. They can coexist.
- **No GPU passthrough.** The nix-agent has no GPU access.

## Hardware Requirements

| Metric | Value |
|---|---|
| RAM (idle) | 512 MB |
| RAM (active Devbox shell) | 1–2 GB |
| RAM (active build) | 6–8 GB |
| CPU (idle) | 0.1 cores |
| CPU (Nix build) | up to 4 cores |
| Disk (Nix store, first run) | 5–10 GB |
| Disk (per active environment) | 0.5–2 GB |

Recommended: 16 GB RAM and 20 GB free disk if using Nix heavily.
