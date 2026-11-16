---
name: kanban-dispatch
description: "Dispatch a kanban card to Codex CLI, Claude Code, or OpenCode when the card body declares an explicit backend: codex / backend: claude-code / backend: opencode label. Captures output and updates the card."
version: 1.0.0
author: RemoteLLM
license: MIT
platforms: [linux, macos, windows]
environments: [kanban]
metadata:
  hermes:
    tags: [kanban, multi-agent, dispatch, codex, claude-code, opencode, devops]
    related_skills: [kanban-worker, kanban-orchestrator, codex, claude-code]
---

# Kanban Dispatch — Codex / Claude Code / OpenCode Backends

> Use this skill when you are running as a kanban worker (`$HERMES_KANBAN_TASK` is set)
> and the card's body has a `backend: codex`, `backend: claude-code`, or
> `backend: opencode` directive on its
> first line. It tells you exactly how to delegate the actual work to that CLI via the
> `terminal` tool, instead of doing the work yourself or freelancing the invocation.
> This is additive to — not a replacement for — the `kanban-worker` skill's lifecycle
> (orient → work → heartbeat → block/complete); follow that lifecycle, using this skill
> for the "work" step specifically.

## Recognizing a dispatch-eligible card

After `kanban_show`, check the **first line of the body**:

```
backend: codex
<rest of the task prompt / acceptance criteria>
```

or

```
backend: claude-code
<rest of the task prompt / acceptance criteria>
```

or

```
backend: opencode
<rest of the task prompt / acceptance criteria>
```

- Only `codex`, `claude-code`, and `opencode` are recognized. Case-sensitive, exact match.
- **No `backend:` line at all → this skill does not apply.** This is the default,
  ordinary case for the vast majority of kanban cards. Ignore this skill entirely and
  proceed with your normal worker behavior (and the lifecycle from the `kanban-worker`
  skill) exactly as if this skill didn't exist. Do not block, do not ask the operator
  whether they meant to use Codex/Claude Code, do not treat the absence of a label as
  an error of any kind.
- **A `backend:` line is present but garbled or names something other than `codex`,
  `claude-code`, or `opencode`** (e.g. a typo, wrong case, or an unsupported value) →
  this is the one case where you block, since the card clearly intended dispatch but the
  label is broken:

  ```python
  kanban_block(reason="dispatch: missing/unknown backend label (expected 'backend: codex', 'backend: claude-code', or 'backend: opencode' as the first body line)")
  ```

  Never invent a backend choice. A wrong guess burns a delegated coder session on the
  wrong task framing.

## Two unrelated Codex auth paths — use the CLI one

Hermes itself can use Codex as *its own* model backend via `hermes auth add openai-codex`
(stored at `~/.hermes/auth.json`). That is **not** what this skill uses. This skill shells
out to the **standalone Codex CLI binary** (`codex`), which authenticates from its own
`~/.codex/auth.json`, set up once via `codex login` (see the operator's
"Authentication (one-time)" docs). If `codex exec` fails with an auth error, that's the
CLI's own login state — don't try to fix it via `hermes auth`.

## OpenCode auth path — use LiteLLM environment

OpenCode uses the seeded RemoteLLM config at `~/.config/opencode/opencode.jsonc` and
routes to LiteLLM through `OPENAI_API_KEY`. It does not use Codex or Claude subscription
tokens. If `opencode run` fails with a provider/model error, check LiteLLM health and the
OpenCode config, not `~/.codex/auth.json` or `~/.claude`.

## Resolving the workspace

Same workspace kinds as the `kanban-worker` skill (`$HERMES_KANBAN_WORKSPACE`):

| Kind | Action before dispatching |
|---|---|
| `worktree` | Preferred for code tasks. If `.git` doesn't exist at the path yet, `git worktree add <path> ${HERMES_KANBAN_BRANCH:-wt/$HERMES_KANBAN_TASK}` from the main repo first. |
| `dir:<path>` | Use as-is; `dispatch-cli` will `git init` it only if it's not already a repo (Codex requires one). |
| `scratch` | `dispatch-cli` `git init`s it automatically if needed. |

## Dispatching

Call the `dispatch-cli` helper through your `terminal` tool — it wraps the per-backend
invocation, log capture, and exit-code handling so you don't have to construct the raw
command yourself:

```
terminal(
  command="dispatch-cli codex \"$HERMES_KANBAN_TASK\" \"<resolved workspace>\" \"<task prompt>\"",
  workdir="<resolved workspace>",
  pty=true,           # required for the codex backend — it's an interactive TUI
  timeout=<budget>,
)
```

By default, Codex runs with `--sandbox workspace-write`. If the container cannot create
bubblewrap/user namespaces, the operator may opt into
`DISPATCH_CODEX_SANDBOX=danger-full-access`, which disables Codex's own sandbox and relies
on the container plus mounted-volume set as the boundary. Do not enable that silently.

```
terminal(
  command="dispatch-cli claude-code \"$HERMES_KANBAN_TASK\" \"<resolved workspace>\" \"<task prompt>\"",
  workdir="<resolved workspace>",
  timeout=<budget>,   # no pty needed — claude-code runs in print mode
)
```

