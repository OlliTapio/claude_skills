---
name: pr
description: Create a pull request with full quality checks. Use when asked to create a PR, submit changes for review, or prepare code for merging. Runs tests, linting, type checking, analyzes async/blocking code, identifies performance bottlenecks, commits with concise messages, creates PR with bullet summary, and asks for reviewers.
---

# Pull Request Creation Skill

Create a pull request with comprehensive quality checks and analysis.

## Process

### Step 1: Merge default branch into current branch

Detect the default branch and merge:

```bash
git fetch origin
DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
git merge "origin/$DEFAULT_BRANCH" -m "Merge $DEFAULT_BRANCH into $(git branch --show-current)"
```

If merge conflicts occur, stop and inform the user. Do not proceed.

### Step 2: Run quality checks

Discover and run the project's quality checks. Look for:
- `Makefile` targets (`make check`, `make lint`, `make test`)
- `package.json` scripts (`npm test`, `npm run lint`)
- CI config (`.github/workflows/`) to determine what CI runs
- Language-specific tools (`pytest`, `cargo test`, `go test ./...`)

Run all checks even if some fail, to surface all issues at once. If any fail, show failures and ask user whether to proceed or fix first.

### Step 3: Analyze changes against default branch

```bash
git diff "origin/$DEFAULT_BRANCH"...HEAD --name-only
git diff "origin/$DEFAULT_BRANCH"...HEAD
git log "origin/$DEFAULT_BRANCH"..HEAD --oneline
```

Analyze: what changed, async/blocking patterns, potential performance issues, code complexity.

### Step 3b: Review against project guidelines

If `docs/review.md` exists, check the diff against every guideline. Fix violations before proceeding; ask the user if a fix is ambiguous.

### Step 3c: Verify only relevant changes

Flag unrelated features or significant unrelated work that should be in a separate PR. Small incidental fixes are acceptable.

### Step 4: Commit if needed

If there are uncommitted changes, stage specific files (not `git add .`) and commit:

```bash
git add <specific-files>
git commit -m "Brief description

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Step 5: Push to remote

```bash
git push -u origin "$(git branch --show-current)"
```

### Step 6: Create PR

```bash
gh pr create --base "$DEFAULT_BRANCH" --title "Descriptive PR title" --body "$(cat <<'EOF'
## Summary
[2-3 sentences, key files, breaking changes]

## Changes
- [Change 1]
- [Change 2]

## Technical notes
- [Async/performance/architecture findings, if any]

## Test plan
- [What was tested, what reviewers should test]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Step 7: Ask for reviewers

Ask the user who should review, then add them:

```bash
gh pr edit --add-reviewer username1,username2
```

## Important Notes

- **Always compare with default branch**, not HEAD or recent commits
- **Always merge default branch first** to ensure the branch is up to date
- Be concise but thorough in PR descriptions — focus on "why" not just "what"
