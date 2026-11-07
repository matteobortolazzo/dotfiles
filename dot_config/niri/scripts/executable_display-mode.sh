#!/usr/bin/env bash
# Windows-style "Project" (Win+P) picker for niri: Extend / Duplicate /
# Laptop only / External only. Output on/off goes through `niri msg output`,
# which is temporary and survives until the output section of the config
# changes. Mirroring is a fullscreen wl-mirror window owned by a transient
# user unit so a later pick can always stop it.
set -euo pipefail

notify() { notify-send 'Display mode' "$*" || true; }
trap 'notify "Could not switch display mode. Check journalctl --user -u niri-screen-mirror."' ERR

# Serialize presses, including while the picker is open.
exec 9>"${XDG_RUNTIME_DIR:?}/niri-screen-mirror.lock"
flock -n 9 || exit 0
unit=niri-screen-mirror.service

for dependency in niri jq fuzzel; do
    if ! command -v "$dependency" >/dev/null; then
        notify "Missing $dependency. Install the desktop packages first."
        exit 1
    fi
done

outputs=$(niri msg --json outputs)
# Internal panel = source. Without one (desktop), the focused output plays that role.
internal=$(jq -r '[.[] | .name | select(test("^(eDP|LVDS|DSI)-"))][0] // empty' <<<"$outputs")
if [[ -z $internal ]]; then
    internal=$(niri msg --json focused-output | jq -r '.name // empty')
fi
if [[ -z $internal ]]; then
    notify 'No display found.'
    exit 0
fi
mapfile -t externals < <(jq -r --arg i "$internal" '.[] | select(.name != $i) | .name' <<<"$outputs")
if ((${#externals[@]} == 0)); then
    notify 'Connect an HDMI or USB-C display first.'
    exit 0
fi

is_on() { jq -e --arg n "$1" '.[] | select(.name == $n) | .logical != null' <<<"$outputs" >/dev/null; }
set_output() { niri msg output "$1" "$2" >/dev/null; }

# Work out the current mode so the picker can mark it.
mirroring=false
systemctl --user is-active --quiet "$unit" && mirroring=true
internal_on=false; is_on "$internal" && internal_on=true
external_on=false
for o in "${externals[@]}"; do is_on "$o" && external_on=true; done
current=extend
if $mirroring; then current=mirror
elif ! $external_on; then current=internal
elif ! $internal_on; then current=external
fi

label() { if [[ $1 == "$current" ]]; then printf '%s  (current)\n' "$2"; else printf '%s\n' "$2"; fi; }
choice=$(
    {
        label extend   'Extend'
        label mirror   'Duplicate (mirror)'
        label internal 'Laptop screen only'
        label external 'External screen only'
    } | fuzzel --dmenu --prompt 'Display: ' --lines 4
) || exit 0
choice=${choice%  (current)}

stop_mirror() {
    if $mirroring; then systemctl --user stop "$unit"; fi
}
enable_all() {
    $internal_on || set_output "$internal" on
    for o in "${externals[@]}"; do is_on "$o" || set_output "$o" on; done
}

case $choice in
    'Extend')
        stop_mirror
        enable_all
        notify 'Extended desktop.'
        ;;
    'Laptop screen only')
        stop_mirror
        $internal_on || set_output "$internal" on
        for o in "${externals[@]}"; do set_output "$o" off; done
        notify "Only $internal is on."
        ;;
    'External screen only')
        stop_mirror
        for o in "${externals[@]}"; do is_on "$o" || set_output "$o" on; done
        set_output "$internal" off
        notify "Only ${externals[*]} on."
        ;;
    'Duplicate (mirror)')
        if $mirroring; then exit 0; fi
        if ! command -v wl-mirror >/dev/null; then
            notify 'Missing wl-mirror. Install the desktop packages first.'
            exit 1
        fi
        enable_all
        if ((${#externals[@]} == 1)); then
            target=${externals[0]}
        else
            target=$(printf '%s\n' "${externals[@]}" | fuzzel --dmenu --prompt 'Mirror to: ') || exit 0
            printf '%s\n' "${externals[@]}" | grep -Fxq -- "$target" || exit 0
        fi
        # Pass the session environment explicitly to the user service manager.
        systemd-run --user --collect --unit="$unit" \
            --setenv="WAYLAND_DISPLAY=${WAYLAND_DISPLAY:?}" \
            --setenv="XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
            -- wl-mirror --title 'Laptop screen mirror' \
            --fullscreen-output "$target" --scaling fit "$internal"
        notify "Mirroring $internal to $target."
        ;;
    *) exit 0 ;;
esac
