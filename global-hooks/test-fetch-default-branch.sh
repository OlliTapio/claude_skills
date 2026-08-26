#!/bin/sh
# Self-contained tests for fetch-default-branch.sh.
# Builds its own scratch repos -- no dependency on the machine's checkouts.
#
#   sh global-hooks/test-fetch-default-branch.sh
#
# Exits non-zero if any case fails.

HOOK=$(cd "$(dirname "$0")" && pwd)/fetch-default-branch.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail=0
ok()   { printf 'PASS  %s\n' "$1"; }
bad()  { printf 'FAIL  %s -- %s\n' "$1" "$2"; fail=1; }

# Every input must exit 0: a hook that can fail can block a worktree.
exits0() {
  printf '%s' "$2" | "$HOOK" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && ok "$1" || bad "$1" "exit=$rc"
}

# --- a scratch remote + a clone that is deliberately behind it ---------------
mkrepo() {  # mkrepo <name> <branch>
  git init -q --bare "$TMP/$1.git" --initial-branch="$2"
  git clone -q "$TMP/$1.git" "$TMP/$1-work" 2>/dev/null
  git -C "$TMP/$1-work" -c user.email=t@t -c user.name=t \
      commit -q --allow-empty -m first
  git -C "$TMP/$1-work" push -q origin "$2"
  git clone -q "$TMP/$1.git" "$TMP/$1-consumer"
  git -C "$TMP/$1-work" -c user.email=t@t -c user.name=t \
      commit -q --allow-empty -m NEW
  git -C "$TMP/$1-work" push -q origin "$2"
}

echo "== exit-code contract (never block) =="
exits0 "non-git dir"           '{"cwd":"/tmp"}'
exits0 "no cwd key"            '{}'
exits0 "malformed json"        'garbage not json'
exits0 "empty stdin"           ''
exits0 "nonexistent path"      '{"cwd":"/does/not/exist"}'

echo
echo "== payload parsing =="
# A nested "cwd" must never shadow the top-level one.
mkrepo nest main
out=$(printf '%s' "{\"cwd\":\"$TMP/nest-consumer\",\"tool_input\":{\"cwd\":\"/does/not/exist\"}}" \
      | "$HOOK" 2>&1; echo "rc=$?")
got=$(git -C "$TMP/nest-consumer" log -1 --format=%s origin/main 2>/dev/null)
[ "$got" = "NEW" ] && ok "nested cwd does not shadow top-level" \
                   || bad "nested cwd does not shadow top-level" "origin/main=$got ($out)"

echo
echo "== fetch behaviour =="
mkrepo plain main
before=$(git -C "$TMP/plain-consumer" log -1 --format=%s origin/main)
printf '%s' "{\"cwd\":\"$TMP/plain-consumer\"}" | "$HOOK" >/dev/null 2>&1
after=$(git -C "$TMP/plain-consumer" log -1 --format=%s origin/main)
[ "$before" = "first" ] && [ "$after" = "NEW" ] \
  && ok "advances a stale remote-tracking ref" \
  || bad "advances a stale remote-tracking ref" "$before -> $after"

# The local checkout must be left alone -- we only move refs/remotes/*.
head=$(git -C "$TMP/plain-consumer" log -1 --format=%s HEAD)
[ "$head" = "first" ] && ok "leaves local HEAD untouched" \
                      || bad "leaves local HEAD untouched" "HEAD=$head"

# Default branch must come from the repo, not a hardcoded "main".
mkrepo odd trunk
printf '%s' "{\"cwd\":\"$TMP/odd-consumer\"}" | "$HOOK" >/dev/null 2>&1
got=$(git -C "$TMP/odd-consumer" log -1 --format=%s origin/trunk)
[ "$got" = "NEW" ] && ok "resolves non-main default branch (trunk)" \
                   || bad "resolves non-main default branch (trunk)" "origin/trunk=$got"

# With no cached origin/HEAD the ls-remote --symref fallback must kick in.
mkrepo nohead trunk
git -C "$TMP/nohead-consumer" symbolic-ref -d refs/remotes/origin/HEAD 2>/dev/null
printf '%s' "{\"cwd\":\"$TMP/nohead-consumer\"}" | "$HOOK" >/dev/null 2>&1
got=$(git -C "$TMP/nohead-consumer" log -1 --format=%s origin/trunk)
[ "$got" = "NEW" ] && ok "falls back to ls-remote when origin/HEAD is absent" \
                   || bad "falls back to ls-remote when origin/HEAD is absent" "origin/trunk=$got"

echo
echo "== unreachable remote is bounded =="
# Blackholed IP: must exit 0 and stay under Claude Code's 30s hook timeout.
git -C "$TMP/nohead-consumer" remote set-url origin https://192.0.2.1/nope.git
git -C "$TMP/nohead-consumer" symbolic-ref -d refs/remotes/origin/HEAD 2>/dev/null
s=$(date +%s)
printf '%s' "{\"cwd\":\"$TMP/nohead-consumer\"}" | "$HOOK" >/dev/null 2>&1
rc=$?
e=$(date +%s)
el=$((e - s))
if [ "$rc" -ne 0 ]; then
  bad "blackholed remote exits 0" "exit=$rc"
elif command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
  [ "$el" -lt 30 ] && ok "blackholed remote bounded (${el}s < 30s)" \
                   || bad "blackholed remote bounded" "${el}s exceeds the 30s hook timeout"
else
  ok "blackholed remote exits 0 (${el}s; no timeout binary, unbounded by design)"
fi

echo
[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit $fail
