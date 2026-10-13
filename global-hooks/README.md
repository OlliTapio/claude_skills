# Global Claude Code Hooks

Hooks registered in `~/.claude/settings.json`, so they apply to **every repo on
the machine**. Symlinked from here, so `git pull` updates every machine.

Distinct from [`templates/hooks/`](../templates/hooks/), which are project-level
templates you **copy** into one repo's `.claude/`.

## `fetch-default-branch.sh` — stop working against stale code

### The problem

`worktree.baseRef` controls where a new worktree branches from:

| Value | Branches from |
|---|---|
| `fresh` *(default)* | `origin/<default-branch>` |
| `head` | your current local `HEAD` |

`fresh` sounds like "latest from the remote". It isn't. It resolves
`origin/main` — the **local remote-tracking ref**, a cached pointer that only
moves when something fetches.

Claude Code does fetch during worktree setup, but it skips that fetch when the
branch is already present locally. A ref that exists and is six months old
counts as present. So the "fresh" worktree is only as fresh as your last pull:

```
remote origin/main   ─────●───●───●───●  ← real HEAD, 6 weeks of commits
                     │
local  origin/main   ─────●              ← present, so the fetch is skipped
                          └── your "fresh" worktree starts HERE
```

This bites hardest in repos you touch rarely — exactly the ones where you're
most likely to spin up an agent and least likely to have pulled recently.

There is a second half to this. Even with `origin/main` fresh, agents *inside* a
worktree read the **local** branch: `git log main`, `git diff main...HEAD`,
`git merge main`. A local `main` that only moves when a human remembers to
`pull` is a stale ruler that fresh work gets measured against — which produces
confidently wrong conclusions, not merely old code. A real instance: a local
`main` seven days and 26 commits behind made an agent measure a ~3,900-line
delta and nearly conclude a shipped feature was unmerged.

### The fix

Force the fetch ourselves, immediately before the worktree is cut — then
fast-forward the local default branch too, but only when that is provably
lossless.

The local half is deliberately timid. It moves `refs/heads/<db>` only when:

- the move is **strictly a fast-forward** (local is an ancestor of the new
  `origin/<db>`) — a diverged or rebased local branch is never rewritten;
- and either the branch is **checked out nowhere** (a compare-and-swap
  `update-ref`, no index to desync), **or** it is checked out in a worktree that
  is **clean** (`status --porcelain -uno` empty), has **HEAD actually on that
  branch**, and has **nothing mid-flight** — no `MERGE_HEAD`,
  `CHERRY_PICK_HEAD`, `REVERT_HEAD`, `BISECT_LOG`, `rebase-merge`,
  `rebase-apply`, or `sequencer`.

Any doubt and it silently does nothing. Two approaches were tried and rejected:

| Rejected | Why |
|---|---|
| `git fetch origin "+refs/heads/main:refs/heads/main"` | Refused outright when `main` is checked out in any worktree. |
| `--update-head-ok` / `git update-ref` on a checked-out branch | Moves the ref but leaves that worktree's index behind, staging a deletion of **every file the new commits added**. Data-loss footgun, not a fix. |

Only `merge --ff-only`, run *in* the worktree that holds the branch, moves ref,
index and working tree together. That is what the hook does — the same operation
as the `pull --ff-only` a human would have run.

Set `CLAUDE_HOOK_FF_LOCAL_DEFAULT=0` to disable the local half and keep the
original refs/remotes-only behaviour.

### How it's wired

Three registrations, because three different paths create worktrees:

| Event | Mode | Why |
|---|---|---|
| `PreToolUse` matcher `EnterWorktree` | blocking | The load-bearing one. Runs right before the worktree is created, so `fresh` resolves against a just-updated ref. Must block — an async fetch would race worktree creation and lose. |
| `SubagentStart` | async | Subagents fire this, **not** `SessionStart`, so it's the only place to catch `isolation: "worktree"` agents. Best-effort: it is not established that it runs before the worktree is cut, so treat it as keeping refs warm rather than as a guarantee. |
| `SessionStart` | async | Covers `claude --worktree` at startup and keeps refs warm generally. |

Only the `EnterWorktree` registration is guaranteed to land before the worktree
exists. The other two are opportunistic.

### What the script does

1. Reads the hook's JSON payload from stdin and extracts `cwd` (the project dir).
2. Bails out silently if that isn't a git repo, or has no `origin` remote.
3. Establishes the timeout and no-prompt guards **before** touching the network.
4. Resolves the default branch from cached `origin/HEAD`, falling back to
   `ls-remote --symref`, then to `main` — so `master` repos work too.
5. Fetches **only** that one branch into `refs/remotes/origin/<db>`.
6. Fast-forwards `refs/heads/<db>` if — and only if — every condition above
   holds; otherwise leaves it untouched.
7. Exits `0` no matter what.

### Design constraints

A blocking `PreToolUse` hook sits in your critical path, so it is built to never
make things worse than not having it:

- **Never blocks.** Always exits `0`. Offline, deleted remote, expired
  credentials — you get a stale ref, same as before, never a hard error.
- **Never prompts.** `GIT_TERMINAL_PROMPT=0` and `ssh -oBatchMode=yes` are
  exported *before* the first network call, so a missing credential fails
  instantly instead of blocking on a tty that isn't there.
