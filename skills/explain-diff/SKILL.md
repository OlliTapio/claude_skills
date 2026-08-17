---
name: explain-diff
description: Use when the user asks for a rich explanation of a code change, diff, branch, or PR. Produces a self-contained HTML file with background, intuition, and code walkthrough, then quizzes the user in the chat.
---

# Explain Diff

Adapted from Geoffrey Litt's `explain-diff` prompts: https://gist.github.com/geoffreylitt/a29df1b5f9865506e8952488eac3d524

Produce a rich explanation of the specified code change as a self-contained HTML file.

## Sections

- **Background**: Explain the existing system relevant to this change. Broadly explore surrounding code first. Include a deep background for beginners (skippable if already familiar), then a narrow background directly relevant to the change.
- **Intuition**: Explain the core intuition — the essence, not full details. Use concrete examples with toy data. Use figures and diagrams liberally.
- **Code**: High-level walkthrough of the changes, grouped/ordered understandably.

The document contains no quiz — the quiz happens in the chat (below).

## Writing

- Write with the clarity and flow of Martin Kleppmann — engaging, classic style, smooth transitions between sections.
- Pick a small number of reusable diagram families. Useful kinds: a simplified version of the app UI (for UI changes); a system diagram of data flow between components (include example data). Never use ASCII diagrams.
- Use callouts for key concepts, definitions, and important edge cases.

## Quiz (in chat)

After delivering the document, offer the quiz and run it with `AskUserQuestion` if the user accepts.

- Five medium-difficulty multiple-choice questions — hard enough to require understanding the substance, not gotchas. Randomize the position of the correct answer.
- One `AskUserQuestion` call per question, so feedback can follow each answer. After each answer, say whether it was correct and why — including why the tempting wrong options are wrong.
- End with a short score and a pointer to the document sections worth re-reading.

## Output

- One self-contained HTML file: inline CSS and JavaScript, no external dependencies. One long page with section headers and a table of contents (no top-level tabs). Basic responsive styling for mobile.
- Save outside the code repo, filename starting with today's date: e.g. `/tmp/2026-01-12-explanation-<slug>.html`.
- Diagrams are HTML/CSS, lists are HTML lists.
- Code blocks use `<pre>` tags. If using a styled `div` instead, it **must** have `white-space: pre-wrap`, or the browser collapses newlines. Before saving, scan each code block and confirm its CSS includes `white-space: pre` or `pre-wrap`.
