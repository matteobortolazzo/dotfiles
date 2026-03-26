#!/bin/bash
number=$1
session=$2
tags=$3

tmux new-window -d -n "$session" \
  "claude-sand -- \"/implement $number\""
