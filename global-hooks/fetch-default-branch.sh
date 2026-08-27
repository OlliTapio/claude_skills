#!/bin/sh
# Refresh origin/<default-branch> -- and fast-forward the local branch -- before
# Claude Code cuts a new worktree.
#
# Claude Code's `worktree.baseRef` defaults to `fresh`, which branches from
# origin/<default-branch>. That is the *local remote-tracking ref*. Claude Code
# skips fetching when the branch is already present locally, so a ref that
# exists but is months old is used as-is -- new worktrees silently start from
# however stale your last pull was.
#
# The local branch matters too: agents inside a worktree run `git log main`,
# `git diff main...HEAD`, `git merge main`. So this also fast-forwards
# refs/heads/<default-branch>, but only when that is provably lossless --
# strictly a fast-forward, and via `merge --ff-only` in the worktree that holds
# it so ref, index and working tree move together. Anything uncommitted or
# mid-flight there, or any divergence, and it is left exactly as it was.
#
# Wired up as PreToolUse(EnterWorktree) + SessionStart + SubagentStart.
# See global-hooks/README.md.
#
# Contract: never block, never hang, never prompt. Always exits 0.

# Claude Code passes hook context as JSON on stdin; `cwd` is the project dir.
input=$(cat 2>/dev/null)

# Prefer a real JSON parser: the payload may contain escaped quotes or unicode
# escapes in the path, which a regex would truncate silently.
dir=$(printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("cwd","") or "")
except Exception: pass' 2>/dev/null)

