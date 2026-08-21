---
name: explain-diff
description: Use when the user asks for a rich explanation of a code change, diff, branch, or PR. Produces a short figure-led HTML page — a five-bullet summary plus up to four numbered diagrams — then quizzes the user in the chat.
---

# Explain Diff

Adapted from Geoffrey Litt's `explain-diff` prompts: https://gist.github.com/geoffreylitt/a29df1b5f9865506e8952488eac3d524

The figures carry the explanation; prose is connective tissue. Read the diff and surrounding code broadly, then spend the effort on the figures.

## Document shape — exactly this, in this order

1. **Title + "In one minute"** — five bullets, ≤20 words each: what changed · why · what breaks if it's wrong · blast radius (files/systems touched) · test status. No TOC, no intro.
2. **Figures 1..N** — up to 4 numbered figures. Each = caption (≤40 words, self-contained) + ≤3 sentences of prose. Nothing else.
3. **Testing** — one table (`test · what it pins · level`), ≤5 rows, ≤10-word cells, plus a "not covered" list. No test evidence: say so in one line.

Nothing else. No summary, no "things worth a second look", no beginner tutorial section.

## Budgets — count before saving

- **Total on-page words: 700.** Captions, bullets, and table cells count.
- Figures: **≤4**, of which **≥3 are true diagrams** (not text lists). Reuse ≤2 vocabulary kinds.
- Every sentence, caption, and bullet ≤25 words.
- Code excerpts: ≤4, ≤12 lines each, elided with `…`, each attached to a figure.
- `<details>`: ≤2 blocks, ≤300 words total.

Over budget: delete a figure or its prose. Never compress sentences.

## Figures

Vocabulary — pick from these, invent none:

- **Before/after flow** — identical layout and node positions; only the changed node differs, and it is the only colored one.
- **Decision gate** — the conditions that route a case, the outcome per branch, and next to each gate the data it reads (column, log table, config field).
- **State machine** — states, and the transitions the change adds or removes.
- **Message sequence** — components in columns, arrows carrying example payloads.
- **Data-shape row** — one concrete row before and after, changed columns highlighted.
- **Simplified UI mock** — only for user-visible changes.

Rules:

- Figure 1 must let a reader reconstruct the whole change with no prose.
- One shared visual language: same component, same color, everywhere. One legend, beside Figure 1.
- Label with concrete example data (`order_id=42`, `status="pending"`), never type names.
- ≤9 nodes. Collapse to the relevant subgraph rather than shrinking text.
- Flow runs one direction; branch downward. Never reverse reading direction inside a panel.
- Sizing: the figure container must be at least as wide as the widest `viewBox`. Never put a text `max-width` on the page wrapper — it shrinks SVG text below its stated size.
- No gradients, icons, shadows, or 3D. Every box, arrow, and color means something.
- A figure that restates a list is not a figure. Keep the list.

## Code

Show the change, don't describe it. For the 3-5 changes that matter, hang a `<pre>` excerpt off its figure: added lines bolded and tinted, plus one sentence saying what to notice. Organize by mechanism, never by file or diff order. Need a file map? One `<details>` table.

## Forbidden

- Any prose paragraph that doesn't point at a figure.
- Walking the diff file by file.
- Explaining what a decorator/queue/JOIN/hook is.
- Restating a bullet, caption, or table cell anywhere.
- Branch history ("the first draft", "review caught"). Rejected designs become one table row: `approach · why it died`.
- Filler: "it's important to note", "essentially", "basically", "leverages", "in order to", "the fact that", rhetorical questions, transition-only sentences.
- ASCII diagrams.

## Self-check before saving

State each result in chat, one line each. Fix, don't rationalize.

1. Total on-page words (including captions, bullets, table cells) = ? Must be ≤700.
2. Figures = ? ≤4. True diagrams = ? ≥3.
3. Every paragraph points at a numbered figure: yes/no.
4. Every caption reads standalone, ≤40 words: yes/no.
5. Same component, same color across figures; one legend: yes/no.
6. No text `max-width` on the wrapper; each figure container ≥ its `viewBox` width: yes/no.
7. Every `<pre>` or styled code block sets `white-space: pre` or `pre-wrap` — otherwise newlines collapse: yes/no.

## Output

- One self-contained HTML file: inline CSS and JS, no external dependencies. Single page, responsive.
- Save outside the code repo, filename prefixed with today's date: e.g. `/tmp/2026-01-12-explanation-<slug>.html`.
- Diagrams are HTML/CSS or inline SVG. Code blocks use `<pre>`.

## Quiz — in chat, not in the document

After delivering the file, offer the quiz; run it if the user accepts.

- Five medium-difficulty multiple-choice questions requiring real understanding, not gotchas. Randomize the correct answer's position.
- One `AskUserQuestion` call per question. After each answer, say whether it was correct and why the tempting wrong options are wrong.
- End with a score and which figures to re-read.
