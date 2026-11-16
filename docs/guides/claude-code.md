# Claude Code CLI

Claude Code is Anthropic's command-line coding agent. It is optional and opt-in, installed at image build time when `INSTALL_CLAUDE_CODE=1`. It runs under the `claude` Compose profile as a one-shot interactive container.

## Features

- Anthropic Claude Code CLI agent
- One-shot profile: interactive task session, then exits
- Routable through LiteLLM (for virtual key scoping and observability) or directly to Anthropic
- Shared workspace mounts with the core agent container
- Interactive TTY with stdin support
- State persisted to `.local/volumes/claude-home/`
- Optional MCP integrations via `config/agent/claude/mcp.json`
- Optional CLAUDE.md agent instructions via `config/agent/claude/CLAUDE.md`

## Functionalities

### Enabling Claude Code

Set build args in `.env`:

```dotenv
INSTALL_CLAUDE_CODE=1
CLAUDE_CODE_PACKAGE=@anthropic-ai/claude-code@<version>
```

Rebuild:

```sh
make build
```

### Running Claude Code

```sh
make claude
```

The container starts the `claude` profile, runs `run-claude-agent`, and exits when the session ends.

### Authentication (one-time)

Claude Code also supports a Pro/Max subscription login with no API key required, separate
from the API-key routing described below. `ANTHROPIC_API_KEY` is empty by default in
`.env.example`, so the subscription path works out of the box as long as you leave it
that way:

```sh
make claude
```

Inside the container, run `claude` and complete the browser OAuth flow (or
`claude setup-token` for a longer-lived token). On a headless/remote host, use the
device-code flow and complete it from your own machine's browser. The token persists to
`.local/volumes/claude-home/` (bind-mounted), surviving container recreation and visible
to any other profile mounting the same volume — including Hermes, when it shells out to
the standalone `claude` binary via the `kanban-dispatch` skill (see `docs/guides/hermes.md`).

Verify with `claude auth status` inside the container, or check that
`.local/volumes/claude-home/` is populated on the host.

**Important:** if `ANTHROPIC_API_KEY` is set to a real key (or `ANTHROPIC_BASE_URL` points
at LiteLLM, per the next section), Claude Code bills at API rates and ignores the
subscription entirely. Use one path or the other, not both.

### Optional LiteLLM routing

Start the gateway with `make up-onlineagents` and configure an agent-specific
`ANTHROPIC_BASE_URL=http://litellm:4000` and `ANTHROPIC_API_KEY` containing a scoped
virtual key. Keep the real upstream Anthropic key in the gateway's environment
or credential store. Use a service-specific Compose override to separate these
keys; the shared `.env` uses one `ANTHROPIC_API_KEY` by default.

There is no `CLAUDE_VIRTUAL_KEY` fallback through `OPENAI_API_KEY`. See
[LiteLLM](../LITELLM.md) for optional setup.

### Routing Directly to Anthropic

If you prefer Claude Code to call Anthropic directly (bypassing LiteLLM):

```dotenv
ANTHROPIC_API_KEY=sk-ant-...    # real Anthropic key
ANTHROPIC_BASE_URL=             # leave empty
```

In this configuration the real Anthropic key is visible inside the `claude` container.

### MCP Configuration

MCP server definitions for Claude Code live at `config/agent/claude/mcp.json`. The Playwright MCP server is listed but disabled by default. Enable it by starting the `playwright` profile and uncommenting the entry.

### Agent Instructions

`config/agent/claude/CLAUDE.md` and `config/agent/AGENTS.md` are mounted into the container and seeded to the Claude home directory. They provide RemoteLLM-specific instructions (workspace paths, safety tool usage, memory conventions) that Claude Code reads on startup.

### State

Claude Code state (conversation history, config, tool permissions) is persisted to `.local/volumes/claude-home/`, mounted at `/home/agent/.claude`.

## Limitations

- **Opt-in only.** Not installed unless `INSTALL_CLAUDE_CODE=1` and a pinned `CLAUDE_CODE_PACKAGE` are set.
- **One-shot profile.** The container exits when the session ends.
- **Requires rebuild after version change.** Updating requires changing `CLAUDE_CODE_PACKAGE` and `make build`.
- **Anthropic account required.** Either a direct API key or a LiteLLM routing key backed by a real Anthropic key.
- **When routing through LiteLLM**, Claude Code uses the `claude-default` alias which maps to `anthropic/claude-sonnet-4-6`. To use a different Claude model, change the `model` field in `config/litellm/config.yaml` and restart LiteLLM.
- **Direct routing exposes the real Anthropic key** inside the container. Use LiteLLM routing to keep the key isolated.

## Security

| Mode | Key exposure |
|---|---|
| Via LiteLLM | Real Anthropic key in `litellm` container only; agent holds a scoped virtual key |
| Direct Anthropic | Real Anthropic key in `claude` container |

Select native login, direct API access, or optional gateway routing explicitly.

## Hardware Requirements

| Metric | Value |
|---|---|
| RAM (Claude Code process) | ~100–256 MB |
| CPU | <1 core |

Inference runs on Anthropic's cloud. No local GPU required.
