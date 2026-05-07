#!/bin/bash
# Lid switch handler - different behavior based on power state

if grep -q 1 /sys/class/power_supply/AC0/online 2>/dev/null; then
    # On AC: just turn the internal display off (paired with dpms on in resume.sh)
    hyprctl dispatch dpms off eDP-1
else
    # On battery: lock (so noctalia captures the screen), then suspend.
    # Don't dpms off here — the kernel powers the panel down during suspend,
    # and an explicit dpms off survives resume as a stuck black screen if the
    # lid:off bindl misses while libinput re-initializes.
    qs -c noctalia-shell ipc call lockScreen lock
    sleep 0.3  # give noctalia time to capture screenshot
    systemctl suspend
fi
