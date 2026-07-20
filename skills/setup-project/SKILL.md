---
name: setup-project
description: Scaffold a new project end-to-end — pick an LLM-friendly language, lay out the layered architecture (controllers/services/repos/views), install .claude rules, and wire quality gates. Use when starting a new repo, bootstrapping a project, or standardizing an existing one's structure and guardrails.
---

# setup-project

Bootstrap a project with a fixed layered architecture, enforced by rules and quality gates.

## 1. Choose the language

We do LLM-driven coding — pick the language the model writes most reliably for the domain. Weigh: size/recency of training corpus, benchmark pass rates, static typing (fewer silent errors for a model to make), and mature tooling (formatter/linter/types/tests). Recommend the best fit and confirm with the user before scaffolding.

## 2. Scaffold the layered architecture

Always use four layers; the cost of the structure is low and it scales. Dependencies point one way: **controllers → services → repos**, with **views** for output.

```
src/
  controllers/   entry points (HTTP/CLI/queue): validate input, call one service, map through a view
  services/      business logic & orchestration; storage/transport-agnostic
  repos/         data access (DB, external APIs); returns domain types
  views/         output shaping (DTOs, serializers, templates, UI)
  domain/        shared types/entities
tests/
```

Create the directories and a minimal working slice (one controller → service → repo → view) so the pattern is copyable. Match the language's idioms (folder names, module system).

## 3. Install .claude rules

- Copy `templates/rules/layered-architecture.md` into `.claude/rules/` — enforces layer responsibilities and dependency direction.
- Add project-specific rules with the `rule-authoring` skill (testing conventions, API design, naming). One topic per file, `paths`-scoped. Keep CLAUDE.md for always-on, project-wide facts only.

## 4. Wire quality gates

Run the `quality-gates` skill: capability matrix per language (format, lint, **complexity, duplication, dead-code**, types, tests), then git **pre-commit** (fast) + **pre-push** (slow) hooks via `core.hooksPath`.

## 5. Verify

Confirm the sample slice builds/tests green, the hooks pass on a clean tree and fail on an injected smell, and `.claude/rules/` loads (edit a file under `src/` and check the rule applies).
