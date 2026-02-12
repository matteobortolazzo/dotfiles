#!/bin/bash

if [ -f /tmp/nerd-dictation.cookie ]; then
    echo '{"text": "dictating", "alt": "active", "tooltip": "Dictation active (Super+N to stop)", "class": "active"}'
else
    echo '{"text": "idle", "alt": "inactive", "tooltip": "Dictation off (Super+N to start)", "class": "inactive"}'
fi
