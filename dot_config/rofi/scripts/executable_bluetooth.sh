#!/usr/bin/env bash
# Self-contained bluetooth manager using rofi + bluetoothctl
#
# bluetoothctl subcommands return nothing when run non-interactively on some
# systems — pipe through interactive mode as a workaround.

ROFI_THEME="$HOME/.config/rofi/launchers/apps.rasi"

rofi_menu() {
    rofi -dmenu -theme "$ROFI_THEME" -p "Bluetooth" "$@"
}

# Run a bluetoothctl command via interactive pipe (works around empty output)
btctl() {
    echo -e "$1\nquit" | bluetoothctl 2>/dev/null
}

is_powered() {
    btctl "show" | grep -q "Powered: yes"
}

is_scanning() {
    btctl "show" | grep -q "Discovering: yes"
}

is_connected() {
    btctl "info $1" | grep -q "Connected: yes"
}

toggle_power() {
    if is_powered; then
        btctl "power off"
    else
        rfkill unblock bluetooth 2>/dev/null
        btctl "power on"
        sleep 1
    fi
}

toggle_scan() {
    if is_scanning; then
        btctl "scan off"
    else
        # Start scan in background — bluetoothctl scan blocks
        bluetoothctl --timeout 5 scan on &>/dev/null &
        disown
        sleep 1
    fi
}

toggle_connection() {
    local mac="$1"
    if is_connected "$mac"; then
        btctl "disconnect $mac"
    else
        btctl "connect $mac"
    fi
    sleep 1
}

device_menu() {
    local mac="$1"
    local name
    name=$(btctl "info $mac" | grep "Alias:" | sed 's/.*Alias: //')

    local connected_label
    if is_connected "$mac"; then
        connected_label="󰂱  Disconnect"
    else
        connected_label="󰂯  Connect"
    fi

    local choice
    choice=$(printf '%s\n%s' "$connected_label" "← Back" | rofi_menu -p "$name")

    case "$choice" in
        *Connect|*Disconnect)
            toggle_connection "$mac"
            show_menu
            ;;
        "← Back")
            show_menu
            ;;
    esac
}

show_menu() {
    if ! is_powered; then
        local choice
        choice=$(printf '%s\n%s' "󰂯  Turn On" "Exit" | rofi_menu)
        case "$choice" in
            *"Turn On"*)
                toggle_power
                show_menu
                ;;
        esac
        return
    fi

    # Build device list from paired/known devices
    local devices
    devices=$(btctl "devices" | grep "^Device " | while read -r _ mac name; do
        if is_connected "$mac"; then
            echo "󰂱  $name|$mac"
        else
            echo "󰂴  $name|$mac"
        fi
    done)

    local scan_label
    if is_scanning; then
        scan_label="󰂰  Stop Scan"
    else
        scan_label="󰂰  Scan"
    fi

    local menu=""
    if [[ -n "$devices" ]]; then
        menu=$(echo "$devices" | cut -d'|' -f1)
        menu=$(printf '%s\n%s\n%s\n%s' "$menu" "$scan_label" "󰂲  Turn Off" "Exit")
    else
        menu=$(printf '%s\n%s\n%s' "$scan_label" "󰂲  Turn Off" "Exit")
    fi

    local choice
    choice=$(echo "$menu" | rofi_menu)

    case "$choice" in
        *"Turn Off"*)
            toggle_power
            ;;
        *"Scan"*|*"Stop Scan"*)
            toggle_scan
            show_menu
            ;;
        "Exit"|"")
            return
            ;;
        *)
            # Device selected — find its MAC
            local selected_name
            selected_name=$(echo "$choice" | sed 's/^[^ ]* *//')
            local mac
            mac=$(echo "$devices" | grep "|" | while IFS='|' read -r label addr; do
                label_name=$(echo "$label" | sed 's/^[^ ]* *//')
                if [[ "$label_name" == "$selected_name" ]]; then
                    echo "$addr"
                    break
                fi
            done)
            if [[ -n "$mac" ]]; then
                device_menu "$mac"
            fi
            ;;
    esac
}

show_menu
