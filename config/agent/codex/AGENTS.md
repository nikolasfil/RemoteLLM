# RemoteLLM Codex Instructions

These instructions extend `/etc/remotellm/AGENTS.md` for Codex CLI sessions running in
RemoteLLM.

- Start Codex through `run-codex-agent` inside the container, or from the host with
  `make codex`.
- Use the RemoteLLM model alias with `--model ollama-default` unless the environment
  provides an equivalent alias.
- Require explicit user approval before changing files.
- `OPENAI_BASE_URL` is set to `http://litellm:4000/v1`; route Codex model traffic
  through that LiteLLM endpoint.
