#!/bin/bash

if pgrep -x nerd-dictation > /dev/null; then
    nerd-dictation end
else
    nerd-dictation begin \
        --vosk-model-dir ~/models/vosk-model-small-en-us-0.15 \
        --output wtype &
fi

pkill -RTMIN+8 waybar
