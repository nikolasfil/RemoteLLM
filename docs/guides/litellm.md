# Optional LiteLLM gateway

LiteLLM and PostgreSQL are behind the `onlineagents` Compose profile. Start them
with `make build-onlineagents` and `make up-onlineagents`; stop with
`make down-onlineagents`. Normal agent startup does not enable this profile.

See [LiteLLM setup](../LITELLM.md) for endpoints, scoped virtual keys, model aliases,
OpenCode configuration, observability, and troubleshooting. Configure the agent
provider, endpoint, key, and model explicitly. There is no automatic master-key
fallback and no gateway model selected in the agent seed configurations.
