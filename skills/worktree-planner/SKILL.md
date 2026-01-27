---
name: worktree-planner
description: Plan and implement changes in an isolated git worktree. Use this skill when implementing multi-file changes, significant features, or refactoring that would benefit from isolation. Triggers when the task involves (1) changes spanning 3+ files, (2) new features requiring multiple components, (3) refactoring or architectural changes, or (4) user explicitly requests isolated implementation.
---

# Worktree Planner

Implement changes safely by planning first, then working in an isolated git worktree.

## Workflow

### 1. Assess if Worktree Approach Fits

Suggest this approach when:
- Task touches 3+ files
- Adding a new feature with multiple components
- Refactoring or significant changes
- User wants to preserve current working state

Skip for: single-file changes, quick fixes, documentation-only changes.

### 2. Create the Plan

Write a `PLAN.md` file in the repo root with:

```markdown
# Implementation Plan: [Brief Title]

## Summary
[1-2 sentence description of what will be implemented]

## Changes

### [Component/Area 1]
- [ ] Change description
- [ ] Change description

### [Component/Area 2]
- [ ] Change description

## Files to Modify
- `path/to/file1.py` - [brief reason]
- `path/to/file2.ts` - [brief reason]

## New Files
- `path/to/new_file.py` - [purpose]

## Testing Strategy
- [How to verify the changes work]
```

### 3. Get User Approval

After writing PLAN.md, ask user to review before proceeding.

### 4. Create Worktree

Generate branch name from task (e.g., `feat/add-user-auth`, `refactor/simplify-api`).

```bash
# Create worktree in sibling .worktrees directory
BRANCH="feat/descriptive-name"
REPO_NAME=$(basename $(git rev-parse --show-toplevel))
WORKTREE_PATH="../.worktrees/${REPO_NAME}--${BRANCH}"

mkdir -p ../.worktrees
git worktree add -b "$BRANCH" "$WORKTREE_PATH"
```

### 5. Implement in Worktree

Change working directory to the worktree path and implement the plan:

```bash
cd "$WORKTREE_PATH"
```

Work through PLAN.md items, checking off as completed. Commit frequently with clear messages.

### 6. Create Draft PR

When implementation is complete:

1. Commit all changes in worktree
2. Push branch to remote
3. Create draft PR with summary from PLAN.md

```bash
git push -u origin "$BRANCH"

gh pr create --draft --title "feat: [description]" --body "$(cat <<'EOF'
## Summary
[From PLAN.md summary]

## Changes
- [Key changes as bullet points]

## Testing
- [ ] [Testing checklist from plan]

---
🤖 Generated with [Claude Code](https://claude.ai/code)
EOF
)"
```

4. Report to user: PR URL, branch name, worktree path

User can then review the PR on GitHub and:
```bash
# Clean up worktree after merging
git worktree remove <worktree-path>
```

## Branch Naming

Generate from task description:
- Feature: `feat/short-description`
- Fix: `fix/issue-description`
- Refactor: `refactor/what-is-changing`
- Docs: `docs/what-documenting`

Keep names lowercase, use hyphens, max 50 chars.
