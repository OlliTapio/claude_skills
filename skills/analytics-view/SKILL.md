---
name: analytics-view
description: Build an analytics view (dashboard page, KPI tile, report) where the same number must agree across every surface. Use when adding charts, counters, tables, or aggregate metrics.
---

# analytics-view

Analytics surfaces fail when the same metric is computed twice and the numbers drift. Prevent it structurally.

## Rules

1. **One definition, upstream.** Define each metric once at the data layer — view, function, dbt model, or shared service. Downstream code reads it; never re-derives it.
2. **Fixtures mirror prod shape.** Seed NULLs, edge values, unknown enum-like strings, and every column the production writer touches — not just what this view reads.
3. **Parity test across surfaces.** Same metric in two places (tile vs. table, chart vs. export, API vs. UI) → one test that asserts they agree.
4. **Verify numbers before UI.** Query the source directly against known fixtures. Confirm the number. Then wire the view.

## When a parity test fails

Find which surface drifted (query the canonical definition), fix that surface. Don't relax the test.
