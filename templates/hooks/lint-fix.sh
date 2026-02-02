#!/bin/bash
# Post-edit hook - auto-fixes lint issues after file edits
# Copy to: .claude/hooks/lint-fix.sh

cd "$CLAUDE_PROJECT_DIR"

# =============================================================================
# TODO: Replace with your project's auto-fix command
# Examples:
#   npm run lint:fix
#   bun run check:fix
#   pnpm run format
#   make format
# =============================================================================

echo "ERROR: lint-fix.sh not configured" >&2
echo "Edit .claude/hooks/lint-fix.sh and replace this with your fix command" >&2
exit 1

# Uncomment and modify:
# npm run lint:fix
