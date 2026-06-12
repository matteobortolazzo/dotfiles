#!/bin/bash
number=$1
session=$2
tmux new-window -d -n "$session" \
  "claude --model claude-opus-4-6 -- \"/refine $number\""
