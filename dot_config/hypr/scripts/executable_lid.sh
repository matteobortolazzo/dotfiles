#!/bin/bash
# Lid switch handler - different behavior based on power state

if grep -q 1 /sys/class/power_supply/AC0/online 2>/dev/null; then
    # On AC power: just disable internal display
    hyprctl keyword monitor "eDP-1, disable"
else
    # On battery: lock first (so hyprlock captures screen), then disable monitor and suspend
    loginctl lock-session
    sleep 0.3  # give hyprlock time to capture screenshot
    hyprctl keyword monitor "eDP-1, disable"
    systemctl suspend
fi