# Fallback if python3 is unavailable. awk match() takes the FIRST occurrence,
# so a nested "cwd" in tool_input can never shadow the top-level one.
if [ -z "$dir" ]; then
  dir=$(printf '%s' "$input" | awk '
    match($0, /"cwd"[[:space:]]*:[[:space:]]*"[^"]*"/) {
      s = substr($0, RSTART, RLENGTH)
      sub(/^"cwd"[[:space:]]*:[[:space:]]*"/, "", s)
      sub(/"$/, "", s)
      print s; exit
    }')
fi

[ -n "$dir" ] || dir=$PWD
cd "$dir" 2>/dev/null || exit 0

# Nothing to do outside a git repo, or in a repo with no origin remote.
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0

# --- Guards must be established BEFORE any command that touches the network. -

# A blocking PreToolUse hook must never sit waiting on a credential prompt.
#
# ssh honours the FIRST occurrence of a repeated -o, so these must be INSERTED
# after the command word, not appended -- appending would silently lose to a
# user who already sets -oBatchMode=no. Everything the user wrote is preserved,
# it just no longer overrides the two options we require.
GIT_TERMINAL_PROMPT=0
if [ -n "${GIT_SSH_COMMAND:-}" ]; then
  _cmd=${GIT_SSH_COMMAND%% *}
  _rest=${GIT_SSH_COMMAND#"$_cmd"}
  GIT_SSH_COMMAND="$_cmd -oBatchMode=yes -oConnectTimeout=5$_rest"
else
  GIT_SSH_COMMAND="ssh -oBatchMode=yes -oConnectTimeout=5"
fi
export GIT_TERMINAL_PROMPT GIT_SSH_COMMAND

# `timeout` is GNU coreutils: present on Linux, absent on stock macOS,
# available as `gtimeout` via `brew install coreutils`. Degrade gracefully.
#
# Budget matters: this script can make two network calls, and every
# registration sets `"timeout": 30` (the harness default is far higher, so the
# bound only exists because we configure it). 8 + 15 keeps the worst case under
# that, so we fail fast and exit cleanly rather than being cut off mid-flight.
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN=gtimeout
else
  TIMEOUT_BIN=""
fi
if [ -n "$TIMEOUT_BIN" ]; then
  T_LOOKUP="$TIMEOUT_BIN 8"
  T_FETCH="$TIMEOUT_BIN 15"
else
  T_LOOKUP=""
  T_FETCH=""
fi

# Partial transport-level bounds, used in addition to the wrappers above.
# These help but do not replace them: http.lowSpeed* only applies once a
# connection is established, and git has no portable HTTP connect timeout
# (http.connectTimeout is unsupported by Apple git). Against a blackholed host
# the `timeout` wrapper is what actually bounds us; with no `timeout` binary at
# all, the configured 30s hook timeout is the only backstop.
GIT="git -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=10"

# Resolve the default branch. Cached origin/HEAD first -- free and offline.
db=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')

# Not every clone has origin/HEAD (git init + remote add, --single-branch, old
# clones), so fall back to asking the remote -- bounded and prompt-free now.
# ls-remote --symref is far cheaper than `git remote show`, which enumerates
# every branch.
if [ -z "$db" ]; then
  # shellcheck disable=SC2086  # word splitting of $T_LOOKUP/$GIT is intended
  db=$($T_LOOKUP $GIT ls-remote --symref origin HEAD 2>/dev/null \
       | sed -n 's|^ref: refs/heads/\([^[:space:]]*\)[[:space:]]*HEAD$|\1|p')
fi

[ -n "$db" ] || db=main

# Fetch only that one branch, not every ref, to stay fast. No --prune: with an
# explicit refspec it cannot clean up other stale refs anyway, and it would
# delete this very ref if the branch were renamed upstream.
# shellcheck disable=SC2086  # word splitting of $T_FETCH/$GIT is intended
$T_FETCH $GIT fetch --quiet origin \
  "+refs/heads/$db:refs/remotes/origin/$db" 2>/dev/null

# --- Fast-forward the LOCAL default branch too -------------------------------
#
# Refreshing origin/<db> fixes `worktree.baseRef: fresh`, but agents inside a
# worktree read the *local* branch: `git log main`, `git diff main...HEAD`,
# `git merge main`. A local main that only moves when you remember to pull is a
# week-old ruler that agents measure fresh work against -- it produces bogus
# "unmerged feature" diffs, not just staleness.
#
# So: advance refs/heads/<db> as well, under strict conditions. Set
# CLAUDE_HOOK_FF_LOCAL_DEFAULT=0 to disable and keep refs/remotes/* only.
[ "${CLAUDE_HOOK_FF_LOCAL_DEFAULT:-1}" = "0" ] && exit 0

remote_sha=$(git rev-parse -q --verify "refs/remotes/origin/$db" 2>/dev/null)
local_sha=$(git rev-parse -q --verify "refs/heads/$db" 2>/dev/null)

# No remote-tracking ref (fetch failed, offline) or no local branch at all:
# nothing to advance. We never *create* the branch -- `fresh` worktrees come
# off origin/<db>, so its absence is not a problem to solve here.
[ -n "$remote_sha" ] && [ -n "$local_sha" ] || exit 0
[ "$remote_sha" = "$local_sha" ] && exit 0

# Fast-forward ONLY. If local has commits the remote lacks, it has diverged
# (or been rebased) and moving it would silently discard work. Leave it.
git merge-base --is-ancestor "$local_sha" "$remote_sha" 2>/dev/null || exit 0

# Which worktree, if any, has this branch checked out. `git worktree list` is
# repo-wide, so it sees the primary checkout even when we are inside a worktree.
wt=$(git worktree list --porcelain 2>/dev/null | awk -v ref="refs/heads/$db" '
  /^worktree / { w = substr($0, 10) }
  /^branch /   { if (substr($0, 8) == ref) { print w; exit } }')

# Checked out nowhere: a bare ref move is enough, and there is no index or
# working tree that could fall out of sync with it. Passing <oldvalue> makes
# this a compare-and-swap, so a concurrent run of this hook cannot clobber.
if [ -z "$wt" ]; then
  git update-ref -m "fetch-default-branch: ff to origin/$db" \
    "refs/heads/$db" "$remote_sha" "$local_sha" 2>/dev/null
  exit 0
fi

# Checked out somewhere. `update-ref` / `fetch --update-head-ok` would move the
# ref and leave that worktree's index behind, staging a deletion of every file
# the new commits added -- a data-loss footgun, not a fix. Only `merge --ff-only`
# updates ref, index and working tree together, so run it *in* that worktree,
# and only when there is provably nothing there to lose.
[ -d "$wt" ] || exit 0

# Anything mid-flight (merge, rebase, cherry-pick, revert, bisect) means a human
# or another agent is holding state in that worktree. Hard stop.
gd=$(git -C "$wt" rev-parse --absolute-git-dir 2>/dev/null) || exit 0
for f in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG \
         rebase-merge rebase-apply sequencer; do
  [ -e "$gd/$f" ] && exit 0
done

# HEAD must actually be on the branch (not detached at the same commit), and the
# tree must be clean. Untracked files are ignored -- ff-only refuses on its own
# if an incoming file would overwrite one, and we exit 0 on that anyway.
[ "$(git -C "$wt" symbolic-ref -q --short HEAD 2>/dev/null)" = "$db" ] || exit 0
[ -z "$(git -C "$wt" status --porcelain --untracked-files=no 2>/dev/null)" ] || exit 0

# Not wrapped in `timeout`: this is local-only, and a SIGTERM mid-checkout is
# worse than a slow one. Its failure modes are all no-ops.
git -C "$wt" merge --ff-only --quiet "$remote_sha" 2>/dev/null

# Always succeed: a failed fetch (offline, deleted remote, expired auth) or a
# skipped fast-forward must not stop the worktree from being created. Worst case,
# you get the same stale refs you would have had without this hook.
exit 0
