---
name: plan
description: Plan features, fixes, or chores with TDD approach. Use when starting any non-trivial work. Extends Claude's built-in planning with test-driven structure.
---

# Plan

Use Claude's built-in `EnterPlanMode` to explore the codebase and design an approach — but structure the plan around TDD: tests define the spec before any implementation.

## TDD nuance

When writing the plan (PLAN.md), organize implementation as TDD phases:

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

## Execution

After plan approval, follow the TDD cycle strictly:
1. Write one failing test, run it to confirm RED
2. Write minimal code to pass, confirm GREEN
3. Refactor while keeping tests green
4. Repeat for each test case in the plan

Commit at logical points: after test suite, after passing implementation, after significant refactoring.
