# RemoteLLM Skills

Place project-specific agent skills here when they should be seeded into new agent homes.

At container startup, files from this image directory are copied into:

```text
/home/agent/.codex/skills
```

Existing files are left in place so local edits in the mounted volume are not overwritten.
