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

- **Total on-page words: 700.** Counts prose, bullets, captions, table cells, and diagram labels. Excludes quoted code.
- Figures: **≤4**, of which **≥3 are true diagrams** (not text lists). Vary the kinds — repeating one grammar is fine, four different ones is not.
- Every sentence, caption, and bullet ≤25 words.
- Code excerpts: ≤4, ≤12 lines each, elided with `…`, each attached to a figure.
- `<details>`: ≤2 blocks, ≤300 words total.

These are ceilings, not targets. Over budget: delete a figure or its prose — never compress sentences.

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
- Sizing: give each SVG `width: 100%; max-width: <viewBox width>px; height: auto` so it renders at full size on desktop and scales down on mobile. Constrain reading measure on `p`/`li`/`table` (~70ch), never on the wrapper — a wrapper `max-width` shrinks diagram text below its stated size.
- No gradients, icons, shadows, or 3D. Every box, arrow, and color means something.
- A figure that restates its own code excerpt, its caption, or a testing row is not a figure. Cut it and keep the excerpt.
- Legend swatches must all appear in Figure 1. A color introduced later belongs in that figure's caption.

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
   Grep each figure's key phrases against its caption, code excerpt, and the testing table — no fact stated twice: yes/no.
4. Every caption reads standalone, ≤40 words: yes/no.
5. Same component, same color across figures; one legend: yes/no.
6. Each SVG scales (`width:100%`, `max-width`, `height:auto`) and no wrapper `max-width`: yes/no.
   Render check: no label wider than the box holding it, no text colliding with a neighbouring shape, nothing under 12px: yes/no.
7. Every `<pre>` or styled code block sets `white-space: pre` or `pre-wrap` — otherwise newlines collapse: yes/no.

## Output

- One self-contained HTML file: inline CSS and JS, no external dependencies. Single page, responsive.
- Save outside the code repo, filename prefixed with today's date: e.g. `/tmp/2026-01-12-explanation-<slug>.html`.
- Diagrams are HTML/CSS or inline SVG. Code blocks use `<pre>`.

## Quiz — in chat, not in the document

After delivering the file, offer the quiz; run it if the user accepts.

**Anchor every question before asking it.** Write the question, then name the figure, caption, table row, or bullet on the page that contains the answer. No anchor means one of two things:

- The page is missing something a reader needs — patch the page, then ask.
- The question is testing the repo rather than the explanation — cut it.

A fact that appears only inside a code excerpt is not fair game unless the excerpt or its caption states the *reason*, not just the line.

**Every stem must be self-contained.** State each precondition the scenario needs to resolve. If the answer turns on a fact the stem omits, the question is broken, not the answer.

- One question per figure, plus at most one on testing: 3-5 total. Medium difficulty — real understanding, not gotchas.
- Each distractor must be wrong for a reason the page states, so the explanation can point at it.
- One `AskUserQuestion` call per question. After each answer, say whether it was correct and why the tempting wrong options are wrong. Randomize the correct answer's position.
- If the user shows a question was unfair, drop it from the score and say so.
- End with a score and which figures to re-read.
