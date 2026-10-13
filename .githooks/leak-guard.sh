#!/usr/bin/env bash
# Blocks work-related content from entering this personal repo.
#
# Denylisted terms live in .githooks/denylist.local (gitignored, one
# case-insensitive extended regex per line) so the terms themselves never
# get committed. Missing denylist = blocked: fail closed on a fresh clone.
#
# Usage: leak-guard.sh staged | message <file> | push <remote-ref-ranges...>
set -euo pipefail

ALLOWED_EMAILS='^(olli@otl\.fi|OlliTapio@users\.noreply\.github\.com|noreply@anthropic\.com)$'
root=$(git rev-parse --show-toplevel)
denylist="$root/.githooks/denylist.local"

die() { echo "leak-guard: $*" >&2; exit 1; }

[ -s "$denylist" ] || die "missing $denylist — create it with one work term (regex) per line."
pattern=$(grep -v '^\s*\(#\|$\)' "$denylist" | paste -sd'|' -)
[ -n "$pattern" ] || die "$denylist has no patterns."

check_email() { # <label> <email>
  echo "$2" | grep -qiE "$ALLOWED_EMAILS" || die "$1 email '$2' is not a personal address."
}

added_lines() { grep "^+" | grep -v "^+++" || true; }

check_text() { # <label>, text on stdin
  local hits
  hits=$(grep -inE "$pattern" || true)
  [ -z "$hits" ] || die "work-related term in $1:"$'\n'"$hits"
}

case "${1:-}" in
  staged)
    check_email author "$(git var GIT_AUTHOR_IDENT | sed 's/.*<\(.*\)>.*/\1/')"
    check_email committer "$(git var GIT_COMMITTER_IDENT | sed 's/.*<\(.*\)>.*/\1/')"
    git diff --cached --name-only --diff-filter=ACMR | check_text "staged file names"
    git diff --cached -U0 --diff-filter=ACMR | added_lines | check_text "staged changes"
    ;;
  message)
    { grep -v "^#" "$2" || true; } | check_text "commit message"
    ;;
  push)
    shift
    for range in "$@"; do
      while read -r sha; do
        while read -r label email; do check_email "$label of $sha" "$email"; done \
          < <(git show -s --format=$'author %ae\ncommitter %ce' "$sha")
        git show -s --format=%B "$sha" | check_text "message of $sha"
        git show --format= "$sha" | added_lines | check_text "diff of $sha"
        git show --format= --name-only "$sha" | check_text "file names of $sha"
      done < <(git rev-list $range)  # unquoted: range may be "<sha> --not --remotes"
    done
    ;;
  *) die "usage: leak-guard.sh staged | message <file> | push <ranges...>" ;;
esac
