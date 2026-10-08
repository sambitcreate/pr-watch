---
name: pr-watch
description: >
  Watch or babysit a pull request without burning tokens: prefer native
  auto-merge, register a zero-token external watcher for state changes, and
  only spend agent turns fixing real failures. Never poll, sleep, or block
  inside your own turn.
---

# pr-watch

When someone asks you to "watch this PR", "babysit CI", "wait for checks", or
"tell me when it's green" — do NOT loop inside your own turn. Sleeping inside
an agent turn re-sends the entire conversation context on every poll and
blocks all other work. That pattern is the single most expensive anti-pattern
in agent-assisted development.

## Decision order (always in this order)

### 1. Merge-on-green? Use GitHub, not yourself.

If the goal is "merge when checks pass", run:

```sh
gh pr merge <number> --repo <owner/repo> --auto --squash   # or --merge / --rebase
```

GitHub merges natively when required checks pass. You are done. Say so and
stop. No watcher needed unless you also want to fix failures.

### 2. Need to know when something changes? Register the watcher.

```sh
pr-watchd add <owner/repo> <pr-number>            # notify only (default)
pr-watchd add <owner/repo> <pr-number> --auto     # auto-merge + watch for conflicts/failures
pr-watchd add <owner/repo> <pr-number> --agent    # also hand failures to a headless agent
```

`--agent` needs a checkout to work in: run it from inside the repo, or pass
`--dir <path>`.

The daemon polls GitHub on a timer, outside any LLM. It wakes you (or the
user) only on: newly-failed checks, merge conflicts, green-and-ready, new
*human* comments and reviews (its own replies and bot comments never wake it),
or the PR being merged or closed (which also ends the watch).

Verify with `pr-watchd list`. Then **end your turn**. The watcher continues
without you; you will be invoked fresh, with a minimal brief, when there is
news worth paying tokens for.

### 3. "What's the status of everything?" Use the digest.

```sh
pr-watchd digest [owner/repo]   # zero-token table: state, reviews, next mergeable
```

Never answer this by walking PRs one API call at a time in your own context.

## Forbidden patterns

Never write any of these, in any agent, for any reason:

```sh
until [ "$(gh pr view N --json mergeable ...)" != "UNKNOWN" ]; do sleep 2; done   # unbounded spin
for i in $(seq 1 40); do ...; sleep 180; done            # hours blocked inside one tool call
gh run watch <id> --interval 120                          # parks the whole turn
sleep 45; gh pr list ...                                  # one-shot glance pretending to be watching
```

Rules they violate: no unbounded loops (always cap iterations and wall time),
no tool call may block longer than ~5 seconds, no re-polling state you can be
woken for.

## If you cannot use the daemon (not installed, and you can't install it)

Fall back to the *cheap* loop, and say why you're falling back:

- one `gh pr checks <number>` call,
- then end the turn and ask to be re-invoked, or use the host agent's
  background/scheduled task feature with a wake — never a busy loop.
- Hard caps: ≤ 10 iterations, ≤ 30 s total sleeping, one retry for flaky CI.

## Fixing failures (when woken)

The wake brief contains only: repo, PR number, failing check names. Fetch
logs yourself (`gh pr checks`, `gh run view --log-failed`), fix, push. Cap:
10 tool rounds, one retry for flaky tests, then report back and stop.
Do not re-register polling loops — the daemon is still watching.
