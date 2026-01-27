---
name: pr-review
description: Review GitHub PRs with a fresh Claude context, leaving inline comments for code quality issues. Use when user asks to review a PR, wants code review feedback, or needs a second opinion on PR changes. Checks for duplicate code, verbose comments, bugs, unclear code, DRY/SOLID violations, missing tests.
---

# PR Review

Review GitHub PRs using fresh Claude agent contexts, posting inline comments for issues found.

**Key benefits:**
- Reviews run in fresh agent contexts via the Task tool, ensuring no bias from code creation
- Two specialized agents run in parallel: one for critical/security issues, one for maintainability

## Review Criteria (by priority)

### P0 - Critical (block merge) - Agent 1
- **Security** - Injection, auth bypass, secrets in code, OWASP top 10
- **Breaking changes** - API contract changes, removed exports, changed signatures
- **Data loss risks** - Destructive operations without safeguards
- **Race conditions** - Concurrency bugs, async issues, shared state mutations
- **Bugs** - Logic errors, null handling, edge cases
- **Error handling** - Swallowed errors, missing try/catch, silent failures

### P1 - High (should fix) - Agent 2
- **DRY violations** - Repeated patterns that should be abstracted (bugs waiting to happen)
- **Missing tests** - New functionality without coverage
- **Performance** - N+1 queries, unbounded operations, memory leaks, blocking in async
- **Resource leaks** - Unclosed handles, connections, subscriptions
- **Type safety** - Unsafe casts, any types, missing null checks
- **Input validation** - Boundary conditions, malformed input handling

### P2 - Suggestions - Agent 2
- **Code clarity** - Unclear naming, complex logic without comments
- **Verbose code** - Can be simplified
- **Dead code** - Unreachable code, unused imports/variables

## Workflow

### 1. Determine PR Number

If the user provides a PR number or URL, extract it. Otherwise, check if we're on a branch with an open PR:

```bash
gh pr view --json number -q '.number' 2>/dev/null || echo "No PR found for current branch"
```

### 2. Get PR Context

```bash
# Create temp directory for this review
mkdir -p /tmp/pr-review-<PR_NUMBER>

# Get list of changed files
gh pr view <PR_NUMBER> --json files -q '.files[].path' > /tmp/pr-review-<PR_NUMBER>/files.txt

# Get the diff
gh pr diff <PR_NUMBER> > /tmp/pr-review-<PR_NUMBER>/diff.patch

# Get PR info
gh pr view <PR_NUMBER> --json title,body,baseRefName,headRefName > /tmp/pr-review-<PR_NUMBER>/pr_info.json
```

### 3. Check for Project-Specific Guidelines

```bash
if [ -f docs/review.md ]; then
  cat docs/review.md > /tmp/pr-review-<PR_NUMBER>/project_guidelines.md
fi
```

### 4. Spawn Two Review Agents IN PARALLEL

**CRITICAL:** Use the Task tool to spawn TWO fresh agents for the review. Run them in parallel by making both Task calls in a single message. This ensures:
- Review context is completely separate from code creation context
- Critical issues are prioritized separately from maintainability concerns
- Faster reviews by parallelizing the work

```
Two Task tool calls in the SAME message:

Agent 1 (Critical):
- subagent_type: "general-purpose"
- description: "Review PR <PR_NUMBER> - critical issues"
- allowed_tools: ["Read", "Write(/tmp/pr-review-*/*)", "Glob", "Grep"]

Agent 2 (Maintainability):
- subagent_type: "general-purpose"
- description: "Review PR <PR_NUMBER> - maintainability"
- allowed_tools: ["Read", "Write(/tmp/pr-review-*/*)", "Glob", "Grep"]
```

The `allowed_tools` parameter pre-authorizes file access so the agents can work without permission prompts.

---

**Agent 1 Prompt (Critical Issues):**

