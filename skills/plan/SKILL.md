---
name: plan
description: Plan features, fixes, or chores with TDD approach. Assesses change type (feat/fix/chore), analyzes architecture, and produces a plan with tests written first. Use when starting any non-trivial work.
---

# Plan

Structured planning workflow using Test-Driven Development. Understands architecture and produces a plan where tests are written before implementation.

## Workflow

### 1. Assess change type

Categorize as: **feat**, **fix**, **chore**, or **refactor**.

### 2. Enter plan mode

Use the `EnterPlanMode` tool. This enables exploration without making changes and requires user approval before any code is written.

### 3. Analyze architecture (in plan mode)

Read relevant code to understand existing patterns, module structure, conventions, and test patterns. This prevents inconsistent implementations.

### 4. Write PLAN.md (in plan mode)

```markdown
# Plan: [Brief Title]

**Type:** feat | fix | chore | refactor

## Summary
[1-2 sentences: what and why]

## TDD Phases

### Phase 1: Tests (RED)
- [ ] [Test case — expected behavior]
- [ ] [Edge case]
- [ ] [Error case]

### Phase 2: Implement (GREEN)
- [ ] [Minimal code to pass tests]

### Phase 3: Refactor
- [ ] [Cleanup, if known]

## Files
| File | Action | Purpose |
|------|--------|---------|
| `path/to/file.test.ts` | Create | Tests |
| `path/to/file.ts` | Create/Modify | Implementation |

## Open Questions
- [ ] [Anything unresolved]
```

### 5. Exit plan mode

Use `ExitPlanMode` to request user approval. Only proceed after explicit approval.

### 6. Execute TDD cycle

For each test case in the plan:
1. Write one failing test, run it to confirm RED
2. Write minimal code to pass, confirm GREEN
3. Refactor while keeping tests green

Commit at logical points: after test suite, after implementation passes, after significant refactoring.

## Quick Plan (simple changes)

```markdown
# Plan: [Title]
**Type:** fix

## Summary
[What and why]

## TDD
1. Test: [what to test]
2. Fix: [what to change]
3. Verify: [run tests]

## Files
- `path/to/file.test.ts` - Add test
- `path/to/file.ts` - Fix
```
