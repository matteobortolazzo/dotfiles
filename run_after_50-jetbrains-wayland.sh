#!/bin/sh
set -eu

config_home="${XDG_CONFIG_HOME:-"$HOME/.config"}"
jetbrains_config="$config_home/JetBrains"

[ -d "$jetbrains_config" ] || exit 0

find "$jetbrains_config" -mindepth 2 -maxdepth 2 -type f -name '*64.vmoptions' | while IFS= read -r file; do
    case "$(basename "$file")" in
        idea64.vmoptions|clion64.vmoptions|datagrip64.vmoptions|goland64.vmoptions|phpstorm64.vmoptions|pycharm64.vmoptions|rider64.vmoptions|rubymine64.vmoptions|rustrover64.vmoptions|webide64.vmoptions|webstorm64.vmoptions|writerside64.vmoptions) ;;
        *) continue ;;
    esac

    if ! grep -qxF -- '-Dawt.toolkit.name=WLToolkit' "$file"; then
        printf '\n-Dawt.toolkit.name=WLToolkit\n' >> "$file"
    fi

    if ! grep -qxF -- '-Dsun.java2d.uiScale.enabled=true' "$file"; then
        printf -- '-Dsun.java2d.uiScale.enabled=true\n' >> "$file"
    fi
done
