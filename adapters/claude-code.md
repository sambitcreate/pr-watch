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
AGENT_CMD='claude -p --allowedTools "Bash(gh pr checks:*) Bash(gh pr view:*) Bash(gh pr diff:*) Bash(gh run view:*) Bash(git:*) Read Edit" --permission-mode acceptEdits'
```

Each wake pipes a minimal brief (repo, PR, failing checks, rules) on stdin to
`claude -p` as a fresh one-shot session, in the background, inside the
watch's checkout (`pr-watchd add ... --agent [--dir <path>]`) — never your
interactive context. Drop `Bash(git:*)` if you want diagnosis only, no pushes.

The `gh` allowlist is read-only on purpose: a blanket `Bash(gh:*)` would also
allow `gh api` with any method and `gh pr merge`, and the agent reads CI logs
that a PR's author can influence.
Without `AGENT_CMD` the daemon only sends OS notifications.
