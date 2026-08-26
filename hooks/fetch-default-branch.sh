#!/bin/sh
# Refresh origin/<default-branch> before Claude Code cuts a new worktree.
#
# Claude Code's `worktree.baseRef` defaults to `fresh`, which branches from
# origin/<default-branch>. That is the *local remote-tracking ref*, not the
# actual remote -- so it is only as current as your last `git fetch`. Without
# this hook, new worktrees silently start from however stale your last pull was.
#
# Wired up as PreToolUse(EnterWorktree) + SessionStart. See hooks/README.md.
#
# Contract: never block, never hang, never prompt. Always exits 0.

# Claude Code passes hook context as JSON on stdin; `cwd` is the project dir.
input=$(cat 2>/dev/null)
dir=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$dir" ] || dir=$PWD

cd "$dir" 2>/dev/null || exit 0

# Nothing to do outside a git repo, or in a repo with no origin remote.
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0

# Resolve the default branch: cached origin/HEAD first (cheap, offline), then
# ask the remote, then fall back to main. Handles master-based repos too.
db=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
[ -n "$db" ] || db=$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p')
[ -n "$db" ] || db=main

# A blocking PreToolUse hook must never sit waiting on a credential prompt.
GIT_TERMINAL_PROMPT=0
GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -oBatchMode=yes}"
export GIT_TERMINAL_PROMPT GIT_SSH_COMMAND

# `timeout` is GNU coreutils: present on Linux, absent on stock macOS,
# available as `gtimeout` via `brew install coreutils`. Degrade gracefully.
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT="timeout 25"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT="gtimeout 25"
else
  TIMEOUT=""
fi

# Fetch only the default branch -- not every ref -- to keep this fast.
$TIMEOUT git fetch --quiet --prune origin \
  "+refs/heads/$db:refs/remotes/origin/$db" 2>/dev/null

# Always succeed: a failed fetch (offline, deleted remote, expired auth) must
# not stop the worktree from being created. Worst case, you get today's stale
# ref instead of a hard error.
exit 0
