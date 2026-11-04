# Package lists

Consumed by `run_onchange_before_10-pacman.sh.tmpl` and
`run_onchange_before_21-aur.sh.tmpl`. Each script embeds a `sha256sum` of the
lists it reads, so editing a list re-triggers the install on the next
`chezmoi apply` (`--needed` makes that idempotent — installed packages are
skipped).

## What these lists include — and what they don't

The lists are explicitly-installed packages (`pacman -Qqen` / `pacman -Qqem`) with
OS-provided entries stripped for a CachyOS no-desktop installation. The `arch-`
filename prefix denotes the pacman/AUR package ecosystem, not a stock Arch target:

- **Stripped**: `base`, `linux`, `linux-firmware`, `linux-headers`, `intel-ucode`,
  `nvidia-open-dkms`. These come from the installer (or the NVIDIA checkbox on
  CachyOS). Re-installing `linux` on CachyOS would pull a second kernel alongside
  `linux-cachyos` and DKMS modules could build against the wrong one.
- **Kept**: everything else — DE, apps, fonts, dev tools, CLI utilities.

### Installer-owned packages

Kernel, firmware, microcode and NVIDIA drivers come from the CachyOS installer.
They live outside this snapshot. TUXEDO additionally installs headers for all
installed kernels before its DKMS modules are built.

## Regenerate on the current machine

```bash
cd "$(chezmoi source-path)/packages"
# Dump the full explicit sets, then fold changes into the split lists by hand
# (terminal vs desktop vs system):
pacman -Qqen | grep -Ev '^(base|linux|linux-firmware|linux-headers|intel-ucode|nvidia-open-dkms)$'
pacman -Qqem | grep -Ev '^yay-bin-debug$'
```

Commit the result. Because the `run_onchange_*` scripts embed each list's
`sha256sum`, editing a list changes the script's rendered content and chezmoi
re-runs it on the next `chezmoi apply` — on both clean and existing machines.
No need to install new packages by hand.

**Vet what you fold in.** `-Qqen` means *explicitly installed*, not *chosen* —
CachyOS's installer marks its whole profile bundle explicit, so a raw dump mixes
your decisions with the installer's. Anything you don't recognise, check with
`pacman -Qi <pkg>` / `pactree -r <pkg>` before adding it to a list.

## Audit for untracked packages

The lists are **additive only**: `pacman -S --needed` installs what's missing and
never removes anything. A package the installer put on the machine but that no
list mentions therefore stays forever, invisible to every apply — and can still
win a dependency resolution.

Both failure modes have already bitten — three times so far:

- **Captured** — `joyutils` came from the CachyOS installer's set, got folded into
  `arch-gaming.txt` as if it were intent, and then conflicted with `linuxconsole`
  on every apply.
- **Untracked** — `noctalia-qs` was in no list at all, which is exactly why it
  survived: it quietly satisfied `dms-shell`'s `quickshell` dependency, and
  nothing in the apply chain had any reason to notice.
- **Untracked, and enabled** — `sddm` came with a CachyOS desktop profile, which
  enables it as the display manager. It then held `display-manager.service`, the
  alias greetd also wants, so `systemctl enable greetd` failed and took the whole
  greetd script down with it on every apply.
  `run_once_after_45-greetd.sh.tmpl` now disables an incumbent DM, but disabling
  is not uninstalling — the package is still here, still untracked.

