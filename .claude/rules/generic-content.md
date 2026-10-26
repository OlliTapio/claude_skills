---
description: Keep every file generic — no real names of employers, clients, people, products, or repos
---

# Generic content only

This is a public personal repo. The leak guard only catches the terms in its denylist, so keep names out before they get there.

## Rules

- Write skills, hooks, templates, examples, tests, and commit messages so they apply to any project.
- Never name a real employer, client, coworker, product, service, internal repo, hostname, or ticket ID.
- When an example comes from real work, replace each specific with a placeholder (`<repo>`, `<service>`, `acme-api`, `example.com`, `PROJ-123`) and keep only the general pattern.
- Allowed names: OlliTapio, olli@otl.fi, public tools and libraries (git, GitHub, npm, Playwright), and credited public sources.
- If a source you're adapting contains specifics, generalize them; if you're unsure whether a name is work-related, ask before writing it.
- When you notice a name the denylist misses, tell the user so they can add it to `.githooks/denylist.local`. Don't write the term itself into any tracked file.
