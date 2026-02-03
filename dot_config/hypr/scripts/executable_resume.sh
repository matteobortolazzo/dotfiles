#!/bin/bash
# Resume script - re-enable display after lid open or suspend resume

# Re-enable the internal monitor with correct scale
hyprctl keyword monitor "eDP-1, preferred, auto, auto"

# Ensure DPMS is on
hyprctl dispatch dpms on

# Restore brightness (may have been dimmed before suspend)
brightnessctl -r 2>/dev/null || true
