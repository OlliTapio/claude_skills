---
name: quality-gates
description: Set up a project with automated code-smell and quality gates — git pre-commit (fast) and pre-push (slow) hooks that run format, lint, complexity, duplication, dead-code, type, and test checks. Language-agnostic; detects the stack and wires the idiomatic tools. Use when asked to add quality gates, code-smell detection, linting/complexity checks, or git hooks to a repo.
---

# Quality gates

Layer deterministic checks under LLM review: linters catch *measurable* smells (complexity, duplication, dead code) cheaply every commit; LLM review handles semantic smells. Set both tiers up.

## 1. Detect the stack

Inspect the repo root: `package.json` → TS/JS, `pyproject.toml`/`setup.cfg` → Python, `go.mod` → Go, `Cargo.toml` → Rust, etc. A repo may have several. For each, find existing scripts/config before adding anything — reuse them.

## 2. Fill the capability matrix per language

Ensure every language has a tool for each capability. **Complexity, duplication, and dead-code are the smell-catchers — turn them on explicitly; they are usually off by default.**

| Capability | TS/JS (this org) | Python (this org) | Any language |
|---|---|---|---|
| format | prettier | ruff format | the idiomatic formatter |
| lint | oxlint | ruff (`E,F,B,SIM,PL`) | the idiomatic linter |
| complexity | oxlint `complexity` rule | ruff `C901` + `PL` | linter's cyclomatic/cognitive rule, threshold ~10 |
| duplication | jscpd | jscpd | jscpd (language-agnostic) |
| dead code | knip | ruff `F401`/vulture | unused-export/dead-code tool |
| types | tsc | mypy/pyright (if used) | the type checker |
| tests | vitest/bun | pytest | the test runner |

Reference stacks: TS repos use `oxlint + prettier + tsc + vitest + knip` under a `check` script; Python repos use `ruff` (select includes `C`,`PL`) + `pre-commit`. Match those. For unknown languages, find the community-standard tool rather than inventing config.

## 3. Split fast vs slow

- **pre-commit (fast, staged files only):** format check, lint, complexity, duplication. Must stay a few seconds.
- **pre-push (slow, whole repo):** type check, tests, dead-code scan.

## 4. Install versioned git hooks

Copy `templates/git-hooks/` into the repo's `.githooks/`, then point git at it:
```bash
mkdir -p .githooks && cp <skill-repo>/templates/git-hooks/pre-commit <skill-repo>/templates/git-hooks/pre-push .githooks/
chmod +x .githooks/*
git config core.hooksPath .githooks
```
`core.hooksPath` keeps hooks checked in and shared. Edit the two scripts so their command blocks match the tools from step 2. The templates auto-detect TS/Python; add a block per additional language.

## 5. Add unified scripts and baseline

Wire a `check` (all tiers) and `check:fix` entry point in the project's task runner so hooks and humans share one command. Turning complexity/duplication on in an existing repo surfaces many pre-existing hits — set a baseline (`jscpd --threshold`, linter `--max-warnings`) or fix-then-enforce; never leave a gate that always fails.

## 6. Verify

Run the pre-commit and pre-push scripts once manually; confirm they pass on a clean tree and fail on an injected smell.
