#!/bin/sh
# Refresh origin/<default-branch> before Claude Code cuts a new worktree.
#
# Claude Code's `worktree.baseRef` defaults to `fresh`, which branches from
# origin/<default-branch>. That is the *local remote-tracking ref*. Claude Code
# skips fetching when the branch is already present locally, so a ref that
# exists but is months old is used as-is -- new worktrees silently start from
# however stale your last pull was.
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

# Always succeed: a failed fetch (offline, deleted remote, expired auth) must
# not stop the worktree from being created. Worst case, you get the same stale
# ref you would have had without this hook.
exit 0
