#!/bin/bash
# Resume script - re-enable display after lid open or suspend resume

# Turn the screen back on
hyprctl dispatch dpms on eDP-1

# Restore brightness (may have been dimmed before suspend)
brightnessctl -r 2>/dev/null || true
