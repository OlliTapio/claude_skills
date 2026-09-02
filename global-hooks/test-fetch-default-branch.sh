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

# The extractor is shared, so hook_event_name goes through the same fallback --
# and a mis-parsed event silently turns the stale-HEAD report off.
mkrepo nopyev main
git -C "$TMP/nopyev-consumer" checkout -q -b feat
out=$(PATH="$TMP/nopy:$PATH" sh -c \
  "printf '%s' '{\"cwd\":\"$TMP/nopyev-consumer\",\"hook_event_name\":\"SessionStart\"}' | '$HOOK'" \
  2>/dev/null)
case "$out" in
  *"behind origin/main"*) ok "awk fallback parses hook_event_name too" ;;
  *) bad "awk fallback parses hook_event_name too" "out=[$out]" ;;
esac

echo
echo "== rebase a Claude-cut worktree onto the fresh default =="

# A consumer clone plus a worktree where Claude Code puts them. The worktree
# branch is cut from the STALE main, then main moves -- the exact shape of the
# bug: born from a base that was already behind.
mkwt() {  # mkwt <name> [--outside]
  mkrepo "$1" main
  _c="$TMP/$1-consumer"
  case "$2" in
    --outside) _w="$TMP/$1-elsewhere" ;;
    --sibling) _w="$TMP/$1-consumer-worktree-wt" ;;
    *) _w="$_c/.claude/worktrees/wt"; mkdir -p "$_c/.claude/worktrees" ;;
  esac
  git -C "$_c" worktree add -q -b feat "$_w" HEAD 2>/dev/null
  printf 'mine\n' > "$_w/mine.txt"
  git -C "$_w" add mine.txt
  git -C "$_w" -c user.email=t@t -c user.name=t commit -q -m MINE
  WT=$_w
}

mkwt reb
printf '%s' "{\"cwd\":\"$WT\"}" | "$HOOK" >/dev/null 2>&1
# The worktree's own commit must survive, replayed on top of the new main.
subj=$(git -C "$WT" log --format=%s -3 | tr '\n' ',')
[ "$subj" = "MINE,NEW,first," ] \
  && ok "replays the worktree's commits onto the fetched default" \
  || bad "replays the worktree's commits onto the fetched default" "log=$subj"
st=$(git -C "$WT" status --porcelain 2>/dev/null)
[ -z "$st" ] && ok "rebase leaves the worktree clean" \
             || bad "rebase leaves the worktree clean" "status: $st"
[ -f "$WT/mine.txt" ] && ok "rebase keeps the worktree's files" \
                      || bad "rebase keeps the worktree's files" "mine.txt gone"

# Dirty worktree: the guard must refuse before touching history.
mkwt wtdirty
printf 'wip\n' >> "$WT/mine.txt"
printf '%s' "{\"cwd\":\"$WT\"}" | "$HOOK" >/dev/null 2>&1
subj=$(git -C "$WT" log -1 --format=%s)
[ "$subj" = "MINE" ] && [ -n "$(git -C "$WT" status --porcelain)" ] \
  && ok "skips a worktree with uncommitted work" \
  || bad "skips a worktree with uncommitted work" "HEAD=$subj"

# The sibling layout `<repo>-worktree-<name>` that older builds produce must be
# recognised too -- matching only .claude/worktrees/ silently disabled this half
# on a machine that uses the sibling layout.
mkwt sib --sibling
printf '%s' "{\"cwd\":\"$WT\"}" | "$HOOK" >/dev/null 2>&1
subj=$(git -C "$WT" log --format=%s -3 | tr '\n' ',')
[ "$subj" = "MINE,NEW,first," ] \
  && ok "recognises the sibling <repo>-worktree-<name> layout" \
  || bad "recognises the sibling <repo>-worktree-<name> layout" "log=$subj"

# A worktree a human added by hand is not ours to rewrite.
mkwt outside --outside
printf '%s' "{\"cwd\":\"$WT\"}" | "$HOOK" >/dev/null 2>&1
subj=$(git -C "$WT" log -1 --format=%s)
base=$(git -C "$WT" log -2 --format=%s | tail -1)
[ "$base" = "first" ] && ok "leaves a worktree outside .claude/worktrees alone" \
                      || bad "leaves a worktree outside .claude/worktrees alone" "parent=$base"

