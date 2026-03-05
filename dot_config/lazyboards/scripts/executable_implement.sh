#!/bin/bash
number=$1
session=$2
tags=$3

chrome_flag=""
case ",$tags," in
  *,Chrome,*) chrome_flag="--chrome" ;;
esac

tmux new-window -d -n "$session" \
  "claude $chrome_flag --plugin-dir ~/Repos/muxwatch/plugin --plugin-dir ~/Repos/ccflow/ -- \"/implement $number\""
