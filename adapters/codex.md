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
# diagnose and report only (the agent cannot edit or push):
AGENT_CMD='codex exec --sandbox read-only'
# fix and push: writable checkout plus network for `git push`
AGENT_CMD='codex exec --sandbox workspace-write -c sandbox_workspace_write.network_access=true'
```

With no prompt argument, `codex exec` reads the brief from stdin as a fresh
non-interactive turn. The brief tells the agent to push only if its
permissions allow, and to report a diagnosis otherwise — so read-only is a
safe default; widen it deliberately.
