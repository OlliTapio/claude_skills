# Assumption cases

Real bugs that shipped because a load-bearing assumption went unverified. Append new ones as they're found.

## Framework behavior asserted in a docstring, baked into the tests

`sointu-pipecat` tracked whether a callee heard a call's opening greeting. The observer's docstring stated:

> The output transport only emits `BotStoppedSpeakingFrame` when playback drains
> naturally; a caller hangup mid-greeting cancels the pipeline (`CancelFrame`)
> *without* emitting it.

False — cancelling flushes TTS, so the frame fires on hangup too. Every hangup mid-greeting was counted as "opening heard", inflating the campaign's engagement metric. Only a production carrier log surfaced it.

Why review missed it:

- The claim was about a third-party library, stated as settled fact in prose. Reviewers read the docstring and trusted it.
- The unit test covering the case asserted **by omission** — it simply never pushed the frame, and the comment justifying that was the assumption itself: `# No BotStoppedSpeakingFrame (CancelFrame path emits none)`. The test was derived from the belief, so it could not fail.
- The integration test's `MockTransport` only emitted the frame on `TTSStopped`/`EndFrame`, encoding the same belief and making the real behavior unreachable.
- Result: three layers of green tests, zero evidence. `grep` in the installed library would have settled it in under a minute.

Generalizable tell: **the code that would falsify the claim was never read, and every fixture that touches the claim was authored from it.**
