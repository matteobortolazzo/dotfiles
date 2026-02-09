#!/bin/bash
set -euo pipefail

state="${1:-clear}"

# Exit silently if not in tmux
[ -n "${TMUX_PANE:-}" ] || exit 0

case "$state" in
  input|done) tmux set-option -w -t "$TMUX_PANE" @claude-state "$state" ;;
  *)          tmux set-option -wu -t "$TMUX_PANE" @claude-state 2>/dev/null || true ;;
esac
