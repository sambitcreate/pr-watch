# Pi adapter

## Skill install

```sh
mkdir -p ~/.pi/agent/skills/pr-watch && cp SKILL.md ~/.pi/agent/skills/pr-watch/
```

Pi loads skills from `~/.pi/agent/skills/`. Because pi also supports
long-running missions, you may be tempted to implement watching as a mission —
don't. A mission that sleeps in a loop pays the same context re-send tax as an
in-turn poll. The shell daemon remains the watcher; pi stays the fixer.

## Headless wake (optional `--agent` mode)

```sh
AGENT_CMD='pi -p "$PRWATCH_BRIEF"'
```

`pi -p/--print` runs one non-interactive turn per wake. The brief is passed
as the prompt argument via `$PRWATCH_BRIEF` (it is also on stdin).
