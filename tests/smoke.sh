#!/usr/bin/env bash
# pr-watch smoke suite — behavior tests with a stubbed gh and real jq logic.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"
PRWATCHD="$SRC/bin/pr-watchd"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export FAKE_DIR="$WORK/fake" PRWATCHD_SRC="$PRWATCHD"
export PRWATCH_HOME="$WORK/state"
mkdir -p "$FAKE_DIR" "$PRWATCH_HOME"
ln -sf "$HERE/fake-gh" "$FAKE_DIR/gh"
export PATH="$FAKE_DIR:$PATH"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok  - $1"; }
fail() { FAIL=$((FAIL+1)); echo "  NOT OK - $1"; }
assert_contains() { # assert_contains <haystack-file> <needle> <label>
  if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else fail "$3 (missing: $2)"; fi
}
assert_count() { # assert_count <file> <n> <label>
  local n; n="$(grep -c . "$1" 2>/dev/null)"; n="${n:-0}"
  if [ "$n" = "$2" ]; then ok "$3"; else fail "$3 (expected $2 lines, got $n)"; fi
}

# recorder stands in for OS notifications
cat > "$FAKE_DIR/notify" <<'EOF'
#!/usr/bin/env bash
echo "$1|$2" >> "$NOTIFY_LOG"
EOF
chmod +x "$FAKE_DIR/notify"
export NOTIFY_LOG="$WORK/notify.log"
export NOTIFY_CMD="$FAKE_DIR/notify"
export WAKE_LIMIT=3 READ_FAILURE_LIMIT=3
: > "$NOTIFY_LOG"

# fixture writer: write_pr <sha> <mstate> <mergeable> <failedname|''> <comments-json>
write_pr() {
  local sha="$1" mstate="$2" mergeable="$3" failed="$4" comments="$5"
  local checks
  checks='{"__typename":"CheckRun","name":"ci/test","status":"COMPLETED","conclusion":"SUCCESS"}'
  [ -n "$failed" ] && checks="$checks"',{ "__typename":"CheckRun","name":"'"$failed"'","status":"COMPLETED","conclusion":"FAILURE"}'
  printf '{"headRefOid":"%s","mergeable":"%s","mergeStateStatus":"%s","statusCheckRollup":[%s],"comments":%s}' \
    "$sha" "$mergeable" "$mstate" "$checks" "$comments" > "$FAKE_DIR/pr.json"
  jq -e . "$FAKE_DIR/pr.json" > /dev/null 2>&1 || { echo "bad fixture json"; jq . "$FAKE_DIR/pr.json" >&2 || true; exit 1; }
}

bot_comment='{"databaseId":100,"author":{"login":"renovate[bot]"}}'
own_comment='{"databaseId":101,"author":{"login":"me"}}'
human_comment='{"databaseId":102,"author":{"login":"alice"}}'

echo "# 1. add + baseline tick: no noise"
write_pr "aaaa000" "CLEAN" "MERGEABLE" "" "[$bot_comment,$own_comment]"
echo 0 > "$FAKE_DIR/lastcid.txt"
"$PRWATCHD" add example/repo 12 >/dev/null 2>&1 && ok "add exits 0" || fail "add exits 0"
"$PRWATCHD" tick >/dev/null 2>&1
assert_count "$NOTIFY_LOG" 0 "baseline tick is silent"

echo "# 2. a check starts failing: exactly one wake, naming the check"
write_pr "aaaa000" "UNSTABLE" "MERGEABLE" "lint" "[$bot_comment,$own_comment]"
"$PRWATCHD" tick >/dev/null 2>&1
assert_count "$NOTIFY_LOG" 1 "failed check wakes once"
assert_contains "$NOTIFY_LOG" "lint" "wake names the failing check"

echo "# 3. same failure next tick: no repeat"
"$PRWATCHD" tick >/dev/null 2>&1
assert_count "$NOTIFY_LOG" 1 "known failure does not re-wake"

