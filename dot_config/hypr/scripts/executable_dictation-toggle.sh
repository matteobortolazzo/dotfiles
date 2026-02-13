#!/bin/bash

# Check cookie AND verify process is actually running
if [ -f /tmp/nerd-dictation.cookie ] && pgrep -f "nerd-dictation begin" > /dev/null 2>&1; then
    nerd-dictation end
    swayosd-client --custom-message "Dictation off" --custom-icon microphone-sensitivity-muted-symbolic
else
    # Clean up stale cookie if present
    rm -f /tmp/nerd-dictation.cookie
    nerd-dictation begin \
        --vosk-model-dir ~/models/vosk-model-en-us-0.22 \
        --simulate-input-tool WTYPE &
    disown
    swayosd-client --custom-message "Dictation on" --custom-icon microphone-sensitivity-high-symbolic
fi

pkill -RTMIN+8 waybar
