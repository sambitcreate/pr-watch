#!/usr/bin/env bash
# pr-watch installer — installs the daemon, the skill, and (optionally) the launchd timer.
set -eu

PREFIX="${PRWATCH_PREFIX:-$HOME/.local}"
SKILL_DIR_SRC="$(cd "$(dirname "$0")" && pwd)"
AGENTS="${AGENTS:-claude codex pi opencode}"
STATE_DIR="${PRWATCH_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/pr-watch}"
CONFIG_FILE="${PRWATCH_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/pr-watch/config.env}"

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

command -v gh >/dev/null 2>&1 || { say "gh CLI is required (https://cli.github.com)"; exit 1; }
command -v jq >/dev/null 2>&1 || { say "jq is required (https://jqlang.org)"; exit 1; }

mkdir -p "$PREFIX/bin" "$STATE_DIR"

say "installing pr-watchd → $PREFIX/bin"
install -m 0755 "$SKILL_DIR_SRC/bin/pr-watchd" "$PREFIX/bin/pr-watchd"

for a in $AGENTS; do
  case "$a" in
    claude)   root="$HOME/.claude" ;;
    codex)    root="$HOME/.codex" ;;
    pi)       root="$HOME/.pi/agent" ;;
    opencode) root="$HOME/.config/opencode" ;;
    *) say "unknown agent: $a"; exit 1 ;;
  esac
  d="$root/skills/pr-watch"
  # an agent counts as present if its config root exists (skills/ may not yet)
  if [ -d "$root" ] || [ "${FORCE_SKILLS:-0}" = "1" ]; then
    mkdir -p "$d"
    cp "$SKILL_DIR_SRC/SKILL.md" "$d/SKILL.md"
    say "skill installed for $a → $d"
  else
    say "skill skipped for $a ($root not found; set FORCE_SKILLS=1 to install anyway)"
  fi
done

if [ ! -f "$CONFIG_FILE" ]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cat > "$CONFIG_FILE" <<'EOF'
# pr-watch config — sourced as shell by pr-watchd. Environment variables win.
# WAKE_LIMIT=10
# READ_FAILURE_LIMIT=15
# NOTIFY_CMD=/path/to/notifier          # called as: NOTIFY_CMD <title> <message>
# Headless agent for `pr-watchd add ... --agent` (see adapters/):
# AGENT_CMD='claude -p --allowedTools "Bash(gh:*) Bash(git:*) Read Edit" --permission-mode acceptEdits'
EOF
  say "config template → $CONFIG_FILE"
fi

# launchd/cron start with a minimal PATH; bake in where gh, jq, and any
# agent CLIs (for --agent wakes) live
run_path="$PREFIX/bin"
for c in gh jq claude codex pi opencode; do
  p="$(command -v "$c" 2>/dev/null || true)"
  [ -n "$p" ] || continue
  case ":$run_path:" in *":$(dirname "$p"):"*) ;; *) run_path="$run_path:$(dirname "$p")" ;; esac
done
run_path="$run_path:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if [ "${1:-}" = "--launchd" ] && [ "$(uname)" = "Darwin" ]; then
  label="com.prwatch.daemon"
  plist="$HOME/Library/LaunchAgents/$label.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  sed -e "s|@BIN@|$PREFIX/bin|g" -e "s|@STATE@|$STATE_DIR|g" -e "s|@PATH@|$run_path|g" -e "s|@HOME@|$HOME|g" \
    "$SKILL_DIR_SRC/launchd/com.prwatch.daemon.plist.in" > "$plist"
  launchctl unload "$plist" 2>/dev/null || true
  launchctl load "$plist"
  say "launchd timer installed: $plist (every 5 minutes)"
  say "state dir: $STATE_DIR"
else
  say "add a cron line to run one poll pass every 5 minutes:"
  printf '  */5 * * * * PATH=%s %s/bin/pr-watchd tick >/dev/null 2>&1\n' "$run_path" "$PREFIX"
  if [ "$(uname)" = "Darwin" ]; then say "or re-run with --launchd on macOS"; fi
fi

say "next steps:"
printf '  %s/bin/pr-watchd add <owner/repo> <pr#> --auto   # merge-on-green\n' "$PREFIX"
printf '  %s/bin/pr-watchd digest                          # status table\n' "$PREFIX"
printf '  %s/bin/pr-watchd list                            # active watches\n' "$PREFIX"