```
You are a security-focused code reviewer for PR #<PR_NUMBER>. You have FRESH context with no prior knowledge.

## Your Focus: Critical Issues Only
You are looking for issues that could cause production incidents, security vulnerabilities, or data loss.

## Setup
1. Read /tmp/pr-review-<PR_NUMBER>/pr_info.json for PR context
2. Read /tmp/pr-review-<PR_NUMBER>/files.txt for changed file list
3. Read /tmp/pr-review-<PR_NUMBER>/diff.patch for the diff
4. If /tmp/pr-review-<PR_NUMBER>/project_guidelines.md exists, read and follow those guidelines
5. Read EACH changed file IN FULL to understand context

## What to Look For (P0 - Critical)

### Security
- SQL/NoSQL injection, command injection, XSS, SSRF
- Authentication/authorization bypass
- Secrets, API keys, passwords in code
- Insecure deserialization
- Path traversal vulnerabilities

### Breaking Changes
- Changed function signatures that break callers
- Removed or renamed exports
- Changed API response formats
- Database schema changes without migration

### Data Loss / Corruption
- Destructive operations (DELETE, DROP, truncate) without safeguards
- Missing transactions where needed
- Race conditions that could corrupt data

### Concurrency Issues
- Race conditions in async code
- Shared mutable state without synchronization
- Deadlock potential
- Missing await on async calls

### Bugs
- Logic errors (wrong operators, off-by-one, inverted conditions)
- Null/undefined not handled
- Edge cases not covered
- Infinite loops potential

### Error Handling
- Exceptions swallowed silently (empty catch blocks)
- Errors not propagated correctly
- Missing error handling on I/O operations
- User-facing errors leaking internal details

## Output
Write findings to /tmp/pr-review-<PR_NUMBER>/findings-critical.json as a JSON array:
[
  {"file": "path/to/file.py", "line": 42, "type": "security|breaking|data-loss|race-condition|bug|error-handling", "severity": "critical", "comment": "Specific actionable feedback"}
]

## Guidelines
- Read ENTIRE files, not just changed lines
- Be specific and actionable
- Only flag REAL issues - false positives waste reviewer time
- Every issue you flag should be something that could cause a production incident
- If you find nothing critical, write an empty array []
```

---

**Agent 2 Prompt (Maintainability):**

```
You are a maintainability-focused code reviewer for PR #<PR_NUMBER>. You have FRESH context with no prior knowledge.

## Your Focus: Code Quality & Maintainability
You are looking for issues that make code hard to maintain, extend, or debug.

## Setup
1. Read /tmp/pr-review-<PR_NUMBER>/pr_info.json for PR context
2. Read /tmp/pr-review-<PR_NUMBER>/files.txt for changed file list
3. Read /tmp/pr-review-<PR_NUMBER>/diff.patch for the diff
4. If /tmp/pr-review-<PR_NUMBER>/project_guidelines.md exists, read and follow those guidelines
5. Read EACH changed file IN FULL to understand context

## What to Look For

### P1 - High Priority (should fix)

**DRY Violations (High Priority - bugs waiting to happen)**
- Same logic copy-pasted in multiple places
- Similar code patterns that should be abstracted
- Duplicated constants or magic values
- When one copy gets fixed, others become bugs

**Missing Tests**
- New functions/classes without test coverage
- Changed logic without updated tests
- Edge cases not tested

**Performance Issues**
- N+1 query patterns
- Unbounded loops or recursion
- Memory leaks (event listeners not cleaned up, growing caches)
- Blocking operations in async code
- Unnecessary re-renders or recomputation

**Resource Leaks**
- File handles not closed
- Database connections not released
- Event subscriptions not unsubscribed
- Timers/intervals not cleared

**Type Safety**
- Unsafe type casts or assertions
- Use of `any` type
- Missing null/undefined checks where needed

**Input Validation**
- Missing boundary checks
- Malformed input not handled
- Assumptions about input format not validated

### P2 - Suggestions

**Code Clarity**
- Unclear variable/function names
- Complex logic that needs a comment
- Deeply nested conditionals

**Verbose Code**
- Code that could be simplified
- Unnecessary intermediate variables
- Overly defensive code

**Dead Code**
- Unreachable code paths
- Unused variables or imports
- Commented-out code

## Output
Write findings to /tmp/pr-review-<PR_NUMBER>/findings-maintainability.json as a JSON array:
[
  {"file": "path/to/file.py", "line": 42, "type": "dry|missing-tests|performance|resource-leak|type-safety|validation|clarity|verbose|dead-code", "severity": "warning|suggestion", "comment": "Specific actionable feedback"}
]

Use severity "warning" for P1 issues, "suggestion" for P2 issues.

## Guidelines
- Read ENTIRE files, not just changed lines - new code might duplicate existing patterns
- Be specific and actionable
- Skip minor style issues that linters handle
- DRY violations are HIGH priority - they cause bugs when one copy is fixed but others aren't
- If you find nothing, write an empty array []
```

