#!/bin/bash
tmux new-window -d -n "Git Sync" \
  "claude-sand --plugin-dir ~/Repos/muxwatch/plugin --plugin-dir ~/Repos/ccflow/ -- \"/sync\""
