#!/usr/bin/env bash
set -euo pipefail

notify() { notify-send 'Screen mirroring' "$*" || true; }
trap 'notify "Could not toggle mirroring. Check journalctl --user -u niri-screen-mirror."' ERR

# Serialize presses, including while the picker is open. Systemd owns the
# process so stopping never relies on a stale or reused PID.
exec 9>"${XDG_RUNTIME_DIR:?}/niri-screen-mirror.lock"
flock -n 9 || exit 0
unit=niri-screen-mirror.service
if systemctl --user is-active --quiet "$unit"; then
    systemctl --user stop "$unit"
    notify 'Mirroring stopped.'
    exit 0
fi

for dependency in wl-mirror jq fuzzel; do
    if ! command -v "$dependency" >/dev/null; then
        notify "Missing $dependency. Install the desktop packages first."
        exit 1
    fi
done

outputs=$(niri msg --json outputs)
source=$(jq -r '[.[] | select(.logical != null) | .name | select(test("^(eDP|LVDS|DSI)-"))][0] // empty' <<<"$outputs")
if [[ -z $source ]]; then
    source=$(niri msg --json focused-output | jq -r '.name // empty')
fi
if [[ -z $source ]]; then
    notify 'No active source display found.'
    exit 0
fi
mapfile -t targets < <(jq -r --arg source "$source" '.[] | select(.logical != null and .name != $source) | .name' <<<"$outputs")
if ((${#targets[@]} == 0)); then
    notify 'Connect and enable an HDMI or USB-C display first.'
    exit 0
elif ((${#targets[@]} == 1)); then
    target=${targets[0]}
else
    target=$(printf '%s\n' "${targets[@]}" | fuzzel --dmenu --prompt 'Mirror to: ') || exit 0
    printf '%s\n' "${targets[@]}" | grep -Fxq -- "$target" || exit 0
fi

# Pass the session environment explicitly to the user service manager.
systemd-run --user --collect --unit="$unit" \
    --setenv="WAYLAND_DISPLAY=${WAYLAND_DISPLAY:?}" \
    --setenv="XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
    -- wl-mirror --title 'Laptop screen mirror' \
    --fullscreen-output "$target" --scaling fit "$source"
notify "Mirroring $source to $target. Super+Shift+P stops mirroring."
