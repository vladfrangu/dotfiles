#!/usr/bin/env bash
# Install Claude Code and copy shared agent config from tools/ to the home
# directory. Agent-specific skill directories point into ~/.agents/skills.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

if ! command -v claudewho >/dev/null 2>&1; then
  claudewho_dir="$HOME/Development/claudewho"

  if [[ ! -d "$claudewho_dir/.git" ]]; then
    mkdir -p "$HOME/Development"
    git clone https://github.com/frisble/claudewho.git "$claudewho_dir"
  fi

  chmod +x "$claudewho_dir/bin/claudewho"
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$claudewho_dir/bin/claudewho" "$HOME/.local/bin/claudewho"
fi

# copy only git-tracked files so local runtime state (plugin repos, data, caches) is skipped
count=0
for dir in .claude .agents .codex; do
  while IFS= read -r -d '' f; do
    rel="${f#tools/}"
    mkdir -p "$HOME/$(dirname "$rel")"
    cp -Pf "$REPO_ROOT/$f" "$HOME/$rel"
    count=$((count + 1))
  done < <(git -C "$REPO_ROOT" ls-files -z "tools/$dir")
done

# Link the shared skill into agent-specific global directories when those
# clients or Claude profiles already exist. Zed reads ~/.agents/skills directly.
for agent_home in "$HOME"/.claudewho-* "$HOME"/.cursor "$HOME"/.copilot; do
  [[ -d "$agent_home" ]] || continue
  mkdir -p "$agent_home/skills"
  ln -sfn "$HOME/.agents/skills/unslop" "$agent_home/skills/unslop"
done

if [[ -d "$HOME/.config/opencode" ]]; then
  mkdir -p "$HOME/.config/opencode/skills"
  ln -sfn "$HOME/.agents/skills/unslop" "$HOME/.config/opencode/skills/unslop"
fi

# settings.json hardcodes the custom-local marketplace path
sed -i '' "s|\"/Users/vlad/.claude|\"$HOME/.claude|g" "$HOME/.claude/settings.json"

for tool in node rtk; do
  command -v "$tool" >/dev/null 2>&1 || echo "warning: $tool not found (used by the statusline / PreToolUse hook)"
done

echo "installed $count config files -> shared Claude and Codex configuration"
