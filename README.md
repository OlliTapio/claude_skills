# Claude Skills

My personal Claude Code skills. For sharing between computers and colleagues.

## The skills I rely on most

- **`pr`** — pre-PR checklist (tests, lint, types, staged files) and opens the PR
- **`pr-review`** — reviews PRs against project rules; sharp on duplicated code and rule violations
- **`finalize`** — small batch-testable changes end-to-end: PR, self-review, squash merge

## Other skills

- **`plan`** — TDD-flavored planning
- **`test-on-main`** — switch from worktree to main, merge, run tests
- **`frontend-design`** — production-grade frontend output
- **`codex-pr-review`** — `pr-review` retuned for Codex

## Hooks

`hooks/` — user-global hooks, symlinked into `~/.claude/` so they apply to every repo on the machine.

- **`fetch-default-branch.sh`** — fetches `origin/<default-branch>` before Claude Code cuts a worktree, so `baseRef: fresh` actually means fresh. Without it, new worktrees start from however stale your last `git fetch` was.

## Templates

`templates/hooks/` — drop-in *project-level* Claude Code hooks (`precommit.sh`, `lint-fix.sh`) that enforce quality gates at the harness level. Copied into a single repo, unlike `hooks/` above.

## Install

Symlink a skill into your Claude Code skills directory:

```bash
ln -s "$PWD/skills/pr" ~/.claude/skills/pr
```

Global hooks are symlinked the same way, plus a `~/.claude/settings.json` entry — see [`hooks/README.md`](hooks/README.md):

```bash
mkdir -p ~/.claude/hooks
ln -s "$PWD/hooks/fetch-default-branch.sh" ~/.claude/hooks/fetch-default-branch.sh
```
