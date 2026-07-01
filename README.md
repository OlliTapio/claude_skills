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

## Templates

`templates/hooks/` — drop-in Claude Code hooks (`precommit.sh`, `lint-fix.sh`) that enforce quality gates at the harness level.

## Install

Symlink a skill into your Claude Code skills directory:

```bash
ln -s "$PWD/skills/pr" ~/.claude/skills/pr
```
