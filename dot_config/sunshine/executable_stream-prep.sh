#!/usr/bin/env bash
# Sunshine global_prep_cmd hook. Called as `stream-prep.sh on` before a stream
# and `stream-prep.sh off` after it.
#
# Two jobs, both of which fail silently and confusingly when absent:
#
#   1. Hold off DMS's idle lock. Otherwise the session locks out from under a
#      running game and the only way back is to walk to the desk — the exact
#      thing couch streaming exists to avoid.
#   2. Drop DP-1 from its native 32:9 mode to a 16:9 one for the duration of
#      the stream. Sunshine captures the output as-is, so a 5120x1440 grab
#      arrives at a 16:9 TV as a thin letterboxed strip with most of the panel
#      wasted. The Odyssey exposes true 16:9 modes (2560x1440@120,
#      1920x1080@120), and 1440p60 is where docs/gaming.md says to start.
#
# Always exits 0. Prep commands are run by Sunshine without a shell, so there
# is no `|| true` to lean on, and a non-zero exit aborts the stream before it
# starts. Under gamescope-session neither niri nor dms is running; both steps
# no-op rather than fail.
set -uo pipefail

# The mode to stream in. Must be one of the modes `niri msg outputs` lists for
# $output, verbatim — niri rejects anything else and leaves the current mode
# alone. Set it empty (or "off") to leave the output alone entirely and let
# Sunshine scale the native mode instead — which is the right setting once a
# 16:9 dummy plug makes the switch unnecessary.
output="${SUNSHINE_STREAM_OUTPUT:-DP-1}"
stream_mode="${SUNSHINE_STREAM_MODE:-2560x1440@119.998}"
state_file="${XDG_RUNTIME_DIR:-/tmp}/sunshine-stream-prep.mode"

have_niri() {
  command -v niri >/dev/null 2>&1 && [[ -n "${NIRI_SOCKET:-}" ]]
}

# `niri msg output <o> mode auto` does NOT mean "whatever config.kdl says" — it
# picks the connector's preferred mode, which on this panel is 3840x1080, not
# the configured 5120x1440. So the previous mode has to be recorded and played
# back verbatim.
current_mode() {
  niri msg --json outputs 2>/dev/null | python3 -c '
import json, sys
try:
    outs = json.load(sys.stdin)
except Exception:
    sys.exit(1)
o = outs.get(sys.argv[1])
if not o:
    sys.exit(1)
i = o.get("current_mode")
if not isinstance(i, int):
    sys.exit(1)
m = o["modes"][i]
print("{}x{}@{:.3f}".format(m["width"], m["height"], m["refresh_rate"] / 1000))
' "$output"
}

case "${1:-}" in
  on)
    if command -v dms >/dev/null 2>&1; then
      dms ipc call inhibit reason "Sunshine streaming" >/dev/null 2>&1
      dms ipc call inhibit enable >/dev/null 2>&1
    fi
    if have_niri && [[ -n "$stream_mode" && "$stream_mode" != "off" ]]; then
      mode="$(current_mode)" || mode=""
      if [[ -n "$mode" && "$mode" != "$stream_mode" ]]; then
        printf '%s\n' "$mode" >"$state_file"
        niri msg output "$output" mode "$stream_mode" >/dev/null 2>&1
      fi
    fi
    ;;
  off)
    if have_niri && [[ -r "$state_file" ]]; then
      niri msg output "$output" mode "$(cat "$state_file")" >/dev/null 2>&1
      rm -f "$state_file"
    fi
    if command -v dms >/dev/null 2>&1; then
      dms ipc call inhibit disable >/dev/null 2>&1
    fi
    ;;
esac

exit 0
