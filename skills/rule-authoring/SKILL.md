---
name: rule-authoring
description: Write a Claude Code rule (.claude/rules/*.md) — path-scoped or always-on instructions Claude loads into context. Use when creating or editing a rule, or turning a repeated correction into persistent guidance.
---

# rule-authoring

## Pick the right mechanism first

- **Rule** (`.claude/rules/*.md`) — a fact or standard that must hold whenever Claude touches matching files. Loads into context.
- **CLAUDE.md** — the same, but always-on and project-wide. Use a `paths`-scoped rule instead when it only concerns part of the tree.
- **Skill** — a multi-step procedure invoked on demand. Loads only when used, so long reference material is free.
- **Hook** — must run at a fixed moment (pre-commit, post-edit). Rules can't enforce; hooks execute regardless of what Claude decides.

If it's a procedure, make it a skill. If it must be enforced, make it a hook.

## Format

```markdown
---
description: <one line — what this rule governs>
paths:
  - "src/api/**/*.{ts,tsx}"
---

# <Topic>

- <instruction>
```

- One topic per file; name it after the topic (`testing.md`, `api-design.md`).
- `paths` scopes the rule — it loads only when Claude reads a matching file. Omit `paths` to load every session at CLAUDE.md priority (use sparingly).
- Globs: `**/*.ts`, `src/**/*`, brace expansion `**/*.{ts,tsx}`.

## Writing rules

- **Concise.** The body is a recurring token cost once loaded. Aim for one screen.
- **State what to do**, not why it matters or what could go wrong.
- **Concrete and verifiable**: "Use 2-space indentation" not "format properly"; "API handlers live in `src/api/handlers/`" not "keep files organized".
- **No conflicts.** Contradicting another rule or CLAUDE.md makes Claude pick arbitrarily. Check existing rules before adding.
- Cut anything that doesn't change what Claude does.
