# Continue

Continue provides chat, editing, and autocomplete inside code-server. Install the
extension from the browser IDE marketplace if needed.

`make init` seeds `.local/volumes/vscode-config/continue/config.yaml` with an
empty model list. Configure a provider in Continue before making requests.
No LiteLLM endpoint or `ollama-default` model is preselected.

For optional LiteLLM routing, start `make up-onlineagents`, then add a model:

```yaml
models:
  - name: Optional LiteLLM
    provider: openai
    model: ollama-default
    apiBase: http://litellm:4000/v1
    apiKey: ${{ secrets.OPENAI_API_KEY }}
    roles: [chat, edit, apply]
```

Put the scoped key in `.local/volumes/vscode-config/continue/.env`. This is local
runtime state, never public repository content. Continue also supports direct
providers; configure their model and authentication in the extension.

Existing volume configuration is preserved. To reset it intentionally, copy the
source template from `config/continue/config.yaml` to the persistent location.
