# agent-here

Run a one-off RemoteLLM agent container in the current host directory.

```sh
# In the RemoteLLM checkout:
make init
make build-agent
mkdir -p "$HOME/.local/bin"
ln -s "$(pwd)/scripts/agent-here" "$HOME/.local/bin/agent-here"

# In a project directory:
agent-here
agent-here git status
agent-here run-pi-agent
agent-here run-jcode-agent
agent-here -m ~/Datasets:ro -m ~/reference:/workspace/reference:ro opencode
```

Ensure `$HOME/.local/bin` is on PATH. The symlink resolves back to the checkout,
so the launcher uses that checkout's Compose configuration and `.env`.
The current directory mounts at `/workspace/projects/<basename>` and becomes
the working directory. `-m HOST[:TARGET][:ro]` adds another directory; the default
target is `/workspace/mounts/<basename>`. Paths containing spaces must be quoted.
Use `--` to end launcher option parsing.

Without a command, the launcher starts `zsh -l`. It shares the configured agent
home, CLI state, and memory mounts, including Pi and jcode. It uses a unique
container name, removes the container on exit, and leaves the long-running agent
service alone. Non-interactive commands disable TTY allocation automatically.

The launcher uses `--no-deps`: it does not start LiteLLM, databases, VPN services,
or other dependencies. Start optional services yourself if your chosen provider
needs them. Build optional CLIs before launching their wrappers. Native provider
login/configuration is the default; no LiteLLM model is preselected.
