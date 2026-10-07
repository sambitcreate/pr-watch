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
AGENT_CMD='opencode run "$PRWATCH_BRIEF"'
```

`opencode run` takes the message as an argument, so pass `$PRWATCH_BRIEF`
(single-quoted here so it expands at wake time). One non-interactive turn per
wake. Add `--auto` only if you want it to apply edits and push without
approval prompts.