- **Never destructive.** The local fast-forward is gated on a strict ancestry
  check plus a clean, idle worktree, so there is no state it can overwrite. The
  `update-ref` path passes `<oldvalue>`, making it a compare-and-swap that two
  concurrent runs of this hook cannot race. The `merge --ff-only` is *not*
  `timeout`-wrapped — it is local-only, and a SIGTERM mid-checkout would be
  worse than a slow one.
- **Bounded.** Both network calls are wrapped in `timeout`, budgeted 8s + 15s so
  the worst case stays under the `"timeout": 30` each registration sets, and
  exits cleanly rather than being killed mid-flight. Measured at 23s against a
  blackholed remote. Set that `timeout` on *every* entry — the harness default
  is far higher, so the bound only exists because you configure it.
- **No GNU coreutils assumption.** `timeout` ships on Linux but not stock macOS;
  the script tries `timeout`, then `gtimeout` (`brew install coreutils`). With
  neither, `http.lowSpeed*` and SSH `ConnectTimeout` help but cannot bound a
  blackholed HTTP connect — git has no portable HTTP connect timeout, and
  `http.connectTimeout` is unsupported by Apple git. There the configured 30s is
  the only backstop; measured 150s unbounded without it.
- **SSH options are inserted, not appended.** `ssh` honours the *first*
  occurrence of a repeated `-o`, so appending `-oBatchMode=yes` would silently
  lose to a user who already sets `-oBatchMode=no`.
- **Real JSON parsing.** Uses `python3` when present, falling back to `awk`'s
  first-match. A regex over raw JSON truncates on escaped quotes and can match a
  nested `"cwd"` instead of the top-level one.

### Exit codes

Only `2` blocks a `PreToolUse` call. Any other non-zero is logged but does not
block. This script only ever returns `0` — it is deliberately incapable of
blocking a worktree.

## Install

```bash
mkdir -p ~/.claude/hooks
ln -s "$PWD/global-hooks/fetch-default-branch.sh" ~/.claude/hooks/fetch-default-branch.sh
```

Then merge into `~/.claude/settings.json` (**not** a project `.claude/settings.json`):

```jsonc
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "EnterWorktree",
        "hooks": [{ "type": "command",
                    "command": "/Users/<you>/.claude/hooks/fetch-default-branch.sh",
                    "timeout": 30 }] }
    ],
    "SubagentStart": [
      { "matcher": ".*",
        "hooks": [{ "type": "command",
                    "command": "/Users/<you>/.claude/hooks/fetch-default-branch.sh",
                    "async": true,
                    "timeout": 30 }] }
    ],
    "SessionStart": [
      { "matcher": ".*",
        "hooks": [{ "type": "command",
                    "command": "/Users/<you>/.claude/hooks/fetch-default-branch.sh",
                    "async": true,
                    "timeout": 30 }] }
    ]
  }
}
```

`~` is not expanded in hook commands — use an absolute path. Existing entries
for these events are additive; append rather than replace.

> **Upgrading from an earlier checkout?** This directory used to be `hooks/`.
> Re-point the symlink or it will dangle:
> ```bash
> ln -sfn "$PWD/global-hooks/fetch-default-branch.sh" ~/.claude/hooks/fetch-default-branch.sh
> ```

### Verify

Hooks load at startup, so **restart your session** before testing.

Run the test suite — it builds its own scratch repos, so it's safe anywhere:

```bash
sh global-hooks/test-fetch-default-branch.sh
```

Or dry-run against a real repo:

```bash
echo '{"cwd":"/path/to/repo"}' | ~/.claude/hooks/fetch-default-branch.sh; echo "exit=$?"
```

The dry-run above will also fast-forward that repo's local default branch if it
is clean and behind. To fetch only, prefix `CLAUDE_HOOK_FF_LOCAL_DEFAULT=0`.

Audit which repos are behind their remote (`tip commit` is the age of the
commit, not of your last fetch):

```bash
for d in ~/repositories/*/; do
  ( cd "$d" 2>/dev/null || exit 0
    git rev-parse --git-dir >/dev/null 2>&1 || exit 0
    db=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')
    [ -n "$db" ] || db=main
    ls=$(git rev-parse "origin/$db" 2>/dev/null) || exit 0
    rs=$(git ls-remote origin "refs/heads/$db" 2>/dev/null | cut -f1)
    [ -n "$rs" ] || exit 0
    [ "$rs" = "$ls" ] && s="ok   " || s="STALE"
    # local lag is the one agents actually read (git log main, git merge main)
    lb=$(git rev-parse -q --verify "refs/heads/$db" 2>/dev/null)
    if [ -z "$lb" ]; then l="-"
    elif [ "$lb" = "$ls" ]; then l="0"
    else l=$(git rev-list --count "$lb..origin/$db" 2>/dev/null); fi
    printf '%-32s remote:%s local behind:%-4s tip commit: %s\n' \
      "$(basename "$d")" "$s" "$l" "$(git log -1 --format=%cr "origin/$db")" )
done
```

## Limits

- **Local only.** Cloud sessions (claude.ai/code) don't read your local
  `~/.claude/settings.json`.
- **Not retroactive.** Only affects *newly created* worktrees. To rescue one
  already cut from a stale base: `git fetch origin && git merge origin/main`.
- **Local `main` only, and only when idle.** The one local branch it will ever
  move is the default branch, only ever forward, and never while that worktree
  has uncommitted or mid-flight state — in which case it stays stale until you
  deal with it yourself. No other branch is touched, ever.
- **`origin/HEAD` can itself go stale.** If a repo renames its default branch,
  the cached pointer keeps naming the old one. Fix with
  `git remote set-head origin -a`.
