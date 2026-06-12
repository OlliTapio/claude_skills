---
description: Writing SKILL.md files — keep them short
paths:
  - "skills/**/SKILL.md"
---

# Skill authoring

Anthropic: *"Keep the body itself concise. Once a skill loads, its content stays in context across turns, so every line is a recurring token cost. State what to do rather than narrating how or why."*
(https://code.claude.com/docs/en/skills)

## Rules

- Aim for one screen. If it's longer, justify each section.
- `description` is the trigger — put the key use case first; it's truncated at 1,536 chars.
- State **what to do**, not why it matters or what could go wrong in theory.
- Cut anti-pattern lists, anecdotes, restated rationale, and multi-step output templates unless the model needs them to act correctly.
- If a sentence doesn't change what the model does, delete it.
