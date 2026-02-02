#!/bin/bash
# Pre-commit hook - runs before git commit commands
# Copy to: .claude/hooks/precommit.sh

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only run for git commit commands
if [[ "$COMMAND" != git\ commit* ]]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# =============================================================================
# TODO: Replace with your project's check command
# Examples:
#   npm run check
#   bun run check
#   pnpm run lint && pnpm run typecheck
#   make check
# =============================================================================

echo "ERROR: precommit.sh not configured" >&2
echo "Edit .claude/hooks/precommit.sh and replace this with your check command" >&2
exit 2

# Uncomment and modify:
# if ! npm run check 2>&1; then
#   echo "Pre-commit checks failed." >&2
#   exit 2
# fi
# exit 0
