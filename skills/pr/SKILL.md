---
name: pr
description: Create a pull request with full quality checks. Use when asked to create a PR, submit changes for review, or prepare code for merging. Runs tests, linting, type checking, analyzes async/blocking code, identifies performance bottlenecks, commits with concise messages, creates PR with bullet summary, and asks for reviewers.
---

# Pull Request Creation Skill

Create a pull request with comprehensive quality checks and analysis.

## When to Use

Use this skill when:
- User asks to create a PR
- User asks to submit changes for review
- User asks to prepare code for merging
- Code is ready to be reviewed and merged

## Process

Follow these steps in order:

### Step 1: Merge master into current branch

Before analyzing changes, ensure the branch is up to date with master:

```bash
git fetch origin master:master
git merge master -m "Merge master into $(git branch --show-current)"
```

If there are merge conflicts:
- Stop and inform the user about conflicts
- Ask the user to resolve conflicts before continuing
- Do not proceed with the PR creation

### Step 2: Run quality checks

Run the following checks in parallel using `make check`:

```bash
make check
```

This runs:
- `make lint` - Code linting
- `make fmt` - Code formatting
- `make mypy` - Type checking
- `make test` - Unit tests

If any checks fail:
- Show the user the failures
- Ask if they want to proceed anyway or fix issues first

### Step 3: Analyze the changes

Compare the current branch with master (NOT with HEAD~1 or recent commits):

```bash
# Get list of changed files
git diff master...HEAD --name-only

# Get the full diff for analysis
git diff master...HEAD

# Get commit history since branching from master
git log master..HEAD --oneline
```

Analyze:
- What files changed
- What functionality was added/modified/removed
- Any async/await patterns (note if blocking operations are in async functions)
- Any potential performance issues
- Code complexity changes

### Step 3b: Review against project code review guidelines

Read `docs/review.md` and check the diff against every guideline listed there. If any violations are found:
- List each violation with the file path and line number
- Fix them before proceeding
- If a fix is ambiguous, ask the user

### Step 3c: Verify PR contains only relevant changes

Review the diff and check that changes relate to the feature/fix being worked on. Small incidental fixes are acceptable. Flag **unrelated features or significant unrelated work** that should be in a separate PR. If found, ask the user whether to keep or split them out.

### Step 4: Create commit (if needed)

If there are uncommitted changes:

```bash
git add .
git commit -m "Brief description of changes

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Step 5: Push to remote

```bash
git push -u origin $(git branch --show-current)
```

### Step 6: Create PR with comprehensive summary

Create the PR using `gh pr create`. The PR body should include:

**Summary section:**
- Brief overview of changes (2-3 sentences)
- Key files modified
- Any breaking changes

**Changes section:**
- Bullet list of specific changes
- Reference file paths with line numbers when relevant

**Technical notes section (if applicable):**
- Async/blocking analysis findings
- Performance considerations
- Architectural decisions

**Test plan:**
- What was tested
- What should reviewers test

Use this command:

```bash
gh pr create --base master --title "Descriptive PR title" --body "$(cat <<'EOF'
## Summary
[Summary here]

## Changes
- [Change 1]
- [Change 2]

## Technical notes
- [Note 1]
- [Note 2]

## Test plan
- [Test item 1]
- [Test item 2]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Step 7: Ask for reviewers

Ask the user: "Who should review this PR?"

Then add reviewers:

```bash
gh pr edit --add-reviewer username1,username2
```

## Important Notes

- **Always compare with master**, not with HEAD or recent commits
- **Always merge master first** to ensure the branch is up to date
- Run all checks even if some fail (to show all issues at once)
- Be concise but thorough in PR descriptions
- Include technical analysis in PR body
- Focus on the "why" not just the "what"
- Reference specific files and line numbers where relevant