echo "# 4. bot posts a comment: suppressed"
write_pr "aaaa000" "UNSTABLE" "MERGEABLE" "lint" "[$bot_comment,$own_comment,{\"databaseId\":103,\"author\":{\"login\":\"dependabot[bot]\"}}]"
"$PRWATCHD" tick >/dev/null 2>&1
assert_count "$NOTIFY_LOG" 1 "bot comments never wake"

echo "# 5. own account posts a comment: suppressed"
write_pr "aaaa000" "UNSTABLE" "MERGEABLE" "lint" "[$bot_comment,$own_comment,{\"databaseId\":104,\"author\":{\"login\":\"me\"}}]"
"$PRWATCHD" tick >/dev/null 2>&1
assert_count "$NOTIFY_LOG" 1 "own replies never wake"

echo "# 6. human comment: wakes"
write_pr "aaaa000" "UNSTABLE" "MERGEABLE" "lint" "[$bot_comment,$own_comment,$human_comment]"
"$PRWATCHD" tick >/dev/null 2>&1
assert_count "$NOTIFY_LOG" 2 "human comment wakes"
assert_contains "$NOTIFY_LOG" "comment" "wake mentions the comment"

echo "# 7. head moves: failure memory resets, then green reports once"
write_pr "bbbb000" "UNSTABLE" "MERGEABLE" "" "[$bot_comment,$own_comment]"
"$PRWATCHD" tick >/dev/null 2>&1   # new head, no failures: reset only, no wake (nothing new)
write_pr "bbbb000" "CLEAN" "MERGEABLE" "" "[$bot_comment,$own_comment]"
"$PRWATCHD" tick >/dev/null 2>&1
assert_contains "$NOTIFY_LOG" "green" "green transition is reported"
"$PRWATCHD" tick >/dev/null 2>&1
assert_count "$NOTIFY_LOG" 3 "green is reported once, not every tick"

echo "# 8. wake limit parks the watch"
rm -f "$PRWATCH_HOME"/*.state "$NOTIFY_LOG"
write_pr "cccc000" "CLEAN" "MERGEABLE" "" "[$bot_comment]"
echo 0 > "$FAKE_DIR/lastcid.txt"
"$PRWATCHD" add example/repo 13 >/dev/null 2>&1
for i in 1 2 3 4; do
  write_pr "cccc000" "CLEAN" "MERGEABLE" "" "[$bot_comment,{\"databaseId\":20$i,\"author\":{\"login\":\"alice\"}}]"
  "$PRWATCHD" tick >/dev/null 2>&1
done
assert_contains "$NOTIFY_LOG" "parked" "unproductive wakes park the watch"
if ls "$PRWATCH_HOME"/*.state >/dev/null 2>&1; then fail "parked watch state removed"; else ok "parked watch state removed"; fi

echo "# 9. read failures drop the watch"
: > "$NOTIFY_LOG"
echo 0 > "$FAKE_DIR/lastcid.txt"
write_pr "dddd000" "CLEAN" "MERGEABLE" "" "[]"
"$PRWATCHD" add example/repo 14 >/dev/null 2>&1
mv "$FAKE_DIR/pr.json" "$FAKE_DIR/pr.json.bak"   # gh reads now fail
"$PRWATCHD" tick >/dev/null 2>&1; "$PRWATCHD" tick >/dev/null 2>&1; "$PRWATCHD" tick >/dev/null 2>&1
mv "$FAKE_DIR/pr.json.bak" "$FAKE_DIR/pr.json"
assert_contains "$NOTIFY_LOG" "unreadable" "consecutive read failures are reported"
if ls "$PRWATCH_HOME"/*.state >/dev/null 2>&1; then fail "broken watch dropped"; else ok "broken watch dropped"; fi

echo "# 10. list and digest"
"$PRWATCHD" add example/repo 15 >/dev/null 2>&1
"$PRWATCHD" list >/dev/null 2>&1 && ok "list runs" || fail "list runs"
printf '7\tCLEAN\n9\tBLOCKED\n' > "$FAKE_DIR/list.tsv"
"$PRWATCHD" digest example/repo >/dev/null 2>&1 && ok "digest runs" || fail "digest runs"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" = "0" ]
