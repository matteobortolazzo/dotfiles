#!/bin/bash
set -euo pipefail

# Exit silently if not in tmux
[ -n "${TMUX_PANE:-}" ] || exit 0

# States: running, input, done, (unset = neutral)
set_state() {
  case "$1" in
    running|input|done) tmux set-option -w -t "$TMUX_PANE" @claude-state "$1" ;;
    *)                  tmux set-option -wu -t "$TMUX_PANE" @claude-state 2>/dev/null || true ;;
  esac
}

mode="${1:-clear}"

case "$mode" in
  --post-tool)
    # Only react to tools that need user attention; ignore everything else
    # so the state stays "running" while Claude works.
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
        set_state running
        ;;
    esac
    ;;
  --stop)
    set_state done
    notify-send 'Claude Code' 'Task completed' 2>/dev/null || true
    ;;
  running|input|done)
    set_state "$mode"
    ;;
  *)
    set_state clear
    ;;
esac
