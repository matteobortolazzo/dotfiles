#!/usr/bin/env bash
# Usage: focus-or-spawn.sh <app-id-regex> <launch-cmd> [args...]
#
# If a niri window's app_id matches <app-id-regex> (case-insensitive),
# focus the first match. Otherwise exec the launch command.
#
# Works around Firefox/Zen-style "second launch opens a new window in
# the existing process" by ensuring we never re-launch when a window
# already exists.

set -euo pipefail

pattern="$1"
shift

id=$(niri msg --json windows | jq -r --arg p "$pattern" '
  [.[] | select((.app_id // "") | test($p; "i"))][0].id // empty
')

if [ -n "$id" ]; then
    niri msg action focus-window --id "$id"
else
    exec "$@"
fi
