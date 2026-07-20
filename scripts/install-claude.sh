#!/usr/bin/env bash
# Install Claude Code and copy config from tools/.claude (+ tools/.agents, which
# the skills/ symlinks point into) to the home directory.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# copy only git-tracked files so local runtime state (plugin repos, data, caches) is skipped
count=0
for dir in .claude .agents; do
  while IFS= read -r -d '' f; do
    rel="${f#tools/}"
    mkdir -p "$HOME/$(dirname "$rel")"
    cp -Pf "$REPO_ROOT/$f" "$HOME/$rel"
    count=$((count + 1))
  done < <(git -C "$REPO_ROOT" ls-files -z "tools/$dir")
done

# settings.json hardcodes the custom-local marketplace path
sed -i '' "s|\"/Users/vlad/.claude|\"$HOME/.claude|g" "$HOME/.claude/settings.json"

for tool in node rtk; do
  command -v "$tool" >/dev/null 2>&1 || echo "warning: $tool not found (used by the statusline / PreToolUse hook)"
done

echo "installed $count config files -> $HOME/.claude + $HOME/.agents"
