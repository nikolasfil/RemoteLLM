# RemoteLLM Hermes Skills

Place project-specific Hermes agent skills here when they should be seeded into new agent
homes.

At container startup, files from this image directory are copied into:

```text
/home/agent/.hermes/skills
```

Existing files are left in place so local edits in the mounted volume are not overwritten
(`cp -Rn`, no-clobber) — this is purely additive content, never overriding Hermes's own
bundled skills of the same name.
