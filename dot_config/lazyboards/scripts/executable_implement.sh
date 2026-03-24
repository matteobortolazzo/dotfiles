#!/bin/bash
number=$1
session=$2
tags=$3

tmux new-window -d -n "$session" \
  "claude-sand --plugin-dir ~/Repos/muxwatch/plugin --plugin-dir ~/Repos/ccflow/ -- \"/implement $number\""
