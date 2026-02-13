#!/bin/bash

# Toggle HyprVoice recording and refresh Waybar status
hyprvoice toggle
pkill -RTMIN+8 waybar
