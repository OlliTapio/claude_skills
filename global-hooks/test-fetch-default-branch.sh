#!/bin/sh
# shellcheck disable=SC2015  # `cond && ok ... || bad ...` is safe here: both
# helpers always return 0, so the || branch only runs when cond is false.
#
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

# ... and so must the local branch, when doing so is lossless: this consumer is
# on main, clean, and strictly behind.
head=$(git -C "$TMP/plain-consumer" log -1 --format=%s HEAD)
[ "$head" = "NEW" ] && ok "fast-forwards a clean checked-out default branch" \
                    || bad "fast-forwards a clean checked-out default branch" "HEAD=$head"

# ff via `merge --ff-only`, so the index must agree with the new tree. A bare
# ref move (update-ref / --update-head-ok) leaves a staged deletion of every
# file the new commits added -- the footgun this guards against.
st=$(git -C "$TMP/plain-consumer" status --porcelain 2>/dev/null)
[ -z "$st" ] && ok "fast-forward leaves the index and tree consistent" \
             || bad "fast-forward leaves the index and tree consistent" "status: $st"

# The opt-out must fall back to the refs/remotes-only behaviour.
mkrepo optout main
CLAUDE_HOOK_FF_LOCAL_DEFAULT=0 sh -c \
  "printf '%s' '{\"cwd\":\"$TMP/optout-consumer\"}' | '$HOOK'" >/dev/null 2>&1
head=$(git -C "$TMP/optout-consumer" log -1 --format=%s HEAD)
rem=$(git -C "$TMP/optout-consumer" log -1 --format=%s origin/main)
[ "$head" = "first" ] && [ "$rem" = "NEW" ] \
  && ok "CLAUDE_HOOK_FF_LOCAL_DEFAULT=0 fetches but does not move local main" \
  || bad "CLAUDE_HOOK_FF_LOCAL_DEFAULT=0 fetches but does not move local main" "HEAD=$head origin=$rem"

echo
echo "== local fast-forward is refused unless provably lossless =="

# Uncommitted work: never move the branch out from under it.
mkrepo dirty main
echo scratch > "$TMP/dirty-consumer/tracked.txt"
git -C "$TMP/dirty-consumer" -c user.email=t@t -c user.name=t add tracked.txt
git -C "$TMP/dirty-consumer" -c user.email=t@t -c user.name=t commit -q -m local-tracked
git -C "$TMP/dirty-consumer" reset -q --soft HEAD~1   # keeps the change staged
printf '%s' "{\"cwd\":\"$TMP/dirty-consumer\"}" | "$HOOK" >/dev/null 2>&1
head=$(git -C "$TMP/dirty-consumer" log -1 --format=%s HEAD)
[ "$head" = "first" ] && ok "skips a worktree with uncommitted changes" \
                      || bad "skips a worktree with uncommitted changes" "HEAD=$head"

# Diverged local branch: a fast-forward is impossible, so nothing may be rewritten.
mkrepo diverged main
git -C "$TMP/diverged-consumer" -c user.email=t@t -c user.name=t \
    commit -q --allow-empty -m LOCAL-ONLY
printf '%s' "{\"cwd\":\"$TMP/diverged-consumer\"}" | "$HOOK" >/dev/null 2>&1
head=$(git -C "$TMP/diverged-consumer" log -1 --format=%s HEAD)
[ "$head" = "LOCAL-ONLY" ] && ok "never rewrites a diverged local branch" \
                           || bad "never rewrites a diverged local branch" "HEAD=$head"

# A half-finished merge is human state -- hard stop even though the tree may look clean.
mkrepo midmerge main
git -C "$TMP/midmerge-consumer" rev-parse HEAD > \
  "$(git -C "$TMP/midmerge-consumer" rev-parse --absolute-git-dir)/MERGE_HEAD"
printf '%s' "{\"cwd\":\"$TMP/midmerge-consumer\"}" | "$HOOK" >/dev/null 2>&1
head=$(git -C "$TMP/midmerge-consumer" log -1 --format=%s HEAD)
[ "$head" = "first" ] && ok "skips a worktree with a merge in progress" \
                      || bad "skips a worktree with a merge in progress" "HEAD=$head"

# Not checked out anywhere: a bare ref move is safe, and is what should happen.
mkrepo detached main
git -C "$TMP/detached-consumer" checkout -q --detach
printf '%s' "{\"cwd\":\"$TMP/detached-consumer\"}" | "$HOOK" >/dev/null 2>&1
got=$(git -C "$TMP/detached-consumer" log -1 --format=%s refs/heads/main)
[ "$got" = "NEW" ] && ok "moves the ref when the branch is checked out nowhere" \
                   || bad "moves the ref when the branch is checked out nowhere" "main=$got"

