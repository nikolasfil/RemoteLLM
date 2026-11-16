# Pi coding agent

Pi is an optional CLI installed into the shared agent image. Enable it in `.env`:

```dotenv
INSTALL_PI_AGENT=1
PI_AGENT_PACKAGE=@earendil-works/pi-coding-agent@1.5.2
```

```sh
make build-agent
make pi
# Or from a project directory:
agent-here run-pi-agent
```

The npm package must be pinned. Pi requires Node >=22.19; the Dockerfile uses
one Node base for npm installation stages and the runtime.

Choose and authenticate a provider within Pi. No provider or model is selected
by the RemoteLLM seed. Custom providers can be configured in
`~/.pi/agent/models.json`; preferences live in `~/.pi/agent/settings.json`.
These files and login state persist in `.local/volumes/pi-home`, mounted at
`/home/agent/.pi`. Treat the volume as private; it can contain credentials.

The `pi` Compose profile shares project, input, output, and memory mounts with
the main agent. It does not start LiteLLM. Rebuild after changing the package
version. The `run-pi-agent` wrapper passes command arguments through unchanged.

Pi runs tools without approval prompts; mount only directories it should access.
The existing Hermes dispatcher also accepts `pi` as a backend. Set
`DISPATCH_PI_PROVIDER` and `DISPATCH_PI_MODEL` to select an explicit provider/model.
