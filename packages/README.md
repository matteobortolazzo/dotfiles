# Package lists

Consumed by `run_once_before_10-pacman.sh.tmpl` and `run_once_before_21-aur.sh.tmpl`.

## What these lists include — and what they don't

The lists are explicitly-installed packages (`pacman -Qqen` / `pacman -Qqem`) with
OS-provided entries stripped so the same list works on stock Arch and CachyOS:

- **Stripped**: `base`, `linux`, `linux-firmware`, `linux-headers`, `intel-ucode`,
  `nvidia-open-dkms`. These come from the installer (or the NVIDIA checkbox on
  CachyOS). Re-installing `linux` on CachyOS would pull a second kernel alongside
  `linux-cachyos` and DKMS modules could build against the wrong one.
- **Kept**: everything else — DE, apps, fonts, dev tools, CLI utilities.

### Stock Arch note

On stock Arch, kernel/firmware/ucode/nvidia come from whatever the installer
(archinstall or manual) set up. Nothing in this list will pull them back if you
ever uninstall them — they live outside this snapshot. That is deliberate; add
them to your bootstrap step if you want them tracked.

## Regenerate on the current machine

```bash
cd "$(chezmoi source-path)/packages"
pacman -Qqen | grep -Ev '^(base|linux|linux-firmware|linux-headers|intel-ucode|nvidia-open-dkms)$' > arch-native.txt
pacman -Qqem | grep -Ev '^yay-bin-debug$' > arch-aur.txt
```

Commit the result. Chezmoi re-hashes the `run_once_*` scripts when they change,
so refreshing the package lists alone won't retrigger install on machines where
the scripts already ran. On a clean machine they run; on an existing one you
add new packages by hand (or bump a comment in the script to force re-run).

## Format

One package name per line. Comments (`# …`) and blank lines are **not** supported
by `pacman -S -` / `paru -S -`, so keep the files clean.

## Mac / WSL later

Add `brew.txt` (Brewfile format) or `apt.txt` and corresponding OS-gated
`run_once_before_*` scripts. The Arch scripts won't fire on non-Arch hosts thanks
to the `{{ "{{" }} if eq .chezmoi.osRelease.id "cachyos" "arch" {{ "}}" }}` guard.
