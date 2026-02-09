#!/bin/bash
set -euo pipefail

# Exit silently if not in tmux
[ -n "${TMUX_PANE:-}" ] || exit 0

set_state() {
  case "$1" in
    input|done) tmux set-option -w -t "$TMUX_PANE" @claude-state "$1" ;;
    *)          tmux set-option -wu -t "$TMUX_PANE" @claude-state 2>/dev/null || true ;;
  esac
}

mode="${1:-clear}"

case "$mode" in
  --post-tool)
    # Read JSON from stdin, extract tool_name
    tool_name=$(jq -r '.tool_name // empty')
    case "$tool_name" in
      AskUserQuestion)
        set_state input
        notify-send 'Claude Code' 'Question needs your answer' 2>/dev/null || true
        ;;
      ExitPlanMode)
        set_state input
        notify-send 'Claude Code' 'Plan ready for review' 2>/dev/null || true
        ;;
      *)
        set_state clear
        ;;
    esac
    ;;
  --stop)
    # If user still needs to respond, don't overwrite with done
    current=$(tmux show-option -wqv -t "$TMUX_PANE" @claude-state 2>/dev/null || true)
    if [ "$current" != "input" ]; then
      set_state done
      notify-send 'Claude Code' 'Task completed' 2>/dev/null || true
    fi
    ;;
  input|done)
    set_state "$mode"
    ;;
  *)
    set_state clear
    ;;
esac
