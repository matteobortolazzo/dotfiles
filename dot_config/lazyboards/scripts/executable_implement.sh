#!/bin/bash
number=$1
session=$2
tags=$3

if [[ -z "${TMUX_PANE:-}" ]]; then
  echo "Implement must be started from inside tmux" >&2
  exit 1
fi

target_session=$(tmux display-message -p -t "$TMUX_PANE" '#{session_id}')
session_grouped=$(tmux display-message -p -t "$TMUX_PANE" '#{session_grouped}')

if [[ "$session_grouped" == "1" ]]; then
  session_group=$(tmux display-message -p -t "$TMUX_PANE" '#{session_group}')
  echo "Implement refused: tmux session $target_session belongs to shared group $session_group" >&2
  exit 1
fi

tmux new-window -d -t "$target_session:" -n "$session" \
  "claude --model claude-opus-4-6 -- \"/implement $number\""
