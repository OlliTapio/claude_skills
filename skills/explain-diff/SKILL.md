---
name: explain-diff
description: Use when the user asks for a rich explanation of a code change, diff, branch, or PR. Produces an interactive HTML file or a Notion page with background, intuition, code walkthrough, and a quiz.
---

# Explain Diff

Adapted from Geoffrey Litt's `explain-diff` prompts: https://gist.github.com/geoffreylitt/a29df1b5f9865506e8952488eac3d524

Produce a rich explanation of the specified code change. Ask which output the user wants if unclear: **HTML file** (self-contained, interactive) or **Notion page**.

## Sections

- **Background**: Explain the existing system relevant to this change. Broadly explore surrounding code first. Include a deep background for beginners (skippable if already familiar), then a narrow background directly relevant to the change.
- **Intuition**: Explain the core intuition — the essence, not full details. Use concrete examples with toy data. Use figures and diagrams liberally.
- **Code**: High-level walkthrough of the changes, grouped/ordered understandably.
- **Quiz**: Five medium-difficulty multiple-choice questions — hard enough to require understanding the substance, not gotchas. Each answer gives feedback on why it is correct or incorrect. Randomize the position of correct answers.

## Writing

- Write with the clarity and flow of Martin Kleppmann — engaging, classic style, smooth transitions between sections.
- Pick a small number of reusable diagram families. Useful kinds: a simplified version of the app UI (for UI changes); a system diagram of data flow between components (include example data). Never use ASCII diagrams.
- Use callouts for key concepts, definitions, and important edge cases.

## HTML output

- One self-contained HTML file: inline CSS and JavaScript, no external dependencies. One long page with section headers and a table of contents (no top-level tabs). Basic responsive styling for mobile.
- Save outside the code repo, filename starting with today's date: e.g. `/tmp/2026-01-12-explanation-<slug>.html`.
- Diagrams are HTML/CSS, lists are HTML lists. Quiz is interactive: clicking an option reveals correct/incorrect with feedback.
- Code blocks use `<pre>` tags. If using a styled `div` instead, it **must** have `white-space: pre-wrap`, or the browser collapses newlines. Before saving, scan each code block and confirm its CSS includes `white-space: pre` or `pre-wrap`.

## Notion output

- Use the Notion MCP tools to create a new page; return its URL.
- Quiz uses toggle blocks — each option is a toggle revealing ✅/❌ and an explanation:
  ```
  1. Question
     ▶ Option 1 → ❌ why incorrect
     ▶ Option 2 → ✅ why correct
  ```
