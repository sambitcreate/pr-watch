# Claude Code adapter

## Skill install

```sh
cp -r SKILL.md ~/.claude/skills/pr-watch/   # create the dir if needed
```

Claude Code discovers skills in `~/.claude/skills/` (personal) or
`.claude/skills/` (project). The skill's decision order applies automatically
whenever a PR-watch request matches the description.

## Headless wake (optional `--agent` mode)

In `pr-watchd` config (`~/.config/pr-watch/config.env`):

```sh
AGENT_CMD='claude -p --allowedTools "Bash(gh:*) Read Edit" --permission-mode acceptEdits'
```

Each wake pipes a minimal brief (repo, PR, failing checks, rules) to
`claude -p` as a fresh one-shot session — never your interactive context.
Without `AGENT_CMD` the daemon only sends OS notifications.
