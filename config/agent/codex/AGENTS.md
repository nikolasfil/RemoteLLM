# RemoteLLM Codex Instructions

These instructions extend `/etc/remotellm/AGENTS.md` for Codex CLI sessions running in
RemoteLLM.

- Start Codex through `run-codex-agent` inside the container, or from the host with
  `make codex`.
- Select a provider/model through Codex login or explicit user configuration.
- Require explicit user approval before changing files.
- LiteLLM is optional; use it only when the user explicitly configures it.
