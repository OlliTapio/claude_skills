---
name: test-on-main
description: Switch from a worktree to the main worktree with the in-progress branch, merge main, and run tests. Use when asked to "test on main worktree" or "switch to main worktree and test".
---

# Test on Main Worktree

Exit worktree → checkout branch on main worktree → merge main → run tests.

## Step 1: Exit worktree

Note the current branch name. If in a worktree, use `ExitWorktree` with `action: "keep"`. If not in a worktree, skip.

## Step 2: Checkout branch and merge main

```bash
git checkout <branch-name>
git fetch origin
DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
git merge "origin/$DEFAULT_BRANCH" -m "Merge $DEFAULT_BRANCH into $(git branch --show-current)"
```

If merge conflicts occur, stop and inform the user.

## Step 3: Run tests

Run the project's quality checks (Makefile targets, package.json scripts, etc.). Report results.
