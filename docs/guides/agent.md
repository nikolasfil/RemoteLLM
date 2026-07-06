# Agent Container

The `agent` service is the primary long-running development container. It provides a persistent shell environment with coding tools, package safety wrappers, and shared workspace mounts that all agent CLI profiles (opencode, Codex, Claude, Hermes) use.

## Features

- Debian Bookworm base with full development tooling
- zsh + Oh My Zsh with `remotellm-agnoster` theme, autosuggestions, and syntax highlighting
- tmux with true-color support, mouse mode, and RemoteLLM defaults
- Neovim with seeded config
- mise for per-project runtime version pinning (Node, Python, Go, Rust, etc.)
- Package safety wrappers: `safe-npm-install`, `safe-pip-install`, `safe-package-check`
- Vulnerability scanners: `pip-audit`, `osv-scanner`, `scorecard`
- Python, Node 22, Go (via mise), build-essential, Git, curl, jq, and common CLI utilities
- Passwordless sudo for development installs
- OpenCode pre-installed; Codex CLI and Claude Code optional (controlled by build args)
- Hermes Agent optional (PyPI or official installer)
- socket CLI for supply-chain checks
- Shared workspace mounts across all agent profiles

## Functionalities

### Starting the Agent

```sh
make up         # start core stack (agent + litellm + nginx)
make up-vpn     # optional: start WireGuard + vpn-proxy when needed
make shell      # attach a shell to the running agent container
```

The agent runs `sleep infinity` by default and is entered via `docker compose exec`.

### Workspace Layout

| Mount | Container Path | Description |
|---|---|---|
| `.local/workspace/projects` | `/workspace/projects` | Editable project code |
| `.local/workspace/inputs` | `/workspace/inputs` (read-only) | Input material |
| `.local/workspace/outputs` | `/workspace/outputs` | Generated outputs |
| `.local/volumes/agent-home` | `/home/agent` | Agent home (persistent) |
| `.local/volumes/opencode-home` | `/home/agent/.config/opencode` | OpenCode state |
| `.local/volumes/codex-home` | `/home/agent/.codex` | Codex state and skills |
| `.local/volumes/claude-home` | `/home/agent/.claude` | Claude Code state |
| `.local/volumes/aide-memory` | `/workspace/.aide` | Shared agent memory |
| `.local/volumes/mise-cache` | `/home/agent/.local/share/mise` | mise tool cache |

`/workspace/.aide/dispatch/` is a subdirectory of the shared memory mount holding
per-task logs from the Hermes `kanban-dispatch` skill (`<task_id>.<backend>.{log,json,err}`)
— see `docs/guides/hermes.md` → "Orchestrating Codex / Claude via Kanban".

### Shell Environment

The agent shell sources `/home/agent/.remotellm.zsh` on startup. This file is managed by the image and defines aliases, environment variables, and the prompt theme. If `.local/volumes/agent-home/.zshrc` exists, the managed block is appended rather than replacing the file.

To refresh the managed profile in an existing home:

```sh
docker compose exec agent setup-agent true
```

Start a persistent tmux session:

```sh
tmux new -A -s remotellm
```

### Package Safety Workflow

From inside the agent container:

```sh
safe-package-check /workspace/projects   # audit all project deps
safe-npm-install <package>               # preflight-check then npm install
safe-pip-install <package>               # preflight-check then pip install
pip-audit                                # CVE scan for Python deps
osv-scanner .                            # multi-ecosystem CVE scan
```

Always run a preflight check before adding unfamiliar packages. Supply-chain risk is elevated because the agent runs with network access and can modify project files.

### Runtime Version Pinning

For per-project runtimes, use mise:

```sh
cd /workspace/projects/<project>
mise install    # reads .mise.toml or .tool-versions
```

Commit `.mise.toml` (or `.tool-versions`) with the project.

### Adding Permanent Packages to the Image

Edit `docker/agent/apt-packages.txt`, then rebuild and recreate:

```sh
docker compose build agent
docker compose --profile ide --profile web-terminal up -d agent web-terminal
```

For one-off packages that don't survive container recreation, use `sudo apt-get install` inside the shell.

### Opt-In CLIs

Enable Codex CLI at build time:

```dotenv
INSTALL_CODEX_CLI=1
CODEX_CLI_PACKAGE=@openai/codex@<version>
```

Enable Claude Code:

```dotenv
INSTALL_CLAUDE_CODE=1
CLAUDE_CODE_PACKAGE=@anthropic-ai/claude-code@<version>
```

Enable Hermes Agent (choose one method):

```dotenv
INSTALL_HERMES_AGENT=1
HERMES_INSTALL_METHOD=pypi        # pinned version
HERMES_AGENT_VERSION=0.16.0
```

After changing any of these, run `make build`.

## Limitations

- The Docker socket is not mounted. The agent cannot build or manage host containers.
- The `runsc` (gVisor) runtime is commented out by default; enable it in `compose.yml` after registering gVisor on the host. Without it, container isolation relies on Docker's default runc.
- Passwordless sudo is intentional for development convenience. Do not expose the agent terminal to untrusted users.
- Tool versions (opencode, socket, pip-audit, osv-scanner, scorecard, ttyd) are pinned via `.env` build args; changing them requires a rebuild.
- The agent home at `.local/volumes/agent-home` accumulates shell history, agent transcripts, and credentials. Review before backups or sharing.

## Hardware Requirements

| Scenario | RAM | CPU |
|---|---|---|
| Idle (shell only) | 256 MB | <0.1 cores |
| Active coding tasks | 4–8 GB | up to 4 cores |
| Build/test workloads | 4–8 GB | up to 4 cores |

Disk: the agent image is ~2–3 GB. The Nix-enabled variant (`nix-agent`) adds 5–10 GB on first run for the Nix store.
