---
name: explain-diff
description: Use when the user asks for a rich explanation of a code change, diff, branch, or PR. Produces a short figure-led HTML page — a five-bullet summary plus up to four numbered diagrams — then quizzes the user in the chat.
---

# Explain Diff

Adapted from Geoffrey Litt's `explain-diff` prompts: https://gist.github.com/geoffreylitt/a29df1b5f9865506e8952488eac3d524

Figures carry the mechanism; prose carries the reasoning. Read the diff and surrounding code broadly, then spend the effort on the figures — but never at the cost of leaving a decision unexplained.

## Document shape — exactly this, in this order

1. **Title + "In one minute"** — five bullets, ≤20 words each: what changed · why · what breaks if it's wrong · blast radius (files/systems touched) · test status. No TOC, no intro.
2. **Figures 1..N** — up to 4 numbered figures. Each = a short title, a caption (≤40 words, self-contained), and up to 6 sentences of prose. Nothing else.
3. **Testing** — one table (`test · what it pins · level`), ≤5 rows, ≤10-word cells, plus a "not covered" list. No test evidence: say so in one line.
4. **Rejected approaches** — one table (`approach · why it died`), ≤3 rows, ≤15-word cells. One row per decision the prose calls deliberate. If no alternative was weighed, say that in a line instead.

Nothing else. No summary, no "things worth a second look", no beginner tutorial section.

## Budgets — count before saving

- **Prose: ≤900 words.** Counts only what is read linearly — paragraphs, bullets, captions, figure titles. Diagram labels, table cells, and quoted code are glanced at, not read, and have structural caps instead.
- No floor. Length is whatever the decision list below costs; if that list is complete at 500 words, ship 500.
- Figures: **≤4**, of which **≥3 are true diagrams** (not text lists). Vary the kinds — repeating one grammar is fine, four different ones is not.
- Every sentence, caption, and bullet ≤25 words. Vary the lengths: if every sentence sits within a few words of the cap, you are filling to spec rather than making points.
- Code excerpts: ≤4, ≤12 lines each, elided with `…`, each attached to a figure.
- `<details>`: ≤2 blocks, ≤300 words total.

Over budget: delete a figure or a whole claim — never compress sentences.

**Before writing, list every deliberate decision** — a guard omitted, a field left alone, an alternative rejected, an inconsistency kept. Each gets one sentence naming its reason. That list, not a word count, sets the length.

A reason living only in a code excerpt, docstring, or commit message has not been explained. Neither has a pointer to one: "the schema comment states why" is not a reason. Words like *deliberately*, *on purpose*, *intentionally* oblige the reason in the same sentence.

This outranks the word budget: if stating a reason breaks the cap, cut a figure.

## Figures

Vocabulary — pick from these, invent none:

- **Before/after flow** — identical layout, node positions, and input values; only the changed node differs, and it is the only colored one. Feeding the panels different inputs teaches a difference the change did not make.
- **Decision gate** — the conditions that route a case, the outcome per branch, and next to each gate the data it reads (column, log table, config field).
- **State machine** — states, and the transitions the change adds or removes.
- **Message sequence** — components in columns, arrows carrying example payloads.
- **Data-shape row** — one concrete row before and after, changed columns highlighted.
- **Simplified UI mock** — only for user-visible changes.

Rules:

- Figure 1 must let a reader reconstruct the whole change with no prose.
- One shared visual language: same component, same color, everywhere. One legend, beside Figure 1.
- Label with concrete example data (`order_id=42`, `status="pending"`), never type names.
- **A label names states and values; it never argues.** Any label over 8 words, or containing a because/so clause, is prose — move it to the caption where the budget can see it.
- ≤9 nodes per panel; a before/after figure counts each panel separately, and both panels carry the same count. Collapse to the relevant subgraph rather than shrinking text.
- Flow runs one direction; branch downward. Never reverse reading direction inside a panel.
- Sizing: keep `viewBox` width ≤760. Inside an `overflow-x: auto` wrapper, set `width: 100%; max-width: <viewBox>px; height: auto; min-width: 640px` so a narrow screen scrolls the figure instead of shrinking its text. `width: 100%` alone scales a 920px diagram to 0.38x on a phone, rendering 13px labels at 5px.
- Constrain reading measure on `p`/`li`/`table` (~70ch), never on the wrapper — a wrapper `max-width` shrinks diagram text.
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

1. Prose words (paragraphs, bullets, captions, figure titles; not labels, cells, or code) = ? Must be ≤900.
   List the deliberate decisions and, beside each, the sentence giving its reason. Any without one: fix before saving.
   Sentence lengths vary rather than clustering at the cap: yes/no.
2. Figures = ? ≤4. True diagrams = ? ≥3.
3. Every paragraph points at a numbered figure: yes/no.
   Grep each figure's key phrases against its caption, code excerpt, and the testing table — no fact stated twice: yes/no.
4. Every caption reads standalone, ≤40 words: yes/no.
5. Same component, same color across figures; one legend: yes/no.
6. Each SVG scales (`width:100%`, `max-width`, `height:auto`) and no wrapper `max-width`: yes/no.
   Render check: no label wider than the box holding it, no text colliding with a neighbour. Compute smallest label × (390 ÷ widest `viewBox`) ≥ 12px: yes/no.
   No label over 8 words or carrying a because/so clause: yes/no.
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
