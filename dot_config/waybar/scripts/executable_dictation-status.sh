#!/bin/bash

# Query HyprVoice daemon status for Waybar

# Get current default audio source name
mic_name=$(wpctl status 2>/dev/null | awk '
    /^Audio/        { in_audio = 1; next }
    /^Video/        { exit }
    in_audio && /Sources:/ { in_sources = 1; next }
    in_sources && /^[│ ]*[├└]─/ { exit }
    in_sources && /\*/ && /[0-9]+\./ {
        line = $0
        gsub(/^[│ ]*\*?[[:space:]]*/, "", line)
        sub(/^[0-9]+\.[[:space:]]*/, "", line)
        sub(/[[:space:]]*\[vol:.*/, "", line)
        sub(/[[:space:]]+$/, "", line)
        print line
        exit
    }
')
mic_line="${mic_name:+\\nMic: $mic_name}"

status_line=$(hyprvoice status 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$status_line" ]; then
    echo "{\"text\": \"off\", \"alt\": \"inactive\", \"tooltip\": \"HyprVoice not running${mic_line}\", \"class\": \"inactive\"}"
    exit 0
fi

# Parse: "STATUS status=<state>"
state="${status_line#STATUS status=}"
state="${state%%$'\n'*}"

case "$state" in
    recording)
        echo "{\"text\": \"recording\", \"alt\": \"active\", \"tooltip\": \"Recording... (Super+N to stop)${mic_line}\", \"class\": \"active\"}"
        ;;
    transcribing|injecting)
        echo "{\"text\": \"processing\", \"alt\": \"active\", \"tooltip\": \"Processing speech...${mic_line}\", \"class\": \"active\"}"
        ;;
    *)
        echo "{\"text\": \"idle\", \"alt\": \"inactive\", \"tooltip\": \"HyprVoice ready (Super+N to start)${mic_line}\\nRight-click: audio settings\", \"class\": \"inactive\"}"
        ;;
esac