```
terminal(
  command="dispatch-cli opencode \"$HERMES_KANBAN_TASK\" \"<resolved workspace>\" \"<task prompt>\"",
  workdir="<resolved workspace>",
  timeout=<budget>,   # no pty needed — opencode run is non-interactive
)
```

OpenCode dispatch runs `opencode run --format json --dir <workspace>` and, by default,
adds `--dangerously-skip-permissions` so unattended kanban dispatch does not pause for
tool approval. The operator can set `DISPATCH_OPENCODE_SKIP_PERMISSIONS=0` to restore
OpenCode's normal permission flow, but that may make kanban dispatch block.

The `<task prompt>` is the rest of the card body (everything after the `backend:` line),
plus an explicit instruction appended by you: **"Commit your work on the current branch.
Do not push."** (see Git boundary below).

`dispatch-cli` writes output to
`/workspace/.aide/dispatch/<task_id>.<backend>.{log,json,err}` and ends with `EXIT:<code>`
on stdout. Codex uses a combined `.log`; Claude Code and OpenCode write JSON/stdout to
`.json` and stderr to `.err`. Read those files or the
`terminal` tool's captured output to decide the next step.

## Interpreting the result

- **Codex:** non-zero exit code in the log → treat as failed.
- **Claude Code:** parse the JSON log; `subtype != "success"` → treat as failed, regardless
  of exit code. Useful fields: `result`, `num_turns`, `total_cost_usd`, `session_id`.
- **OpenCode:** non-zero exit code → treat as failed. The JSON log is event-oriented; use
  it plus `git status` / `git diff --stat` to summarize changed files.

**Clean, terminal, no-review work** (docs typo, trivial one-liner):

```python
kanban_complete(
    summary="codex done: added dark mode toggle; log at /workspace/.aide/dispatch/<id>.codex.log",
    metadata={
        "backend": "codex",
        "exit_code": 0,
        "log_path": "/workspace/.aide/dispatch/<id>.codex.log",
        "workspace": "<resolved path>",
        "changed_files": [...],   # git -C <workspace> diff --name-only HEAD~1
        "committed": True,
        "pushed": False,
    },
)
```

**Code-changing work (the common case)** — block for review instead of completing, per the
`kanban-worker` skill's review-required pattern:

```python
kanban_comment(
    body="review-required handoff:\n" + json.dumps({
        "backend": "claude-code",
        "exit_code": 0,
        "claude": {"subtype": "success", "num_turns": 4, "total_cost_usd": 0.18},
        "log_path": "/workspace/.aide/dispatch/<id>.claude-code.json",
        "workspace": "<resolved path>",
        "branch": "wt/<task_id>",
        "changed_files": [...],
        "committed": True,
        "pushed": False,
    }, indent=2),
)
kanban_block(reason="review-required: claude-code finished — needs eyes before push")
```

**Failure** (non-zero exit, `subtype` error, or the CLI's auth/login state is broken):

```python
kanban_block(reason="dispatch: codex exited non-zero — see /workspace/.aide/dispatch/<id>.codex.log")
```

Don't retry the dispatch yourself in a loop — block and let the operator reclaim/reassign
per the `kanban-worker` retry-diagnostics guidance.

## Git boundary — commit, never push

The container has no git credential helper configured by default, so a dispatched CLI
*can't* push even if instructed to — but always include the instruction explicitly anyway
(belt and suspenders, and it documents intent in the transcript): **"Commit your work on
this branch. Do not push."** Surface the branch/worktree path in your `kanban_comment` so
the operator runs the host-side push after reviewing.

## Concurrency

The card's claimed/`in_progress` state is the only lock — don't add new locking. If two
cards must touch the same checkout, that should already be expressed as a `parents=[...]`
dependency by whoever created the cards; if you notice an ungated pair targeting the same
non-worktree workspace, flag it in a comment rather than silently racing.

## Pitfalls

- **Don't skip the `backend:` parse and just "be helpful" by doing the task yourself.**
  The whole point of the label is to run the work through the named CLI's own context and
  subscription, not yours.
- **Don't conflate `~/.codex/auth.json` (CLI) with `~/.hermes/auth.json` (Hermes's own
  model routing).** See "Two unrelated Codex auth paths" above.
- **Don't forget `pty=true` for Codex.** Without it the `terminal` call hangs.
- **Don't claim `kanban_complete` on code changes without review** unless the task is
  genuinely trivial — see the `kanban-worker` skill's review-required convention.

## Additional backends

`dispatch-cli pi <task_id> <workspace_dir> <prompt>` and
`dispatch-cli jcode <task_id> <workspace_dir> <prompt>` use the same log and
`EXIT:<code>` convention. Install and authenticate each CLI first. Optional
`DISPATCH_PI_PROVIDER`, `DISPATCH_PI_MODEL`, `DISPATCH_JCODE_PROVIDER`, and
`DISPATCH_JCODE_MODEL` select a provider/model; otherwise each CLI uses its own configuration.
