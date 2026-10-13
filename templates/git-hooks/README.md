# Git hook templates (quality gates)

Versioned git hooks that run outside Claude too. Two tiers:

- **pre-commit** — fast, staged files only: format, lint, complexity, duplication.
- **pre-push** — slow, whole repo: types, tests, dead-code, whole-repo duplication.

## Install

```bash
mkdir -p .githooks
cp pre-commit pre-push .githooks/
chmod +x .githooks/*
git config core.hooksPath .githooks   # checked-in, shared by everyone who clones
```

## Configure

Both scripts auto-detect TS/JS (`package.json`) and Python (`pyproject.toml`) and
call the repo's own scripts (`lint`, `fmt:check`, `tsc`, `test`, `lint:exports`).
Edit the command blocks to match your tools, and add a block per additional language.

Turn the smell-catchers on explicitly — they are usually off by default:
- **complexity**: linter cyclomatic/cognitive rule (oxlint `complexity`, ruff `C901`), threshold ~10.
- **duplication**: `jscpd` (language-agnostic, wired in pre-push).
- **dead code**: `knip` (TS), `vulture`/ruff `F401` (Python).

## Baseline

Enabling complexity/duplication on an existing repo surfaces many pre-existing hits.
Set a threshold or fix-then-enforce so the gate never always-fails. Bypass in
emergencies with `git commit --no-verify` / `git push --no-verify`.

See the `quality-gates` skill for the full setup flow.
