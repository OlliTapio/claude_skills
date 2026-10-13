# Claude Hooks Templates

Pre-configured hooks for Claude Code quality enforcement.

## Setup

```bash
# Create hooks directory in your project
mkdir -p .claude/hooks

# Copy files
cp settings.json .claude/settings.json
cp precommit.sh .claude/hooks/
cp lint-fix.sh .claude/hooks/

# Make executable
chmod +x .claude/hooks/*.sh
```

## Configure

Edit each script and replace the placeholder with your project's commands:

### precommit.sh

Runs **before** `git commit` commands. Blocks commit if checks fail.

```bash
# Replace the TODO section with:
if ! npm run check 2>&1; then
  echo "Pre-commit checks failed." >&2
  exit 2
fi
exit 0
```

### lint-fix.sh

Runs **after** every `Edit` or `Write` operation. Auto-fixes formatting.

```bash
# Replace the TODO section with:
npm run lint:fix
```

## How It Works

| Hook | Trigger | Purpose |
|------|---------|---------|
| `PreToolUse` + Bash | Before `git commit` | Block commits if checks fail |
| `PostToolUse` + Edit/Write | After file changes | Auto-fix lint/format issues |

## Exit Codes

- `0` - Success, allow operation
- `2` - Block the operation (for PreToolUse)
- Other non-zero - Error, but don't block
