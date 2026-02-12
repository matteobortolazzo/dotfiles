#!/bin/bash

if [ -f /tmp/nerd-dictation.cookie ]; then
    nerd-dictation end
    swayosd-client --custom-message "Dictation off" --custom-icon microphone-sensitivity-muted-symbolic
else
    nerd-dictation begin \
        --vosk-model-dir ~/models/vosk-model-en-us-0.22 \
        --simulate-input-tool WTYPE &
    disown
    swayosd-client --custom-message "Dictation on" --custom-icon microphone-sensitivity-high-symbolic
fi

pkill -RTMIN+8 waybar
