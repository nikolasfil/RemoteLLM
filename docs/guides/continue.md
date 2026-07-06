# Continue

Continue is a VS Code extension that provides AI-powered chat, code editing, and autocomplete inside code-server. It connects to LiteLLM, so it uses the same remote Ollama model as the rest of the stack.

## Features

- In-editor chat with context from open files and selections
- Inline code edit and apply: describe a change, preview it, apply in one keystroke
- Tab autocomplete powered by the same LiteLLM gateway as opencode
- Model switching without reconfiguring the extension (change the alias in `config.yaml`)
- Persistent config in `.local/volumes/vscode-config/continue/`
- Secrets decoupled from config via a local `.env` file

## Functionalities

### Configuration

The seeded config lives at:

```text
.local/volumes/vscode-config/continue/config.yaml
```

The source template is at `config/continue/config.yaml`. On first `make init`, the template is copied to the volume.

```yaml
models:
  - name: RemoteLLM LiteLLM
    provider: openai
    model: ollama-default
    apiBase: http://litellm:4000/v1
    apiKey: ${{ secrets.OPENAI_API_KEY }}
    roles: [chat, edit, apply]
    defaultCompletionOptions:
      temperature: 0.2

  - name: RemoteLLM LiteLLM Autocomplete
    provider: openai
    model: ollama-default
    apiBase: http://litellm:4000/v1
    apiKey: ${{ secrets.OPENAI_API_KEY }}
    roles: [autocomplete]
    useLegacyCompletionsEndpoint: false
    autocompleteOptions:
      debounceDelay: 350
      maxPromptTokens: 1024
      onlyMyCode: true
```

### API Key Secret

Continue resolves `${{ secrets.OPENAI_API_KEY }}` from:

```text
.local/volumes/vscode-config/continue/.env
```

This file is created by `make init` with the value from `OPENAI_API_KEY` (which maps to `AGENT_VIRTUAL_KEY` or `LITELLM_MASTER_KEY`). Update it after rotating the key:

```sh
# edit .local/volumes/vscode-config/continue/.env
OPENAI_API_KEY=sk-...
```

### Switching Models

Change the `model` field in the Continue config to any alias defined in `config/litellm/config.yaml`:

```yaml
model: claude-default     # use Anthropic via LiteLLM
model: bitnet-2b          # use local BitNet (cpu-llm profile must be active)
```

No extension reinstall needed; the change takes effect on next Continue request.

### Autocomplete Token Budget

The `maxPromptTokens: 1024` default limits how much context Continue sends for autocomplete. This keeps latency low with large Ollama models over the VPN. Increase it for larger context but expect slower suggestions:

```yaml
maxPromptTokens: 2048
```

### Installing the Extension

If the extension is not already installed in code-server, install it from the VS Code Open VSX marketplace within the browser IDE (search "Continue").

## Limitations

- **Requires code-server.** Continue is a VS Code extension and only works inside the browser IDE.
- **Autocomplete latency depends on model and VPN throughput.** Remote Ollama models typically take 1–5 seconds per completion. The `debounceDelay: 350` default reduces noise but cannot eliminate latency.
- **Single model for autocomplete.** The seeded config uses `ollama-default` for autocomplete. Switching to a purpose-built autocomplete model (e.g., a smaller fill-in-the-middle model) requires an additional entry in the LiteLLM config.
- **`maxPromptTokens: 1024` is conservative.** It may truncate context on large files. Increase only if the target model handles longer prompts well.
- **Config reset is manual.** Customizations made in the volume are not overwritten by `make init`. If you want to reset to the seeded config, copy it manually: `cp config/continue/config.yaml .local/volumes/vscode-config/continue/config.yaml`.

## Hardware Requirements

Continue itself has no independent hardware requirements — it runs as part of code-server. The autocomplete and chat workloads are sent to LiteLLM and then to the remote Ollama model. Hardware requirements are those of code-server and the upstream model server.
