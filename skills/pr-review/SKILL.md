---
name: pr-review
description: Review GitHub PRs with a fresh Claude context and produce severity-ranked findings. Use when user asks to review a PR, wants code review feedback, or needs a second opinion on PR changes. Checks for duplicate code, bugs, unclear code, DRY/SOLID violations, over-engineering, tool/library reuse opportunities, and missing tests.
---

# PR Review

Review pull requests with a repeatable workflow that prioritizes real defects over style noise.

## Workflow

### 1. Identify the PR

If the user provides a PR number or URL, use it directly. Otherwise, detect from current branch:

```bash
gh pr view --json number,url,title -q '{number: .number, url: .url, title: .title}' 2>/dev/null || echo "No PR found for current branch"
```

### 2. Gather PR context

```bash
PR=<PR_NUMBER>
OUT="/tmp/pr-review-$PR"
mkdir -p "$OUT"

gh pr view "$PR" --json title,body,baseRefName,headRefName,files > "$OUT/pr_info.json"
gh pr diff "$PR" > "$OUT/diff.patch"

# Project-specific review rules (if available)
[ -f docs/review.md ] && cp docs/review.md "$OUT/project_guidelines.md"
```

### 3. Read changed files fully

Use the file list from `pr_info.json`, then read each changed file in full (not only diff hunks). Full-file context reduces false positives and catches copy-paste regressions.

### 4. Run two review passes

Spawn two agents in parallel via the Agent tool (both calls in a single message). Fresh contexts ensure no bias from prior conversation.

If subagents are not available, run the same two-pass flow sequentially in the main agent.

#### Agent 1 — Critical issues (P0)

Prompt focus: security vulnerabilities, breaking changes, data loss/corruption risk, race conditions and async correctness, logic bugs and edge-case failures, error-handling failures.

Treat these as merge-blocking unless proven safe by explicit evidence. Do not claim runtime behavior without test evidence or clear static proof.

Write findings to `$OUT/findings-critical.json`.

#### Agent 2 — Maintainability (P1/P2)

Prompt focus: missing or insufficient tests for behavior changes, DRY violations likely to drift, over-engineering or reinvented solutions where existing tools should be used, performance and resource leak risks, type-safety and input-validation gaps, dead code or unnecessary complexity.

Write findings to `$OUT/findings-maintainability.json`.

#### Agent guidelines (include in both prompts)

- Read ENTIRE changed files, not just diff hunks
- Be specific and actionable — include file path, line number, concrete fix direction
- Only flag issues that are likely true defects or meaningful risks
- Skip linter-only style nits unless they hide correctness risk
- Include a confidence estimate (high/medium/low) and mark assumptions explicitly
- If project guidelines exist at `$OUT/project_guidelines.md`, apply them
- If no issues found, write an empty array `[]`

#### Severity mapping

| Level | Label | Scope |
|-------|-------|-------|
| P0 | `critical` | Security, data-loss/corruption, breaking production behavior |
| P1 | `warning` | Correctness risk, missing tests for changed behavior, major DRY/perf/type issues |
| P2 | `suggestion` | Clarity and simplification improvements, non-blocking |

#### Finding format

```json
[{"file": "path/to/file.py", "line": 42, "category": "security|breaking|bug|race-condition|missing-tests|dry|over-engineering|performance|type-safety", "severity": "critical|warning|suggestion", "comment": "Specific actionable feedback", "confidence": "high|medium|low"}]
```

### 5. Merge and report

```bash
jq -s 'add' "$OUT/findings-critical.json" "$OUT/findings-maintainability.json" > "$OUT/findings.json"
```

Report to user:
- PR link
- Findings sorted by severity (P0 first)
- Summary count by severity
- If no issues, state explicitly and note residual risk (e.g., missing integration tests)

### 6. Re-review after fixes

When the user says fixes are done:

1. Re-run the workflow on latest PR head.
2. Check each previously reported issue against current file state.
3. Mark each as resolved, still open, or partially fixed.
4. Share a concise delta summary.

## Quality bar

- Favor precision over volume.
- Only report issues that are likely true defects or meaningful risks.
- Always prioritize merge-blocking concerns before suggestions.
