# Codex adapter

## Skill install

Codex reads skills from `~/.codex/skills/<name>/SKILL.md`:

```sh
mkdir -p ~/.codex/skills/pr-watch && cp SKILL.md ~/.codex/skills/pr-watch/
```

Codex also honors `AGENTS.md` in repos it works in; the repo-level
`AGENTS.md` in this repository is a short pointer you can paste there.

## Headless wake (optional `--agent` mode)

```sh
AGENT_CMD='codex exec --sandbox read-only -'
```

Codex `exec` accepts the brief on stdin as a fresh non-interactive turn.
Keep the sandbox read-only by default; widen it deliberately if you want the
woken agent to push fixes itself.