---

### 5. Merge and Post Comments

After BOTH agents complete, merge findings and post as PR comments.

**IMPORTANT:** Do NOT use the GitHub review API (`/pulls/{pr}/reviews`). The PR author cannot review their own PR, and you're likely running as the same user. Use regular PR comments instead.

```bash
# Merge findings from both agents
jq -s 'add' /tmp/pr-review-<PR_NUMBER>/findings-critical.json /tmp/pr-review-<PR_NUMBER>/findings-maintainability.json > /tmp/pr-review-<PR_NUMBER>/findings.json

# Post a summary comment with all findings
CRITICAL_COUNT=$(cat /tmp/pr-review-<PR_NUMBER>/findings.json | jq '[.[] | select(.severity == "critical")] | length')
WARNING_COUNT=$(cat /tmp/pr-review-<PR_NUMBER>/findings.json | jq '[.[] | select(.severity == "warning")] | length')
SUGGESTION_COUNT=$(cat /tmp/pr-review-<PR_NUMBER>/findings.json | jq '[.[] | select(.severity == "suggestion")] | length')

CRITICAL_ITEMS=$(cat /tmp/pr-review-<PR_NUMBER>/findings-critical.json | jq -r '.[] | "- [ ] **\(.file):\(.line)** [\(.type)] \(.comment)"')
MAINTAINABILITY_ITEMS=$(cat /tmp/pr-review-<PR_NUMBER>/findings-maintainability.json | jq -r '.[] | "- [ ] **\(.file):\(.line)** [\(.type)] \(.comment)"')

gh pr comment <PR_NUMBER> --body "## Code Review Summary

**Issues found:** $CRITICAL_COUNT critical, $WARNING_COUNT warnings, $SUGGESTION_COUNT suggestions

### Critical Issues (P0)
$CRITICAL_ITEMS

### Maintainability (P1/P2)
$MAINTAINABILITY_ITEMS

---
*Reviewed by Claude with fresh dual-agent context*"
```

Note: Items are formatted as checkboxes (`- [ ]`) so they can be checked off when resolved.

### 6. Report to User

After posting, report:
- Link to the PR
- Summary of issues by severity
- **Highlight any critical issues first** - these block merge
- List of warnings (DRY violations, missing tests, etc.)

---

## Resolving Comments After Fixing Issues

When the user fixes issues from a previous review, update the PR comment to mark items as resolved:

### 1. Find the Review Comment

```bash
# Get the review comment ID (look for "Code Review Summary" comments)
gh api repos/{owner}/{repo}/issues/<PR_NUMBER>/comments \
  --jq '.[] | select(.body | contains("Code Review Summary")) | {id: .id, created_at: .created_at}'
```

### 2. Check Which Issues Are Fixed

Read the current state of the files and compare against the findings in `/tmp/pr-review-<PR_NUMBER>/findings.json`. For each finding, check if:
- The problematic code has been changed/removed
- The issue has been addressed

### 3. Update the Comment with Checked Boxes

```bash
# Update the comment body, changing "- [ ]" to "- [x]" for resolved items
gh api repos/{owner}/{repo}/issues/comments/<COMMENT_ID> \
  --method PATCH \
  -f body="<updated body with [x] for resolved items>"
```

### 4. When All Items Resolved

When all items are checked off, add a follow-up comment:

```bash
gh pr comment <PR_NUMBER> --body "All review items have been addressed."
```
