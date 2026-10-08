---
name: pr-review
description: Review GitHub PRs with a fresh Claude context and produce severity-ranked findings, auto-fixing P0/P1 and having the reviewing agents confirm each fix. Use when user asks to review a PR, wants code review feedback, or needs a second opinion on PR changes. Checks for duplicate code, bugs, unclear code, DRY/SOLID violations, over-engineering, tool/library reuse opportunities, missing tests, and assumptions no test can falsify.
---

# PR Review

Prioritize real defects over style noise. Favor precision over volume — only flag likely defects or meaningful risks.

## 1. Get the PR and guidelines

Use the PR number/URL if given; else `gh pr view` on the current branch. Fetch the diff and changed-file list. Read `.claude/rules/` and `docs/review.md` if present — **paste their content into all three agent prompts** so each bot enforces the rules on its own beat. A guideline violation is always P0.

## 1b. Stray files

Scan the changed-file list for dependency dirs (`node_modules/`, `.venv/`), build output (`dist/`, `build/`, `*.pyc`), local scratch (`tmp*`, `scratch*`, `*.log`, ad-hoc run scripts) and editor/OS junk (`.DS_Store`, `.idea/`). Exempt a dependency or build path whose directory already has tracked files on the default branch; scratch and junk get no exemption.

Exclude what's left from the diff and file list handed to the agents, and report each as P1: the file and the fix (`git rm --cached <path>` plus a `.gitignore` entry matching the pattern, not just that path). Env and credential files stay in the diff — Agent 1 judges those.

## 2. Three focused reviews

Spawn **three Agents in parallel** (single message), each with a fresh context and **only its own brief** — never another's. Keep each agent's ID for §4. Fall back to sequential if Agents are unavailable.

**Agent 1 — Security & breaking changes:**
- Security: injection, XSS, SSRF, auth bypass, secrets, path traversal
- Secrets in git: env/credential files, keys, certs, tokens, DB dumps, customer data — scan every commit on the branch, not just the head tree; a squash merge hides them from main but GitHub keeps PR commits fetchable forever, so say whether the secret needs rotating
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

**Agent 3 — Unverified assumptions:** (have it read `~/.claude/skills/pr-review/references/assumption-cases.md` first)
Find claims the change *rests on* that nothing proves. Per claim: if it were false, which existing test turns red? Name it, or it's unverified. Read the PR body. Examples:
- Prose absolutes about code outside the diff ("only emits X when Y", "never null", "always ordered") — read that code and cite file:line
- Mocks/fakes/fixtures: behavior derived from the real implementation (cite it), or authored from belief? A fake that diverges on the path under test makes green tests meaningless
- Tests asserting by *omission* — outcome established by not pushing an event or setting a field, justified by a belief about upstream

Verify what's readable (dependency source, installed packages, schemas) instead of listing manual to-dos. Report the claim, what breaks if wrong, whether any test can falsify it, and the cheapest test that would. Skip claims nothing depends on.

**All bots:** read entire changed files, not just hunks. Return each finding as file + line + concrete fix + confidence (high/med/low); mark assumptions. Skip style nits unless they hide correctness risk. Assign severity per finding by impact (§3) — a bot's beat decides *what* it hunts, not how severe each hit is; any bot can report any severity.

## 3. Severity (per finding, by impact)

- **P0 critical** — exploitable/data-losing/prod-breaking now, or any `.claude/rules`/`docs/review.md` violation
- **P1 warning** — real risk needing a trigger or specific state: correctness bugs, exploitable-only-under-conditions security gaps, missing tests for changed behavior, load-bearing unverified assumptions (especially ones the PR's own tests bake in, so they read as covered), major DRY/perf/type issues
- **P2 suggestion** — hardening and clarity with no direct failure path: defense-in-depth, simplification, non-blocking nits

## 4. Fix P0/P1 and confirm

Reviewers and implementer MUST NOT see each other's context. Relay only finding text and commit SHAs between them.

Spawn a fresh **implementer Agent**. Give it the PR branch (`gh pr checkout` in a worktree if it isn't current), the pasted guidelines, and each P0/P1 as ID + file + line + problem + suggested fix. Never pass reviewer transcripts or reasoning. It fixes each finding, runs the project's checks, commits, and returns SHA + finding IDs. It pushes only if `gh pr view --json author` is the current `gh` user; otherwise it leaves the commits local, and the report says so. P2s stay unfixed. Fix stray-file findings yourself.

Then `SendMessage` each reviewer that raised a fixed finding with only its own findings, as it reported them, and the SHA — not the implementer's explanation. It re-reads the code at that SHA and answers per finding: **confirmed** / **not fixed** (with why) / **new issue introduced**. Send rejections to the implementer as new findings; stop after 3 rounds. Confirm stray-file fixes yourself from the new file list.

## 5. Report

Present findings to the user sorted P0→P2, with a count per severity. Mark each P0/P1 confirmed or still open, with the commit SHA. If none, say so and name residual risk (e.g. missing integration tests).

## 6. Re-review

On "fixes done", re-run on the new head, mark each prior finding resolved / open / partial, share the delta.
