---
name: plan
description: Plan features, fixes, or chores with TDD approach. Creates a clean branch, assesses change type (feat/fix/chore), analyzes architecture, and produces a plan with tests written first. Use when starting any non-trivial work.
---

> **⚠️ WIP / BETA** - This skill is under development and not fully tested. Workflow may change.

# Plan

Structured planning workflow using Test-Driven Development. Creates a branch, understands architecture, and produces a plan where tests are written before implementation.

## Why TDD for LLM Implementation

TDD is ideal for LLM-driven development:

1. **Tests define behavior** - Clear specification before coding
2. **Immediate verification** - LLM can run tests to validate its work
3. **Prevents over-engineering** - Write minimal code to pass tests
4. **Edge cases upfront** - Forces thinking about boundaries early
5. **Safe refactoring** - Tests catch regressions during changes

## Workflow

### 1. Assess Change Type

| Type | Description | Branch Prefix |
|------|-------------|---------------|
| **feat** | New functionality | `feat/` |
| **fix** | Bug fix | `fix/` |
| **chore** | Maintenance, deps, config | `chore/` |
| **refactor** | Restructuring without behavior change | `refactor/` |

### 2. Check Working Directory is Clean

```bash
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: Uncommitted changes exist"
  git status --short
  exit 1
fi
```

If not clean, ask user: stash, commit first, or abort.

### 3. Create Branch from Latest Main

Handles worktree scenarios where main/master is checked out elsewhere:

```bash
git fetch origin
DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
BRANCH_NAME="<type>/<short-description>"
git checkout -b "$BRANCH_NAME" "origin/$DEFAULT_BRANCH"
```

Branch naming: lowercase, hyphen-separated, max 50 chars.

### 4. Enter Plan Mode

After creating the branch, use the `EnterPlanMode` tool to enter plan mode. This:

- Enables exploration without making changes
- Focuses on understanding before implementing
- Requires user approval before any code is written
- Prevents premature implementation

```
Use EnterPlanMode tool here
```

Plan mode continues through steps 5-6 (architecture analysis and PLAN.md creation).

### 5. Understand the Architecture (in plan mode)

Read relevant code to understand:

- **Existing patterns** - How similar features are implemented
- **Module structure** - Where new code should live
- **Conventions** - Naming, file organization, error handling patterns
- **Test patterns** - How existing tests are structured

This prevents inconsistent implementations and helps identify the right location for changes.

### 6. Create PLAN.md (in plan mode)

Write a `PLAN.md` file in the repo root:

```markdown
# Plan: [Brief Title]

**Type:** feat | fix | chore | refactor
**Branch:** <branch-name>

## Summary

[1-2 sentences: what will be implemented and why]

## Impact

- [ ] User-facing change
- [ ] API change (breaking / non-breaking)
- [ ] Database change (migration needed)

## Architecture

### Patterns to Follow
- [Existing pattern this should match, e.g., "Service class pattern in src/services/"]
- [Convention to follow, e.g., "Error handling via Result type"]

### Where This Fits
- [Module/layer this belongs to]
- [How it connects to existing code]

### Key Files to Understand
- `path/to/similar.ts` - [reference implementation]
- `path/to/types.ts` - [shared types]

## TDD Implementation

### Phase 1: Write Tests (RED)

Write failing tests that define expected behavior:

- [ ] Test: [test case description]
- [ ] Test: [test case description]
- [ ] Test: [edge case]
- [ ] Test: [error case]

### Phase 2: Implement (GREEN)

Write minimal code to make tests pass:

- [ ] [Implementation task]
- [ ] [Implementation task]

### Phase 3: Refactor (REFACTOR)

Improve code quality while keeping tests green:

- [ ] [Refactoring task, if known]

## Files

| File | Action | Purpose |
|------|--------|---------|
| `path/to/file.test.ts` | Create | Tests for [feature] |
| `path/to/file.ts` | Create/Modify | [Implementation] |

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| [edge case 1] | [behavior] |
| [error condition] | [error message/handling] |

## Open Questions

- [ ] [Question that needs answering]
```

### 7. Exit Plan Mode

After writing PLAN.md, use `ExitPlanMode` to request user approval. The user will review the plan and either:

- **Approve** - Proceed to implementation
- **Request changes** - Revise the plan
- **Reject** - Abandon this approach

Only proceed to implementation after explicit approval.

### 8. TDD Execution Flow (after approval)

```
┌─────────────────────────────────────────────────────┐
│  1. WRITE TEST                                      │
│     - Write one failing test                        │
│     - Run test → confirm it fails (RED)            │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  2. IMPLEMENT                                       │
│     - Write minimal code to pass the test          │
│     - Run test → confirm it passes (GREEN)         │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  3. REFACTOR                                        │
│     - Clean up code, remove duplication            │
│     - Run tests → confirm still passing            │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
              More tests needed?
                 │         │
                Yes        No
                 │         │
                 ▼         ▼
            Loop back    Done!
            to step 1    Commit.
```

### 9. Commit Strategy

Commit at logical points:
- After test suite is written (tests failing)
- After implementation passes tests
- After refactoring (if significant)

Commit messages follow type prefix: `feat:`, `fix:`, `chore:`, `refactor:`, `test:`

## Parallel Execution (Large Tasks)

For larger tasks, analyze if work can be parallelized.

### When to Parallelize

- Independent components (no shared state)
- Multiple files with no dependencies
- Separate concerns (e.g., frontend + backend)

### Parallelization Patterns

| Pattern | Agent 1 | Agent 2 |
|---------|---------|---------|
| **Layer split** | Backend/API | Frontend/UI |
| **Component split** | Module A | Module B |
| **Test + Impl** | Write all tests | Implement to pass tests |

### Plan Section for Parallel Work

```markdown
## Parallel Execution

### Agent Assignments

| Agent | Focus | Tasks | Files |
|-------|-------|-------|-------|
| Agent 1 | Tests | Write test suite | `*.test.ts` |
| Agent 2 | Implementation | Make tests pass | `*.ts` |

### Sync Points
- After Agent 1 completes: Agent 2 starts implementation
- After both complete: Integration verification
```

### Execution

Spawn agents in parallel using Task tool (single message, multiple calls):

```
Agent 1: "Write tests for [feature] as defined in PLAN.md.
         Commit when test suite is complete (tests will fail)."

Agent 2: "Implement [feature] to pass the tests in PLAN.md.
         Wait for test files to exist, then implement."
```

## Quick Plan (Simple Changes)

For single-file fixes or small changes:

```markdown
# Plan: [Title]

**Type:** fix | **Branch:** fix/issue-name

## Summary
[What and why]

## TDD
1. Test: [what to test]
2. Fix: [what to change]
3. Verify: [run tests]

## Files
- `path/to/file.test.ts` - Add test for [case]
- `path/to/file.ts` - [fix description]
```
