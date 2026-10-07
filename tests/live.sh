#!/usr/bin/env bash
# pr-watch live check — runs the daemon's real query against GitHub with your
# gh auth, read-only. Catches what a stub can't: flags gh rejects, field names
# the API doesn't return. Usage: bash tests/live.sh [owner/repo] [pr#]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PRWATCHD="$HERE/../bin/pr-watchd"
repo="${1:-cli/cli}"
pr="${2:-$(gh pr list --repo "$repo" --state all --limit 1 --json number --jq '.[0].number')}"
export PRWATCH_HOME="$(mktemp -d)" PRWATCH_CONFIG=/dev/null NOTIFY_CMD=true
trap 'rm -rf "$PRWATCH_HOME"' EXIT

row="$("$PRWATCHD" fetch "$repo" "$pr")" || { echo "NOT OK - fetch $repo#$pr failed"; exit 1; }
printf 'row: %s\n' "$row" | tr '\t' '|'
fields="$(printf '%s' "$row" | awk -F'\t' '{print NF}')"
sha="$(printf '%s' "$row" | cut -f1)"
nh="$(printf '%s' "$row" | cut -f5)"
cursor="$(printf '%s' "$row" | cut -f6)"
rc=0
[ "$fields" = "6" ] && echo "  ok  - 6 fields" || { echo "  NOT OK - expected 6 fields, got $fields"; rc=1; }
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] && echo "  ok  - head sha" || { echo "  NOT OK - head sha: $sha"; rc=1; }
[[ "$nh" =~ ^[0-9]+$ ]] && echo "  ok  - human count" || { echo "  NOT OK - human count: $nh"; rc=1; }
[[ -z "$cursor" || "$cursor" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]] && echo "  ok  - cursor" || { echo "  NOT OK - cursor: $cursor"; rc=1; }
"$PRWATCHD" add "$repo" "$pr" >/dev/null && "$PRWATCHD" tick >/dev/null && "$PRWATCHD" list | grep -qF "$repo" \
  && echo "  ok  - add/tick/list round-trip" || { echo "  NOT OK - add/tick/list round-trip"; rc=1; }
exit "$rc"
