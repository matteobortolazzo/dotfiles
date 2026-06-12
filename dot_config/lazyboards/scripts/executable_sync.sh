#!/bin/bash
tmux new-window -d -n "Git Sync" \
  "claude --model claude-opus-4-6 -- \"/sync\""