# The primary checkout is never rebased, even on a stale feature branch --
# that is the human's working copy.
mkrepo prim main
git -C "$TMP/prim-consumer" checkout -q -b feat
git -C "$TMP/prim-consumer" -c user.email=t@t -c user.name=t \
    commit -q --allow-empty -m MINE
printf '%s' "{\"cwd\":\"$TMP/prim-consumer\"}" | "$HOOK" >/dev/null 2>&1
base=$(git -C "$TMP/prim-consumer" log -2 --format=%s | tail -1)
[ "$base" = "first" ] && ok "never rebases a branch in the primary checkout" \
                      || bad "never rebases a branch in the primary checkout" "parent=$base"

# A conflicting rebase must leave the worktree byte-identical, never half-done.
mkrepo conf main
printf 'upstream\n' > "$TMP/conf-work/clash.txt"
git -C "$TMP/conf-work" add clash.txt
git -C "$TMP/conf-work" -c user.email=t@t -c user.name=t commit -q -m UPSTREAM
git -C "$TMP/conf-work" push -q origin main
_c="$TMP/conf-consumer"; mkdir -p "$_c/.claude/worktrees"
git -C "$_c" worktree add -q -b feat "$_c/.claude/worktrees/wt" HEAD 2>/dev/null
printf 'mine\n' > "$_c/.claude/worktrees/wt/clash.txt"
git -C "$_c/.claude/worktrees/wt" add clash.txt
git -C "$_c/.claude/worktrees/wt" -c user.email=t@t -c user.name=t commit -q -m MINE
before=$(git -C "$_c/.claude/worktrees/wt" rev-parse HEAD)
printf '%s' "{\"cwd\":\"$_c/.claude/worktrees/wt\"}" | "$HOOK" >/dev/null 2>&1
after=$(git -C "$_c/.claude/worktrees/wt" rev-parse HEAD)
gd=$(git -C "$_c/.claude/worktrees/wt" rev-parse --absolute-git-dir)
[ "$before" = "$after" ] && [ ! -e "$gd/rebase-merge" ] && [ ! -e "$gd/rebase-apply" ] \
  && ok "aborts a conflicting rebase and leaves no in-progress state" \
  || bad "aborts a conflicting rebase and leaves no in-progress state" "HEAD moved or rebase left mid-flight"

# Opt-out.
mkwt optreb
CLAUDE_HOOK_REBASE_WORKTREE=0 sh -c \
  "printf '%s' '{\"cwd\":\"$WT\"}' | '$HOOK'" >/dev/null 2>&1
base=$(git -C "$WT" log -2 --format=%s | tail -1)
[ "$base" = "first" ] && ok "CLAUDE_HOOK_REBASE_WORKTREE=0 disables the rebase" \
                      || bad "CLAUDE_HOOK_REBASE_WORKTREE=0 disables the rebase" "parent=$base"

echo
echo "== report a stale HEAD the hook must not move =="

# The primary-checkout case that started all this: agent must be told.
mkrepo rep main
git -C "$TMP/rep-consumer" checkout -q -b feat
out=$(printf '%s' "{\"cwd\":\"$TMP/rep-consumer\",\"hook_event_name\":\"SessionStart\"}" \
      | "$HOOK" 2>/dev/null)
case "$out" in
  *"feat is 1 commit(s) behind origin/main"*)
    ok "SessionStart reports how far behind HEAD is" ;;
  *) bad "SessionStart reports how far behind HEAD is" "out=[$out]" ;;
esac

# PreToolUse stdout is transcript noise, not context -- stay quiet there.
mkrepo repq main
git -C "$TMP/repq-consumer" checkout -q -b feat
out=$(printf '%s' "{\"cwd\":\"$TMP/repq-consumer\",\"hook_event_name\":\"PreToolUse\"}" \
      | "$HOOK" 2>/dev/null)
[ -z "$out" ] && ok "stays silent on PreToolUse" \
              || bad "stays silent on PreToolUse" "out=[$out]"

# Nothing to say when the branch already contains origin/main.
mkrepo repu main
git -C "$TMP/repu-consumer" fetch -q origin main
git -C "$TMP/repu-consumer" checkout -q -B feat origin/main
out=$(printf '%s' "{\"cwd\":\"$TMP/repu-consumer\",\"hook_event_name\":\"SessionStart\"}" \
      | "$HOOK" 2>/dev/null)
[ -z "$out" ] && ok "stays silent when HEAD is up to date" \
              || bad "stays silent when HEAD is up to date" "out=[$out]"

echo
[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit $fail
