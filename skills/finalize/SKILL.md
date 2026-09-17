---
name: finalize
description: Create a PR, review it, fix issues, and auto-merge squash. Use when the user wants to ship changes end-to-end in one command — covers PR creation, self-review, fixes, and squash merge.
---

# Finalize

Create PR → review → fix → squash merge.

## Step 0: Drop stray files

List the files the branch adds against the default branch. Remove anything that must not ship — dependency dirs (`node_modules/`, `vendor/`, `.venv/`), build output (`dist/`, `build/`, `*.pyc`), local scratch (`tmp*`, `scratch*`, `*.log`, ad-hoc run scripts), editor/OS junk (`.DS_Store`, `.idea/`), env and credential files — with `git rm --cached` plus a `.gitignore` entry. Ask before removing anything whose purpose is unclear.

## Step 1: Create PR

Run the `pr` skill. Skip asking for reviewers.

## Step 2: Review PR

Run the `pr-review` skill on the created PR.

## Step 3: Fix and re-review

If P0/P1 issues found: fix them, run quality checks, commit, push, re-review. Max 3 iterations. P2s are non-blocking — proceed.

## Step 4: Wait for CI

```bash
gh pr checks --watch --fail-fast
```

If CI fails, fix and retry. Max 3 attempts.

## Step 5: Squash merge

```bash
PR_NUMBER=$(gh pr view --json number -q .number)
PR_TITLE=$(gh pr view --json title -q .title)
gh pr merge "$PR_NUMBER" --squash --subject "$PR_TITLE" --delete-branch
```

Report the merged PR URL.
