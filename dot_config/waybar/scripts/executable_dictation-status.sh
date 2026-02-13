#!/bin/bash

if [ -f /tmp/nerd-dictation.cookie ] && pgrep -f "nerd-dictation begin" > /dev/null 2>&1; then
    echo '{"text": "dictating", "alt": "active", "tooltip": "Dictation active (Super+N to stop)", "class": "active"}'
else
    echo '{"text": "idle", "alt": "inactive", "tooltip": "Dictation off (Super+N to start)", "class": "inactive"}'
fi
