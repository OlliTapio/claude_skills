# Assumption cases

Real bugs that shipped because a load-bearing assumption went unverified. Append new ones as they're found.

## Framework behavior asserted in a docstring, baked into the tests

A service tracked whether a user finished watching an intro clip. The observer's docstring stated:

> The player only emits `PlaybackFinished` when playback drains naturally;
> closing the page mid-clip cancels the pipeline *without* emitting it.

False — cancelling flushes the buffer, so the event fires on cancel too. Every early exit was counted as "intro watched", inflating the engagement metric. Only a production log surfaced it.

Why review missed it:

- The claim was about a third-party library, stated as settled fact in prose. Reviewers read the docstring and trusted it.
- The unit test covering the case asserted **by omission** — it simply never emitted the event, and the comment justifying that was the assumption itself: `# No PlaybackFinished (cancel path emits none)`. The test was derived from the belief, so it could not fail.
- The integration test's mock player only emitted the event on natural end, encoding the same belief and making the real behavior unreachable.
- Result: three layers of green tests, zero evidence. `grep` in the installed library would have settled it in under a minute.

Generalizable tell: **the code that would falsify the claim was never read, and every fixture that touches the claim was authored from it.**
