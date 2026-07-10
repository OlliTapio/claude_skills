---
name: pr-review
description: Review GitHub PRs with a fresh Claude context and produce severity-ranked findings. Use when user asks to review a PR, wants code review feedback, or needs a second opinion on PR changes. Checks for duplicate code, bugs, unclear code, DRY/SOLID violations, over-engineering, tool/library reuse opportunities, and missing tests.
---

# PR Review

Prioritize real defects over style noise. Favor precision over volume — only flag likely defects or meaningful risks.

## 1. Get the PR and guidelines

Use the PR number/URL if given; else `gh pr view` on the current branch. Fetch the diff and changed-file list. Read `.claude/rules/` and `docs/review.md` if present — **paste their content into both agent prompts** so each bot enforces the rules on its own beat. A guideline violation is always P0.

## 2. Two focused reviews

Spawn **two Agents in parallel** (single message), each with a fresh context and **only its own brief** — never both. Fall back to sequential if Agents are unavailable.

**Agent 1 — Security & breaking changes:**
- Security: injection, XSS, SSRF, auth bypass, secrets, path traversal
- Breaking changes: API contracts, removed exports, signature/response-shape changes
- Data loss: unsafe deletes, missing transactions/safeguards
- Async correctness: races, missing `await`, shared mutable state
- Logic bugs: off-by-one, null handling, inverted conditions
- Error handling: silent catches, dropped errors, internals leaked to users
- Any pasted guideline touching the above

**Agent 2 — Code quality:**
- Missing tests for changed behavior
- DRY: trace each derived value to one source; a rule in two syntaxes (e.g. app classifier mirroring SQL `CASE`) is duplication — push to the lowest shared layer. If two paths must coexist, require a parity test covering nulls/edge values.
- Over-engineering or reinvented wheels where a library/framework/project util exists
- Redundant migrations — several files that could be one, or one feature split across PRs (don't edit a migration already applied to prod)
- Performance/leaks: N+1, unbounded loops, leaked handles/listeners
- Type-safety and input-validation gaps; clarity that hides defects; dead code
- Any pasted guideline touching the above

**Both bots:** read entire changed files, not just hunks. Return each finding as file + line + concrete fix + confidence (high/med/low); mark assumptions. Skip style nits unless they hide correctness risk. Assign severity per finding by impact (§3) — a bot's beat decides *what* it hunts, not how severe each hit is; either bot can report any severity.

## 3. Severity (per finding, by impact)

- **P0 critical** — exploitable/data-losing/prod-breaking now, or any `.claude/rules`/`docs/review.md` violation
- **P1 warning** — real risk needing a trigger or specific state: correctness bugs, exploitable-only-under-conditions security gaps, missing tests for changed behavior, major DRY/perf/type issues
- **P2 suggestion** — hardening and clarity with no direct failure path: defense-in-depth, simplification, non-blocking nits

## 4. Report

Present findings to the user sorted P0→P2, with a count per severity. If none, say so and name residual risk (e.g. missing integration tests).

## 5. Re-review

On "fixes done", re-run on the new head, mark each prior finding resolved / open / partial, share the delta.
