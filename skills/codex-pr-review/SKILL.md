---
name: codex-pr-review
description: Review GitHub pull requests in Codex and produce severity-ranked findings with file and line references. Use when the user asks to review a PR, wants a second-opinion code review, or needs verification that review comments are addressed before merge. Focus on critical defects first, then maintainability and test coverage.
---

# Codex PR Review

Review pull requests with a repeatable workflow that prioritizes real defects over style noise.

## Codex capabilities in this skill

Use these strengths during review:

- Inspect repository state and PR metadata with `git` and `gh`.
- Read diffs and full files quickly, then cross-check implementation against tests and nearby call sites.
- Run local verification commands (tests, lint, typecheck, build) when available and relevant.
- Draft high-signal findings with exact file/line references and concrete fix guidance.
- Implement fixes directly when the user asks, then re-run checks and summarize deltas.
- Reuse `security-best-practices` guidance for security-focused analysis.

Respect these constraints:

- If `gh` is unauthenticated or unavailable, report the blocker and continue with local diff/file review when possible.
- Do not claim runtime behavior without either test evidence or clear static proof.
- Avoid speculative findings when confidence is low; mark assumptions explicitly.

## Workflow

### 1. Identify the PR

If the user provides a PR URL or number, use it directly. Otherwise, detect PR from the current branch:

```bash
gh pr view --json number,url,title -q '{number: .number, url: .url, title: .title}' 2>/dev/null || echo "No PR found for current branch"
```

If no PR is found, ask the user for PR number or URL.

### 2. Gather PR context

```bash
PR=<PR_NUMBER>
OUT="/tmp/codex-pr-review-$PR"
mkdir -p "$OUT"

gh pr view "$PR" --json title,body,baseRefName,headRefName,files > "$OUT/pr_info.json"
gh pr diff "$PR" > "$OUT/diff.patch"
```

Optionally collect project-specific review rules:

```bash
if [ -f docs/review.md ]; then
  cp docs/review.md "$OUT/project_guidelines.md"
fi
```

### 3. Read changed files fully

Use the PR file list from `pr_info.json`, then read each changed file in full (not only diff hunks). Full-file context reduces false positives and catches copy-paste regressions.

### 4. Run two review passes

Do two explicit passes, in this order.

#### Security skill integration

When security is part of the request, load and apply the `security-best-practices` skill:

1. Identify languages/frameworks in the PR scope.
2. Read matching references from that skill.
3. Apply those checks during Pass A.
4. If user asks for a dedicated security report, write `security_best_practices_report.md` with file+line references.

#### Pass A: Critical issues (P0/P1)

Check for:

- Security vulnerabilities (SQL/NoSQL injection, command injection, XSS, SSRF, auth bypass, secrets, path traversal)
- Breaking changes (API contracts, removed exports, signature changes, response shape changes)
- Data loss or corruption risk (unsafe deletes, missing safeguards, missing transactions)
- Race conditions and async correctness (shared mutable state, missing await, ordering bugs)
- Logic bugs and edge-case failures (off-by-one, null handling, inverted conditions)
- Error-handling failures (silent catch blocks, dropped errors, leaked internals in user errors)

Treat these as merge-blocking unless proven safe by explicit evidence.

#### Pass B: Maintainability and confidence (P1/P2)

Check for:

- Missing or insufficient tests for behavior changes
- DRY violations and duplicated logic likely to drift
- Over-engineering or reinvented solutions where existing libraries, framework features, or project utilities should be used
- Performance and resource leak risks (N+1, unbounded loops, leaked handles/listeners)
- Type-safety and input-validation gaps
- Clarity problems that hide defects
- Dead code or unnecessary complexity

#### Severity mapping

- P0 `critical`: security, data-loss/corruption, breaking production behavior.
- P1 `warning`: high-risk correctness, missing tests for changed behavior, major DRY/perf/type issues.
- P2 `suggestion`: clarity and simplification improvements that are non-blocking.

#### Coverage, DRY, and tool-usage checks (required)

- For each changed non-test file, verify whether related tests were added or updated.
- If behavior changes and tests did not change, add a missing-tests finding.
- Look for duplicated logic introduced in this PR or copied from nearby modules.
- Flag DRY issues only when duplication is substantial enough to cause drift risk.
- Flag custom implementations that duplicate capabilities already available via stable libraries or project-standard tooling.

### 5. Use clean-context subagents when available

If the runtime supports subagents/Task:

- Spawn Subagent 1 for critical + security checks (Pass A).
- Spawn Subagent 2 for maintainability checks (Pass B).
- Keep prompts scoped and have each subagent write findings to separate temp files.
- Merge findings and remove duplicates before reporting.

If subagents are not available, run the same two-pass flow sequentially in the main agent.

### 6. Produce findings in required format

When reporting to the user:

- List findings first, sorted by severity: P0, P1, P2
- For each finding include file path, line number, category, impact, and concrete fix direction
- Keep comments actionable and specific
- Skip linter-only style nits unless they hide correctness risk
- If no issues are found, state that explicitly and note any residual risk (for example, missing integration tests)
- Include a confidence estimate and mention assumptions when evidence is partial.

Preferred finding format:

```text
[P1] path/to/file.ts:123
Category: missing-tests|dry|over-engineering|performance|type-safety|validation|bug|security|breaking|error-handling
Impact: ...
Fix: ...
Confidence: high|medium|low
```

### 7. Re-review fixed comments

When the user says fixes are done:

1. Re-run the same workflow on the latest PR head.
2. Check each previously reported issue.
3. Mark each issue as resolved, still open, or partially fixed.
4. Share a concise delta summary.

### 8. Optional remediation mode (when user asks)

If the user asks to fix issues instead of only reviewing:

1. Prioritize P0 and P1 findings.
2. Implement minimal, targeted patches.
3. Run relevant verification commands.
4. Report what changed, what passed, and any remaining risk.

## Quality bar

- Favor precision over volume.
- Only report issues that are likely true defects or meaningful risks.
- Always prioritize merge-blocking concerns before suggestions.
