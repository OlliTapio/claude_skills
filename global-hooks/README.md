# Global Claude Code Hooks

Hooks registered in `~/.claude/settings.json`, so they apply to **every repo on
the machine**. Symlinked from here, so `git pull` updates every machine.

Distinct from [`templates/hooks/`](../templates/hooks/), which are project-level
templates you **copy** into one repo's `.claude/`.

## `fetch-default-branch.sh` — stop starting worktrees from stale code

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

### The fix

Force the fetch ourselves, immediately before the worktree is cut.

### How it's wired

Three registrations, because three different paths create worktrees:

| Event | Mode | Why |
|---|---|---|
| `PreToolUse` matcher `EnterWorktree` | blocking, 30s | Runs right before the worktree is created. Must block — an async fetch would race worktree creation and lose. |
| `SubagentStart` | async | Subagents launched with `isolation: "worktree"` fire this, **not** `SessionStart`. Without it, agent-isolated worktrees get no fetch. |
| `SessionStart` | async | Covers `claude --worktree` at startup, and keeps refs warm generally. |

### What the script does

1. Reads the hook's JSON payload from stdin and extracts `cwd` (the project dir).
2. Bails out silently if that isn't a git repo, or has no `origin` remote.
3. Establishes the timeout and no-prompt guards **before** touching the network.
4. Resolves the default branch from cached `origin/HEAD`, falling back to
   `ls-remote --symref`, then to `main` — so `master` repos work too.
5. Fetches **only** that one branch.
6. Exits `0` no matter what.

### Design constraints

A blocking `PreToolUse` hook sits in your critical path, so it is built to never
make things worse than not having it:

- **Never blocks.** Always exits `0`. Offline, deleted remote, expired
  credentials — you get a stale ref, same as before, never a hard error.
- **Never prompts.** `GIT_TERMINAL_PROMPT=0` and `ssh -oBatchMode=yes` are
  exported *before* the first network call, so a missing credential fails
  instantly instead of blocking on a tty that isn't there.
- **Bounded.** Both network calls are wrapped in `timeout`, budgeted 8s + 15s so
  the worst case stays under Claude Code's 30s hook timeout and exits cleanly
  rather than being killed. Measured at 24s against a blackholed remote.
- **No GNU coreutils assumption.** `timeout` ships on Linux but not stock macOS;
  the script tries `timeout`, then `gtimeout` (`brew install coreutils`). With
  neither, `http.lowSpeed*` and SSH `ConnectTimeout` help but cannot bound a
  blackholed HTTP connect — git has no portable HTTP connect timeout, and
  `http.connectTimeout` is unsupported by Apple git. There, Claude Code's 30s
  hook timeout is the backstop.
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
                    "async": true }] }
    ],
    "SessionStart": [
      { "matcher": ".*",
        "hooks": [{ "type": "command",
                    "command": "/Users/<you>/.claude/hooks/fetch-default-branch.sh",
                    "async": true }] }
    ]
  }
}
```

`~` is not expanded in hook commands — use an absolute path. Existing entries
for these events are additive; append rather than replace.

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
    printf '%-32s %s  tip commit: %s\n' "$(basename "$d")" "$s" "$(git log -1 --format=%cr "origin/$db")" )
done
```

## Limits

- **Local only.** Cloud sessions (claude.ai/code) don't read your local
  `~/.claude/settings.json`.
- **Not retroactive.** Only affects *newly created* worktrees. To rescue one
  already cut from a stale base: `git fetch origin && git merge origin/main`.
- **Remote-tracking refs only.** Your local branches and working tree are never
  modified.
- **`origin/HEAD` can itself go stale.** If a repo renames its default branch,
  the cached pointer keeps naming the old one. Fix with
  `git remote set-head origin -a`.
