# Global Claude Code Hooks

User-global hooks — they live in `~/.claude/settings.json` and apply to **every
repo on the machine**, including repos that don't exist yet.

> Not to be confused with [`templates/hooks/`](../templates/hooks/), which are
> *project-level* templates you **copy** into a single repo's `.claude/`.
> These are global and **symlinked**, so a `git pull` here updates every machine.

## `fetch-default-branch.sh` — stop starting worktrees from stale code

### The problem

Claude Code's `worktree.baseRef` setting has two values:

| Value | Branches from |
|---|---|
| `fresh` *(default)* | `origin/<default-branch>` |
| `head` | your current local `HEAD` |

`fresh` sounds like it means "latest from the remote". It doesn't. It branches
from `origin/main` — the **local remote-tracking ref**, a cached pointer that
only moves when you run `git fetch` or `git pull`.

Nothing in Claude Code fetches on its own. So the "fresh" worktree is only as
fresh as the last time *you* happened to pull in that repo:

```
remote origin/main   ─────●───●───●───●  ← real HEAD, 6 weeks of commits
                     │
local  origin/main   ─────●              ← last fetched 6 weeks ago
                          └── your "fresh" worktree starts HERE
```

This bites hardest in repos you touch rarely — exactly the ones where you're
most likely to spin up an agent and least likely to have pulled recently.

### The fix

Fetch the default branch immediately before the worktree is cut.

### How it's wired

Two registrations, doing different jobs:

| Event | Mode | Why |
|---|---|---|
| `PreToolUse` matcher `EnterWorktree` | blocking, 30s timeout | Runs right before the worktree is created, so `fresh` resolves against a just-updated ref. Must block — an async fetch would race the worktree creation and lose. |
| `SessionStart` | async | Catches the paths that never call `EnterWorktree` — notably subagents launched with `isolation: "worktree"`. Async because nothing is waiting on it. |

### What the script does

1. Reads the hook's JSON payload from stdin and pulls out `cwd` (the project dir).
2. Bails out silently if that isn't a git repo, or has no `origin` remote.
3. Resolves the default branch from cached `origin/HEAD`, falling back to asking
   the remote, then to `main` — so `master`-based repos work too.
4. Fetches **only** that one branch, not every ref, to stay fast.
5. Exits `0` no matter what.

### Design constraints

A blocking `PreToolUse` hook sits directly in your critical path, so the script
is built to never make things worse than not having it:

- **Never blocks.** Always exits `0`. Offline, deleted remote, expired
  credentials — you get a stale ref, same as before the hook, never a hard error.
- **Never hangs.** `GIT_TERMINAL_PROMPT=0` and `ssh -oBatchMode=yes` turn
  credential prompts into instant failures instead of a hung terminal.
- **Never assumes GNU coreutils.** `timeout` ships on Linux but not stock macOS;
  the script tries `timeout`, then `gtimeout` (`brew install coreutils`), then
  runs bare.

### Exit code reference

| Code | Effect |
|---|---|
| `0` | Success, continue |
| `2` | **Blocks** the tool call (`PreToolUse` only) |
| other | Logged as an error, does *not* block |

This script only ever returns `0`. It is deliberately incapable of blocking a
worktree.

## Install

Symlink into your global hooks directory, then register the events:

```bash
mkdir -p ~/.claude/hooks
ln -s "$PWD/hooks/fetch-default-branch.sh" ~/.claude/hooks/fetch-default-branch.sh
```

Merge into `~/.claude/settings.json` (**not** a project `.claude/settings.json` —
these are global):

```jsonc
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "EnterWorktree",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/<you>/.claude/hooks/fetch-default-branch.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/<you>/.claude/hooks/fetch-default-branch.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
```

`~` is not expanded in hook commands — use an absolute path. Existing entries
for these events are additive; append rather than replace.

### Verify

Hooks load at startup, so **restart your session** before testing.

Dry-run the script directly against a repo:

```bash
echo '{"cwd":"/path/to/repo"}' | ~/.claude/hooks/fetch-default-branch.sh; echo "exit=$?"
```

Audit which repos are currently behind their remote:

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
    printf '%-32s %s  last fetched: %s\n' "$(basename "$d")" "$s" "$(git log -1 --format=%cr "origin/$db")" )
done
```

## Limits

- **Local only.** Cloud sessions (claude.ai/code) don't read your local
  `~/.claude/settings.json`.
- **Not retroactive.** Only affects *newly created* worktrees. To rescue one
  already cut from a stale base: `git fetch origin && git merge origin/main`.
- **Doesn't touch your local `main`.** It updates the remote-tracking ref only.
  Your checked-out branches are never modified.
