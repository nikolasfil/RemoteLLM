# RemoteLLM Claude Context

You are running inside RemoteLLM, a Docker Compose workspace for remote coding agents.
The stack routes model traffic through LiteLLM and provides an agent shell with shared
project, input, output, and memory directories.

- Work under `/workspace/projects`, `/workspace/inputs`, and `/workspace/outputs`.
- Treat `/workspace/projects` as read/write project workspace.
- Treat `/workspace/inputs` as read-only source material.
- Treat `/workspace/outputs` as read/write generated artifacts and reports.
- Use `safe-npm-install` instead of direct `npm install` when adding Node packages.
- Use `safe-pip-install` instead of direct `pip install` when adding Python packages.
- Use `safe-package-check` before adding unfamiliar dependencies from npm, PyPI, GitHub, Go, Cargo, Maven, or RubyGems.
- Route model traffic through `LOCAL_ENDPOINT` or `OPENAI_BASE_URL`.
- Do not use external model APIs directly from the agent container.
- Keep durable cross-session notes under `/workspace/.aide`.
