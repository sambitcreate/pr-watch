#!/usr/bin/env bash
# pr-watch installer — installs the daemon, the skill, and (optionally) the launchd timer.
set -eu

PREFIX="${PRWATCH_PREFIX:-$HOME/.local}"
SKILL_DIR_SRC="$(cd "$(dirname "$0")" && pwd)"
AGENTS="${AGENTS:-claude codex pi opencode}"

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

[ -x "$(command -v gh || true)" ] || { say "gh CLI is required (https://cli.github.com)"; exit 1; }

mkdir -p "$PREFIX/bin"

say "installing pr-watchd → $PREFIX/bin"
sed "s|#!/usr/bin/env bash|#!/usr/bin/env bash|" "$SKILL_DIR_SRC/bin/pr-watchd" > "$PREFIX/bin/pr-watchd"
chmod +x "$PREFIX/bin/pr-watchd"

for a in $AGENTS; do
  case "$a" in
    claude)  d="$HOME/.claude/skills/pr-watch" ;;
    codex)   d="$HOME/.codex/skills/pr-watch" ;;
    pi)      d="$HOME/.pi/agent/skills/pr-watch" ;;
    opencode) d="$HOME/.config/opencode/skills/pr-watch" ;;
    *) say "unknown agent: $a"; exit 1 ;;
  esac
  if [ -d "$(dirname "$d")" ] || [ "${FORCE_SKILLS:-0}" = "1" ]; then
    mkdir -p "$d"
    cp "$SKILL_DIR_SRC/SKILL.md" "$d/SKILL.md"
    say "skill installed for $a → $d"
  else
    say "skill skipped for $a ($dirname-not-present pattern: $(dirname "$d") not found; set FORCE_SKILLS=1 to install anyway)"
  fi
done

if [ "${1:-}" = "--launchd" ] && [ "$(uname)" = "Darwin" ]; then
  label="com.prwatch.daemon"
  plist="$HOME/Library/LaunchAgents/$label.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  sed "s|@HOME@|$HOME|g" "$SKILL_DIR_SRC/launchd/com.prwatch.daemon.plist.in" > "$plist"
  launchctl unload "$plist" 2>/dev/null || true
  launchctl load "$plist"
  say "launchd timer installed: $plist (every 5 minutes)"
  say "state dir: ${XDG_STATE_HOME:-$HOME/.local/state}/pr-watch"
else
  say "add a cron line to run one poll pass every 5 minutes:"
  printf '  */5 * * * * %s/bin/pr-watchd tick >/dev/null 2>&1\n' "$PREFIX"
  say "or re-run with --launchd on macOS"
fi

say "next steps:"
printf '  %s/bin/pr-watchd add <owner/repo> <pr#> --auto   # merge-on-green\n' "$PREFIX"
printf '  %s/bin/pr-watchd digest                          # status table\n' "$PREFIX"
printf '  %s/bin/pr-watchd list                            # active watches\n' "$PREFIX"
