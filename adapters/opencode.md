# opencode adapter

## Skill install

```sh
mkdir -p ~/.config/opencode/skills/pr-watch && cp SKILL.md ~/.config/opencode/skills/pr-watch/
```

opencode discovers skills under `~/.config/opencode/skills/`. If your version
predates skill discovery, paste the `SKILL.md` rules into your
`~/.config/opencode/AGENTS.md` instead — the decision order is what matters.

## Headless wake (optional `--agent` mode)

```sh
AGENT_CMD='opencode run'
```

`opencode run "<brief>"` executes one non-interactive turn per wake.
