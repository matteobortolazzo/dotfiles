#!/usr/bin/env bash
# Keeps the 16:9 dummy plug (DP-2) on only when something needs it.
#
#   desk monitor connected  -> DP-2 off  (sims and games can only land on DP-1)
#   desk monitor absent     -> DP-2 on   (monitor powered off / headless: niri
#                                         and Sunshine still have an output)
#   stream active           -> DP-2 on   (stream-prep.sh owns DP-1 meanwhile)
#
# The Odyssey drops off the bus when powered down (docs/gaming.md,
# "Monitorless"), so "absent from `niri msg outputs`" is the headless signal;
# niri lists connected outputs only, enabled or not.
#
#   dummy-output.sh            daemon; run by dummy-output.service
#   dummy-output.sh reconcile  apply the rule once (stream-prep.sh calls this)
#
# Re-checks on every DRM hotplug and every niri config reload: `niri msg
# output` changes are temporary and niri forgets them when that output's block
# in config.kdl changes, which would otherwise re-enable DP-2 behind our back.
set -uo pipefail

dummy="${SUNSHINE_STREAM_OUTPUT:-DP-2}"
desk="${SUNSHINE_DESK_OUTPUT:-DP-1}"
stream_marker="${XDG_RUNTIME_DIR:-/tmp}/sunshine-stream-prep.desk-off"

log() { printf 'dummy-output: %s\n' "$1"; }

reconcile() {
  local outs want is
  outs=$(niri msg --json outputs 2>/dev/null) || return 0
  # Not on this machine (laptop, unplugged dongle): nothing to manage.
  jq -e --arg o "$dummy" 'has($o)' <<<"$outs" >/dev/null || return 0

  if [[ -e "$stream_marker" ]]; then
    want=on
  elif jq -e --arg o "$desk" 'has($o)' <<<"$outs" >/dev/null; then
    want=off
  else
    want=on
  fi

  is=$(jq -r --arg o "$dummy" 'if .[$o].logical == null then "off" else "on" end' <<<"$outs")
  if [[ "$is" != "$want" ]]; then
    niri msg output "$dummy" "$want" >/dev/null 2>&1 && log "$dummy $want"
  fi
}

case "${1:-watch}" in
  reconcile)
    reconcile
    exit 0
    ;;
  watch) ;;
  *)
    echo "usage: $0 [watch|reconcile]" >&2
    exit 2
    ;;
esac

reconcile

# DRM hotplug. niri processes the same uevent itself, so give it a moment
# before asking it what is connected, and look again once the link settles.
udevadm monitor --udev --subsystem-match=drm 2>/dev/null | while read -r line; do
  [[ "$line" == *" change "* ]] || continue
  sleep 1; reconcile
  sleep 2; reconcile
done &

niri msg --json event-stream 2>/dev/null | while read -r line; do
  [[ "$line" == '{"ConfigLoaded"'* ]] && reconcile
done &

# Either pipe ending (niri gone, udevadm killed) is a reason to restart cleanly.
wait -n
exit 1
