#!/usr/bin/env bash
# PreToolUse hook for `git push`: reviews every outgoing commit (messages +
# diffs) for work-related names before they leave the machine.
#   1. Denylist check via leak-guard.sh (deterministic).
#   2. A model reads the diff and flags real employer/client/product/person
#      names the denylist doesn't know about (see .claude/rules/generic-content.md).
# Exit 2 blocks the push and hands stderr to Claude. Fails closed.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}" || exit 2

block() { echo "review-push: $*" >&2; exit 2; }

outgoing=$(git log -p --format='=== commit %h%n%B' HEAD --not --remotes) || block "git log failed"
[ -n "$outgoing" ] || exit 0

echo "$outgoing" | .githooks/leak-guard.sh text "outgoing commits" || exit 2

prompt='You review a git diff for a PUBLIC personal repo of generic Claude Code skills.
Flag any real name that ties the content to a specific employer, client, coworker, company product or service, internal repo, internal hostname, or ticket ID.
Allowed: OlliTapio, olli@otl.fi, Anthropic/Claude, public tools and libraries (git, GitHub, npm, Playwright, etc.), credited public sources, and obvious placeholders (acme, example.com, PROJ-123, <repo>).
Reply with exactly one line: "OK" if nothing is flagged, otherwise "BLOCK: <file or commit>: <the name> - <why>" listing every hit.'

verdict=$(echo "$outgoing" | timeout 170 claude -p "$prompt" --model haiku --tools "" \
  --setting-sources user --no-session-persistence 2>&1) || block "name review failed to run: $verdict"

case "$verdict" in
  OK*) exit 0 ;;
  BLOCK*) block "outgoing commits name something specific; generalize it (amend/rebase), then push again.
$verdict" ;;
  *) block "unexpected name-review output: $verdict" ;;
esac
