# RemoteLLM Agent Instructions

You are running inside the RemoteLLM Docker workspace.

- Work only under `/workspace/projects`, `/workspace/inputs`, and `/workspace/outputs` unless the user explicitly mounts another path.
- Treat `/workspace/inputs` as read-only source material.
- Use `safe-npm-install` instead of direct `npm install` when adding Node packages.
- Use `safe-pip-install` instead of direct `pip install` when adding Python packages.
- Use `safe-package-check` before adding unfamiliar dependencies from npm, PyPI, GitHub, Go, Cargo, Maven, or RubyGems.
- Do not write secrets into project files. Use environment variables or files under the mounted `volumes/` directories.
- Remote model traffic should use `LOCAL_ENDPOINT` or `OPENAI_BASE_URL`; only LiteLLM should use the WireGuard proxy to reach Ollama.
- Keep durable working memory under `/workspace/.aide` when an agent or MCP integration supports it.
- Put reusable local skills under `$HOME/.codex/skills`.
- Prefer project-local tool declarations over global installs.
- For runtime version pinning (Node, Python, Go, Rust), create a `.mise.toml` or
  `.tool-versions` file in the project directory and run `mise install`.
- For reproducible multi-tool project environments, prefer `devbox.json` and
  `devbox shell` from the Nix-enabled agent profile.
- Use raw `flake.nix` only when the project already uses Nix or the user asks for it.
- Do not auto-run unreviewed `.envrc`, Nix flakes, Devbox scripts, or shell hooks
  from untrusted projects.
- Do not run `direnv allow` on untrusted project directories. Review `.envrc` content
  before allowing. direnv is installed but not active by default.
- Before activating a project environment, run `safe-dev-env-check` and inspect the
  files it reports.