The cheapest fix is upstream of all three: **install with no desktop environment**
(see the main [README](../README.md#installer-choices-cachyos)). The lists
already cover the full graphical stack.

List everything explicitly installed but untracked:

```bash
cd "$(chezmoi source-path)/packages"
comm -13 \
  <(cat arch-terminal.txt arch-desktop.txt arch-system.txt arch-gaming.txt arch-ups.txt | sort -u) \
  <(pacman -Qqen | grep -Ev '^(base|linux|linux-firmware|linux-headers|intel-ucode|nvidia-open-dkms)$' | sort)
```

Swap in the `arch-aur-*.txt` lists and `pacman -Qqem` for the foreign side. Every
line is either an installer leftover or something you added by hand and forgot to
record — decide which, then track it or `pacman -Rns` it. `pactree -r <pkg>` first
for anything that looks load-bearing.

Worth running on each host separately: same installer, so the laptop and the
desktop accumulate their own copies.

## Format

One package name per line. Comments (`# …`) and blank lines are **not** supported
by `pacman -S -` / `paru -S -`, so keep the files clean.

## Gaming host

`arch-gaming.txt` and `arch-aur-gaming.txt` are gated on the `gaming` data var
(`dig "gaming" false .`, since `.chezmoi.toml.tmpl` only runs on `chezmoi init`),
and `profile = "main"`. The gaming desktop is the same platform as the laptop;
old gaming answers on WSL do not pull in desktop packages.

Two deliberate exceptions to the rules above:

- **`arch-gaming.txt` is CachyOS-only.** `cachyos-gaming-meta`,
  `gamescope-session-cachyos` and `linux-cachyos-headers` are not in stock Arch's
  repos and would abort the whole transaction, so the pacman script guards this
  list on `.chezmoi.osRelease.id == "cachyos"` specifically.
- **`linux-cachyos-headers` is kept**, even though plain `linux-headers` is
  stripped. It is not the same package and pulls no second kernel, and
  `hid-fanatecff-dkms` needs it: without headers a routine `pacman -Syu` leaves
  the module unbuilt and the Fanatec wheel silently loses force feedback. Running
  a non-default CachyOS kernel means swapping this for that kernel's headers.
- **`lib32-nvidia-utils` is named explicitly.** Steam only depends on "a lib32
  Vulkan driver"; with `--noconfirm` pacman auto-picks the first provider, which
  can be `lib32-mesa`.

`nvidia-open-dkms` stays stripped as documented above — it comes from the CachyOS
NVIDIA checkbox. Note that the RTX 50-series (Blackwell) has no proprietary
kernel-module option at all, so the open modules are mandatory rather than a
preference.

Controller DKMS modules (`xpadneo`, `xone`) are deliberately absent: Xbox
controllers over USB and DualSense work with the in-tree drivers. Add them only
if you hit a specific wireless dongle that doesn't.

`joyutils` is deliberately absent too — it conflicts with `linuxconsole` (both
ship `jstest` and `jscal`) and aborts the gaming transaction. `linuxconsole` is
the one to keep: it is the superset, and its `fftest` is what the Fanatec
force-feedback check in `docs/gaming.md` uses.

## Shared development clients

Linux and full-dev Macs receive development tools; the old `dev` flag and `arch-dev.txt`
manifest are retired. `arch-terminal.txt` includes `bind` (`dig`, `host`,
`nslookup`) and `postgresql-libs` (`libpq`, `psql`, `pg_dump`, `pg_restore`) for
both native Linux and WSL. The PostgreSQL server is not included.
`bind` is the current package providing the old `bind-tools` name; its DNS
server service is not enabled by these dotfiles.

macOS already provides the DNS tools. The full-dev Brewfile installs `libpq`, and zsh
adds its keg-only binaries to PATH for both Apple Silicon and Intel Homebrew.
This also supplies headers and `pg_config` for language drivers that link libpq.

## Mac / WSL

macOS installs from `Brewfile` (`run_onchange_before_05-homebrew.sh.tmpl`). The
installer exports `HOMEBREW_CHEZMOI_MAC_MODE` from the `macMode` data variable (`minimal`
or `full-dev`, defaulting to `full-dev` for existing configs). Changing the mode
re-runs installation. Direct `brew bundle` calls default to `full-dev`; set
`HOMEBREW_CHEZMOI_MAC_MODE=minimal` explicitly for a minimal Mac. Removal is a separate,
explicit operation: see [Mac cleanup](../docs/mac-profiles.md).

The
`wsl` profile installs `arch-terminal.txt` plus a small extra set (docker,
wl-clipboard, tailscale) directly in the pacman/AUR scripts. The Arch scripts won't
fire on non-Arch hosts thanks to the
`{{ "{{" }} if eq .chezmoi.osRelease.id "cachyos" "arch" {{ "}}" }}` guard.

## TUXEDO

`arch-aur-tuxedo.txt` is enabled only for Linux `main` with `tuxedo = true`.
The pacman step derives headers from `/usr/lib/modules/*/pkgbase`, so switching
to a CachyOS LTS kernel does not leave the hardware module without its headers.
AUR failures are reported and return failure after attempting the remaining
packages; the next `chezmoi apply` retries instead of recording a partial install
as successful. Package lists install missing packages; removing a line does not
uninstall that package.
