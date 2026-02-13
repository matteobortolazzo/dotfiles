#!/bin/bash
# Lock screen on idle — only when on battery
if grep -q 1 /sys/class/power_supply/AC0/online 2>/dev/null; then
    exit 0  # on AC power, skip lock
fi
loginctl lock-session
