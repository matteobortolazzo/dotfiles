#!/bin/bash
session=$1
tmux kill-window -t "$session" 2>/dev/null || true
