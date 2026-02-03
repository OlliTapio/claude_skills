# Claude Skills Repository

Personal Claude Code skills for OlliTapio.

## Updating Skills

When modifying skills in this repo:

1. Edit the skill files directly in `skills/<skill-name>/SKILL.md`
2. After making changes, commit and push to this repo:
   ```bash
   git add -A && git commit -m "Update <skill-name>: <brief description>" && git push
   ```

The skills are symlinked from `~/.claude/skills/` to this repo, so changes take effect immediately.

## Adding New Skills

1. Create a new directory: `skills/<skill-name>/`
2. Add `SKILL.md` with the skill definition
3. Create the symlink: `ln -s /Users/olli/repositories/claude_skills/skills/<skill-name> ~/.claude/skills/<skill-name>`
4. Commit and push

## Current Skills

- **plan** - TDD-based planning workflow (WIP)
- **pr-review** - Review GitHub PRs with inline comments
- **worktree-planner** - Plan and implement changes in isolated git worktrees

## Templates

Reusable configuration templates in `templates/`:

### Hooks (`templates/hooks/`)

Pre-configured Claude Code hooks for quality enforcement:

```bash
# Copy to your project
mkdir -p .claude/hooks
cp templates/hooks/settings.json .claude/
cp templates/hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
```

- **precommit.sh** - Blocks `git commit` if checks fail
- **lint-fix.sh** - Auto-fixes lint after file edits

See `templates/hooks/README.md` for configuration.
