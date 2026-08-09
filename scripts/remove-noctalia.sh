#!/usr/bin/env bash
# Swap noctalia-qs for upstream quickshell as DMS's shell runtime, then drop the
# hotfix tree the wrapper only needs while noctalia-qs is installed.
#
# One-shot migration, run by hand — deliberately not a run_once_ script, since
# the package swap is interactive and should not fire during `chezmoi apply`.
#
# Run this BEFORE the next `chezmoi apply`: arch-desktop.txt now lists
# quickshell, and pacman --noconfirm would abort the whole desktop transaction
# on the noctalia-qs conflict rather than resolving it.
#
# Once it has succeeded on every machine, this script and the hotfix machinery
# (run_after_48-dms-noctalia-hotfix.sh.tmpl, dot_local/bin/executable_dms-run-session,
# dot_config/systemd/user/dms.service.d/override.conf) can all be deleted.
set -euo pipefail

hotfix_base="$HOME/.local/share/dms-shell-hotfix"

command -v pacman >/dev/null 2>&1 || { echo "not an Arch/CachyOS host — nothing to do"; exit 1; }

echo "==> current shell runtime"
quickshell --version 2>/dev/null || echo "  (no quickshell binary on PATH)"

if pacman -Qq noctalia-qs >/dev/null 2>&1; then
    echo "==> what depends on noctalia-qs"
    pactree -r noctalia-qs 2>/dev/null || pacman -Qi noctalia-qs | grep -i 'required by'

    echo "==> locating an upstream quickshell package"
    if pacman -Si quickshell >/dev/null 2>&1; then
        installer=(sudo pacman -S --needed quickshell)
        echo "  found in a pacman repo"
    elif command -v yay >/dev/null 2>&1 && yay -Si quickshell >/dev/null 2>&1; then
        installer=(yay -S --needed quickshell)
        echo "  found via yay (AUR)"
    else
        echo "  no quickshell package found — aborting so dms-shell keeps a working runtime." >&2
        echo "  Revert the quickshell line in packages/arch-desktop.txt before applying." >&2
        exit 1
    fi

    # Preferred path: one transaction. If noctalia-qs declares a conflict with
    # quickshell, pacman offers the swap and dms-shell's dependency never goes
    # unsatisfied. Answer "y" when it asks to remove noctalia-qs.
    echo "==> swapping noctalia-qs -> quickshell"
    if ! "${installer[@]}"; then
        # Fallback: noctalia-qs only *provides* quickshell without conflicting,
        # so the two collide on /usr/bin/quickshell. -Rdd skips the dependency
        # check (dms-shell is briefly unsatisfied) and the install restores it.
        echo "==> direct install failed; removing noctalia-qs first"
        sudo pacman -Rdd noctalia-qs
        "${installer[@]}"
    fi

    pacman -Qq noctalia-qs >/dev/null 2>&1 && sudo pacman -Rns noctalia-qs || true
else
    echo "==> noctalia-qs is not installed — skipping the package swap"
fi

echo "==> verifying"
if quickshell --version 2>/dev/null | grep -q '^noctalia-qs '; then
    echo "  still noctalia-qs — leaving the hotfix tree in place." >&2
    exit 1
fi
quickshell --version

# The wrapper (~/.local/bin/dms-run-session) already falls through to the
# packaged DMS once noctalia-qs is gone, so this tree is dead weight.
if [ -e "$hotfix_base" ]; then
    echo "==> removing $hotfix_base"
    rm -rf "$hotfix_base"
fi

echo "==> restarting DMS (bar/launcher will blink)"
systemctl --user restart dms.service || echo "  restart failed — log out and back in"

echo "done. Now run: chezmoi diff && chezmoi apply"
