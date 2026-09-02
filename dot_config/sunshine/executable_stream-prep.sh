#!/usr/bin/env bash
# Sunshine global_prep_cmd hook. Called as `stream-prep.sh on` before a stream
# and `stream-prep.sh off` after it.
#
# Two jobs, both of which fail silently and confusingly when absent:
#
#   1. Hold off DMS's idle lock. Otherwise the session locks out from under a
#      running game and the only way back is to walk to the desk — the exact
#      thing couch streaming exists to avoid.
#   2. Disable the desk monitor (DP-1) for the duration of the stream, so the
#      16:9 dummy plug (DP-2) is the only output: Sunshine's monitor pick and
#      Steam's window placement then have exactly one answer. Only done when
#      the dummy is actually present — with it unplugged, turning DP-1 off
#      would leave the session with zero outputs.
#
# This replaced the old SUNSHINE_STREAM_MODE mode-switch: switching DP-1 to a
# 16:9 mode broke every XWayland game (xwayland-satellite does not propagate
# the mode change, so Proton titles rendered at the stale 5120px width). The
# dummy plug is a permanently-16:9 output, so nothing needs switching.
#
# Always exits 0. Prep commands are run by Sunshine without a shell, so there
# is no `|| true` to lean on, and a non-zero exit aborts the stream before it
# starts. Under gamescope-session neither niri nor dms is running; both steps
# no-op rather than fail.
set -uo pipefail

stream_output="${SUNSHINE_STREAM_OUTPUT:-DP-2}"
desk_output="${SUNSHINE_DESK_OUTPUT:-DP-1}"
state_file="${XDG_RUNTIME_DIR:-/tmp}/sunshine-stream-prep.desk-off"

have_niri() {
  command -v niri >/dev/null 2>&1 && [[ -n "${NIRI_SOCKET:-}" ]]
}

output_present() {
  niri msg --json outputs 2>/dev/null | python3 -c '
import json, sys
try:
    outs = json.load(sys.stdin)
except Exception:
    sys.exit(1)
sys.exit(0 if sys.argv[1] in outs else 1)
' "$1"
}

case "${1:-}" in
  on)
    if command -v dms >/dev/null 2>&1; then
      dms ipc call inhibit reason "Sunshine streaming" >/dev/null 2>&1
      dms ipc call inhibit enable >/dev/null 2>&1
    fi
    if have_niri && output_present "$stream_output" && output_present "$desk_output"; then
      if niri msg output "$desk_output" off >/dev/null 2>&1; then
        touch "$state_file"
      fi
    fi
    ;;
  off)
    if have_niri && [[ -e "$state_file" ]]; then
      niri msg output "$desk_output" on >/dev/null 2>&1
      rm -f "$state_file"
    fi
    if command -v dms >/dev/null 2>&1; then
      dms ipc call inhibit disable >/dev/null 2>&1
    fi
    ;;
esac

exit 0
