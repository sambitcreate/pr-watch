# pr-watch

**PR babysitting that never burns tokens while waiting.**

A tiny shell daemon + agent skill that implements the *correct* pattern for
"watch this PR": wait with shells, fix with agents, and never poll inside an
LLM turn.

Works with **Claude Code, Codex, Pi, and opencode**.

## Why

An audit of local coding-agent logs found that when agents are asked to
"watch CI" or "babysit a PR", nearly all of the wasted tokens come from one
anti-pattern: **polling inside the agent turn**. Every `sleep 60` in a loop
re-sends the entire conversation context to the model on the next
iteration. Billions of input tokens have been spent — at API prices, real
money — teaching agents to do what a `while` loop and `gh api` do for free.

Worse, the hand-rolled loops are reliably buggy in the same few ways:

| Hand-rolled pattern | Failure mode |
|---|---|
| `until [ "$(gh pr view …)" != "UNKNOWN" ]; do sleep 2; done` | unbounded spin, no timeout |
| `for i in $(seq 1 40); do …; sleep 180; done` | hours blocked in one tool call; killed by tool timeout; retried; re-paid |
| `sleep 45; gh pr list …` | a one-shot glance pretending to be watching |
| `gh run watch --interval 120` | parks the entire agent for the CI duration |
| "haiku subagent, keep an eye on CI" | the watcher forgets, the wake never fires, you re-ask tomorrow |

`pr-watchd` makes those impossible: polling happens in a 60-line shell script
on a timer, costs zero tokens, and only *state changes* wake anyone.

## Install

```sh
git clone https://github.com/sambitcreate/pr-watch.git   # or your fork
cd pr-watch
./install.sh                      # daemon + skills for detected agents
./install.sh --launchd            # macOS: also install the 5-minute timer
```

Requirements: [`gh`](https://cli.github.com) (authenticated), `jq`, bash.
Cron users: add `*/5 * * * * ~/.local/bin/pr-watchd tick >/dev/null 2>&1`.

## Use

```sh
# merge-on-green: GitHub does the waiting natively. Zero tokens.
gh pr merge 123 --auto --squash

# need to hear about failures/conflicts/human comments? register a watcher:
pr-watchd add owner/repo 123 --auto       # auto-merge + watch
pr-watchd add owner/repo 123              # watch + notify only
pr-watchd add owner/repo 123 --agent      # also hand failures to a headless agent

pr-watchd list                            # what's being watched
pr-watchd digest owner/repo               # zero-token status table
pr-watchd remove owner/repo 123
```

Then end your agent turn. The daemon keeps watching; agents get woken fresh.

## How it wakes

On each tick, per watch, the daemon diffs current state against what it last
reported:

- **newly-failed checks** — reported the moment they fail (an advisory check
  that never finishes cannot hold news back)
- **merge conflict** — reported once per head
- **green & ready** — reported once per head
- **new human comments** — its own replies and `[bot]` accounts never wake it

Optional `--agent` mode pipes a minimal brief (repo, PR, failing check names,
hard rules) into a headless agent — `claude -p`, `codex exec`, `pi --print`,
or `opencode run` — as a *fresh* session. Your interactive context is never
re-sent.

## Guards (learned the hard way)

| Guard | Default | Prevents |
|---|---|---|
| `WAKE_LIMIT` | 10 | a chatty loop waking you forever; watch auto-parks |
| `READ_FAILURE_LIMIT` | 15 | unreadable PRs burning the watch; watch is dropped |
| baseline seeding | on | watching re-announces the state you already knew |
| head-move reset | on | stale failure memory after a force-push |
| own-reply suppression | on | the agent waking itself |
| bot suppression | on | CI bots and renovators as noise |

All are environment-tunable; see the top of `bin/pr-watchd`.

## The skill

`SKILL.md` is the agent-facing contract, installed into each agent's skill
directory (`~/.claude/skills/`, `~/.codex/skills/`, `~/.pi/agent/skills/`,
`~/.config/opencode/skills/`). It teaches the decision order:

1. merge-on-green → `gh pr merge --auto` (no watching needed)
2. need news? → `pr-watchd add` (external watcher)
3. status question → `pr-watchd digest` (one call, zero tokens)
4. forbidden: unbounded loops, blocking sleeps, `gh run watch`

Per-agent adapter notes live in [`adapters/`](adapters/).

## Privacy

No telemetry, no accounts, no network calls beyond `gh` itself. Watch state
is local files under your state directory. Nothing in this repo contains
personal data; `pr-watchd` reads your GitHub login at runtime only to know
which comments are your own.

## Development

```sh
bash tests/smoke.sh     # 17 behavior tests, stubbed gh, real diffing logic
```

MIT — see [LICENSE](LICENSE).
