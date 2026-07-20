#!/usr/bin/env bash
# Fetch latest thermos plugin from cursor/plugins and convert it for Claude Code.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE_DIR="$REPO_ROOT/tools/.claude/plugins/custom-local"
TARGET="$MARKETPLACE_DIR/thermos"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --quiet --depth 1 --filter=blob:none --sparse https://github.com/cursor/plugins.git "$TMP/plugins"
git -C "$TMP/plugins" sparse-checkout set thermos --no-cone >/dev/null

SRC="$TMP/plugins/thermos"
[[ -f "$SRC/.cursor-plugin/plugin.json" ]] || { echo "upstream layout changed: no .cursor-plugin/plugin.json" >&2; exit 1; }

# Cursor -> Claude Code conversion
mv "$SRC/.cursor-plugin" "$SRC/.claude-plugin"
# Claude Code's manifest schema rejects these keys; both dirs are auto-discovered
jq 'del(.skills, .agents)' "$SRC/.claude-plugin/plugin.json" > "$TMP/plugin.json" && mv "$TMP/plugin.json" "$SRC/.claude-plugin/plugin.json"

find "$SRC/skills" "$SRC/agents" -name '*.md' -print0 | while IFS= read -r -d '' f; do
  # disable-model-invocation would hide the rubric skills from the Skill tool (subagents load them)
  sed -i '' '/^disable-model-invocation:/d' "$f"
  # Claude Code namespaces plugin agents/skills as thermos:<name>
  sed -i '' \
    -e 's/subagent_type: "thermo-nuclear/subagent_type: "thermos:thermo-nuclear/g' \
    -e 's/Load the `thermo-nuclear/Load the `thermos:thermo-nuclear/g' \
    "$f"
  # drop Cursor-specific shell/explore orchestration (best-effort, no-op if upstream rewords)
  perl -pi -e 's/in \*\*one\*\* message, run two `Task` calls in parallel — `subagent_type: "shell"` and `subagent_type: "explore"` — to collect/collect/g' "$f"
done

rm -rf "$TARGET"
cp -R "$SRC" "$TARGET"

# keep the marketplace entry's version/description in sync with upstream
VERSION="$(jq -r .version "$TARGET/.claude-plugin/plugin.json")"
DESCRIPTION="$(jq -r .description "$TARGET/.claude-plugin/plugin.json")"
jq --arg v "$VERSION" --arg d "$DESCRIPTION" \
  '(.plugins[] | select(.name == "thermos")) |= (.version = $v | .description = $d)' \
  "$MARKETPLACE_DIR/.claude-plugin/marketplace.json" > "$TMP/marketplace.json"
mv "$TMP/marketplace.json" "$MARKETPLACE_DIR/.claude-plugin/marketplace.json"

echo "thermos $VERSION -> $TARGET"