# On another branch: main is checked out nowhere, so it may advance -- but the
# branch the user is actually on must not be touched.
mkrepo elsewhere main
git -C "$TMP/elsewhere-consumer" checkout -q -b feature
printf '%s' "{\"cwd\":\"$TMP/elsewhere-consumer\"}" | "$HOOK" >/dev/null 2>&1
main=$(git -C "$TMP/elsewhere-consumer" log -1 --format=%s refs/heads/main)
feat=$(git -C "$TMP/elsewhere-consumer" log -1 --format=%s HEAD)
[ "$main" = "NEW" ] && [ "$feat" = "first" ] \
  && ok "advances main while leaving the checked-out feature branch alone" \
  || bad "advances main while leaving the checked-out feature branch alone" "main=$main feature=$feat"

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
echo "== guards are established before the first network call =="
# Shim `git` to record the environment at the moment of each network call.
# Without this, deleting the guard exports still passes every other test.
REALGIT=$(command -v git)
mkdir -p "$TMP/shim"
GUARD_LOG="$TMP/guard.log"
export GUARD_LOG REALGIT
cat > "$TMP/shim/git" <<'SHIM'
#!/bin/sh
for a in "$@"; do
  case $a in
    ls-remote|fetch)
      printf 'TERMPROMPT=%s SSHCMD=%s\n' \
        "${GIT_TERMINAL_PROMPT-unset}" "${GIT_SSH_COMMAND-unset}" >> "$GUARD_LOG"
      break ;;
  esac
done
exec "$REALGIT" "$@"
SHIM
chmod +x "$TMP/shim/git"

mkrepo guards main
: > "$GUARD_LOG"
PATH="$TMP/shim:$PATH" sh -c "printf '%s' '{\"cwd\":\"$TMP/guards-consumer\"}' | '$HOOK'" >/dev/null 2>&1

if [ ! -s "$GUARD_LOG" ]; then
  bad "guard shim observed a network call" "no ls-remote/fetch recorded"
else
  grep -q 'TERMPROMPT=0' "$GUARD_LOG" \
    && ok "GIT_TERMINAL_PROMPT=0 set before network call" \
    || bad "GIT_TERMINAL_PROMPT=0 set before network call" "$(cat "$GUARD_LOG")"
  grep -q 'BatchMode=yes' "$GUARD_LOG" \
    && ok "ssh BatchMode set before network call" \
    || bad "ssh BatchMode set before network call" "$(cat "$GUARD_LOG")"
fi

# ssh honours the FIRST -o, so our options must be inserted after the command
# word -- appending would lose to a user who already set BatchMode=no.
: > "$GUARD_LOG"
mkrepo sshpre main
PATH="$TMP/shim:$PATH" GIT_SSH_COMMAND="ssh -oBatchMode=no -i /tmp/k" \
  sh -c "printf '%s' '{\"cwd\":\"$TMP/sshpre-consumer\"}' | '$HOOK'" >/dev/null 2>&1
line=$(head -1 "$GUARD_LOG")
case $line in
  *"ssh -oBatchMode=yes -oConnectTimeout=5 -oBatchMode=no -i /tmp/k"*)
    ok "our ssh options precede a user's existing GIT_SSH_COMMAND" ;;
  *)
    bad "our ssh options precede a user's existing GIT_SSH_COMMAND" "$line" ;;
esac

echo
echo "== awk fallback works without python3 =="
# The regex fallback is never exercised on a machine that has python3. Shadow
# python3 with a stub that always fails, rather than stripping PATH -- git
# resolves its libexec helpers relative to its own binary, so a symlinked git
# in a bare PATH breaks for reasons unrelated to this hook.
mkdir -p "$TMP/nopy"
printf '#!/bin/sh\nexit 127\n' > "$TMP/nopy/python3"
chmod +x "$TMP/nopy/python3"
mkrepo nopy main
PATH="$TMP/nopy:$PATH" sh -c \
  "printf '%s' '{\"cwd\":\"$TMP/nopy-consumer\",\"tool_input\":{\"cwd\":\"/does/not/exist\"}}' | '$HOOK'" \
  >/dev/null 2>&1
got=$(git -C "$TMP/nopy-consumer" log -1 --format=%s origin/main 2>/dev/null)
[ "$got" = "NEW" ] && ok "awk fallback parses cwd when python3 is unavailable" \
                   || bad "awk fallback parses cwd when python3 is unavailable" "origin/main=$got"

echo
[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit $fail
