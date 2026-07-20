---
name: setup-project
description: Scaffold a new project end-to-end — pick an LLM-friendly language, lay out the layered architecture (controllers/services/repos/views), install .claude rules, and wire quality gates. Use when starting a new repo, bootstrapping a project, or standardizing an existing one's structure and guardrails.
---

# setup-project

## 1. Choose the language

Recommend the language the model codes most reliably for the domain (favor static typing plus mature formatter/linter/test tooling). Confirm with the user before scaffolding.

## 2. Scaffold the layered architecture

Four layers, dependencies pointing one way: **controllers → services → repos**, with **views** for output.

```
src/
  controllers/   entry points (HTTP/CLI/queue): validate input, call one service, map through a view
  services/      business logic & orchestration; storage/transport-agnostic
  repos/         data access (DB, external APIs); returns domain types
  views/         output shaping (DTOs, serializers, templates, UI)
  domain/        shared types/entities
tests/
```

Create the directories and one working slice (controller → service → repo → view). Match the language's idioms.

## 3. Install .claude rules

- Copy `templates/rules/layered-architecture.md` into `.claude/rules/` — enforces layer responsibilities and dependency direction.
- Add project-specific rules with the `rule-authoring` skill (testing, API design, naming).

## 4. Wire quality gates

Run the `quality-gates` skill: per-language checks, then git **pre-commit** (fast) + **pre-push** (slow) hooks.

## 5. Verify

Confirm the sample slice builds/tests green, the hooks pass on a clean tree and fail on an injected smell, and `.claude/rules/` loads (edit a file under `src/` and check the rule applies).
