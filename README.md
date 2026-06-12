# Claude Skills

A personal toolkit of [Claude Code](https://claude.com/claude-code) skills I use daily to ship software faster and with fewer mistakes. Shared here so other people — and other machines — can pick up the same workflow.

**Status:** in active daily use as of June 2026. Commits are sparse because the skills are stable, not abandoned.

## What's a "skill"?

A skill is a small, named bundle of instructions an LLM agent can invoke on demand — think of it as a reusable prompt with a clear job. The skills here are authored as plain Markdown (`SKILL.md`) so they're portable: the same definitions work across Claude Code today and translate cleanly to other LLM providers tomorrow.

## The skills I rely on most

### `pr` — never ship a half-finished PR
Wraps the whole pre-PR checklist: runs tests, lint, and type checks, confirms every intended file is staged, writes a concise commit message, opens the PR with a bullet summary, and asks for reviewers. Solves the "I forgot to add the migration file" class of mistake.

### `pr-review` — a second pair of eyes that actually reads the rules
Reviews an open PR against the project's own guidelines (CLAUDE.md, conventions, architectural rules) and surfaces severity-ranked findings. Particularly sharp at catching **duplicated code** and **project-rule violations** that human reviewers tend to miss on a Friday afternoon.

### `finalize` — ship small changes end-to-end
For batch-testable changes that don't need a human gate: creates the PR, self-reviews, applies fixes, and squash-merges. Keeps small chores from accumulating into context-switching tax.

## Other skills in the repo

- **`plan`** — TDD-flavored planning for non-trivial work
- **`test-on-main`** — switch from a worktree to main, merge, run the full suite
- **`frontend-design`** — production-grade frontend output that avoids generic AI aesthetics
- **`codex-pr-review`** — `pr-review` retuned for the Codex runtime

## Templates

`templates/hooks/` contains drop-in Claude Code hooks (`precommit.sh`, `lint-fix.sh`) that enforce quality gates at the harness level — the agent literally cannot commit broken code. Copy into any project's `.claude/` directory.

## Installing a skill

Each skill is a folder under `skills/`. To use one, symlink it into your Claude Code skills directory:

```bash
ln -s "$PWD/skills/pr" ~/.claude/skills/pr
```

That's it — Claude Code picks it up on next launch.

## Why this exists

Most "AI tips" online are screenshots. This repo is the actual configuration I run against client work and personal projects every day. If you're a hiring manager or fellow engineer curious about how I shape my tooling, this is the real artifact — flaws and all.

More context on otl.fi → [Blog](https://otl.fi/blog/).
