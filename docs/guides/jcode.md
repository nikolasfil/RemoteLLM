# jcode

jcode is an optional CLI installed from a pinned GitHub release. Enable it in `.env`:

```dotenv
INSTALL_JCODE=1
JCODE_VERSION=v0.88.0
```

```sh
make build-agent
make jcode
# Or from a project directory:
agent-here run-jcode-agent
```

The Dockerfile downloads the Linux x86_64 release and verifies the tarball
against the release's SHA256SUMS before installing its launcher and binary.
The shared agent image currently targets x86_64 for downloaded CLI binaries.

Use jcode's provider login/configuration. RemoteLLM does not discover LiteLLM
or automatically switch providers. `run-jcode-agent` passes arguments through
with `--no-update` to preserve the image's pinned version and disables telemetry.
To configure an OpenAI-compatible provider, explicitly set the endpoint, key,
and model using jcode's configuration. No key or model is injected by default.

State persists in `.local/volumes/jcode-home`, mounted at `/home/agent/.jcode`.
Treat this directory as private because it can contain login tokens. The `jcode`
Compose profile shares the main workspace and memory mounts. Rebuild after
changing the version.

The existing Hermes dispatcher also accepts `jcode` as a backend. Optional
`DISPATCH_JCODE_PROVIDER` and `DISPATCH_JCODE_MODEL` select an explicit provider/model.
