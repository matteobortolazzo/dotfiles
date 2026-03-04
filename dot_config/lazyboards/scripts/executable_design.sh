#!/bin/bash
number=$1
session=$2
tmux new-window -d -n "$session" \
  "claude --plugin-dir ~/Repos/muxwatch/plugin --plugin-dir ~/Repos/ccflow/ -- \"/design $number\""
