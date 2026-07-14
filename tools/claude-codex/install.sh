#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="docker"
case "${1:-}" in
  ""|--docker) MODE="docker" ;;
  --native) MODE="native" ;;
  *) echo "Usage: $0 [--docker|--native]" >&2; exit 2 ;;
esac

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-codex"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/claude-codex"
BIN_DIR="$HOME/.local/bin"
CODEX_AUTH_FILE="$HOME/.codex/auth.json"
export CODEX_AUTH_FILE
[[ -s "$CODEX_AUTH_FILE" ]] || {
  echo "Error: Codex OAuth is missing at $CODEX_AUTH_FILE. Run 'codex login' first." >&2
  exit 1
}
mkdir -p "$CONFIG_DIR" "$DATA_DIR/chatgpt" "$BIN_DIR"
chmod 700 "$CONFIG_DIR" "$DATA_DIR" "$DATA_DIR/chatgpt"

if [[ ! -s "$CONFIG_DIR/master-key" ]]; then
  printf 'sk-local-%s\n' "$(openssl rand -hex 16)" > "$CONFIG_DIR/master-key"
  chmod 600 "$CONFIG_DIR/master-key"
fi
printf '%s\n' "$MODE" > "$CONFIG_DIR/runtime"
ln -sfn "$ROOT/claude-codex" "$BIN_DIR/claude-codex"

if [[ "$MODE" == "docker" ]]; then
  command -v docker >/dev/null || { echo "Error: Docker is required." >&2; exit 1; }
  export LITELLM_MASTER_KEY="$(<"$CONFIG_DIR/master-key")"
  export CLAUDE_CODEX_DATA_DIR="$DATA_DIR"
  docker compose --project-directory "$ROOT" build proxy
else
  command -v uv >/dev/null || { echo "Error: uv is required." >&2; exit 1; }
  uv sync --project "$ROOT" --locked
  uv run --project "$ROOT" python "$ROOT/patch_litellm.py"
fi

echo
echo "Installed claude-codex using the $MODE runtime."
echo "Ensure $BIN_DIR is on PATH, then run:"
echo "  claude-codex"
echo "The proxy will reuse and refresh the OAuth session from $CODEX_AUTH_FILE."
