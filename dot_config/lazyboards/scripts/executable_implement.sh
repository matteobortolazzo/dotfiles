#!/bin/bash
number=$1
session=$2
tags=$3

TMUX_ENV_ARGS=()
[[ -n "${CONTEXT7_API_KEY:-}" ]] && TMUX_ENV_ARGS+=(-e "CONTEXT7_API_KEY=$CONTEXT7_API_KEY")

tmux new-window -d -n "$session" "${TMUX_ENV_ARGS[@]}" \
  "claude-sand -- \"/implement $number\""
