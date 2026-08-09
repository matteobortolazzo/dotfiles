# Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/). Primary target is Arch Linux running [niri](https://github.com/YaLTeR/niri) (scrollable-tiling Wayland compositor) with [DankMaterialShell](https://danklinux.com/) as the desktop shell, behind a greetd/regreet login. Terminal configs (zsh, tmux, neovim, yazi, ghostty, lazygit, bat) are shared with macOS and WSL.

## Machine axes

`chezmoi init` prompts once for three independent values, stored in `~/.config/chezmoi/chezmoi.toml`:

| Prompt | Axis | Values |
|---|---|---|
| `profile` | Platform — packages, compositor, interop | `main` / `wsl` / `mac` |
| `org` | Work ownership; must match the 1Password item name in the Private vault | org name, blank for personal |
| `gaming` | Role — gaming / sim-rig host, which doubles as the remote dev box | `true` / `false` |

| Profile | What you get |
|---|---|
| `main` | Full Arch desktop: niri + DMS, greetd, GUI apps, system services |
| `wsl` | Terminal stack + docker, WSL host tuning, Windows SSH-agent bridge |
| `mac` | Terminal stack via Homebrew/Brewfile |

They stay orthogonal on purpose: the gaming desktop runs the same platform as the laptop (CachyOS + niri + DMS + greetd), so it is `profile = "main"` with `gaming = true` layered on, not a profile of its own.

Templates read the newer vars with `dig "gaming" false .` rather than `.gaming`. `.chezmoi.toml.tmpl` only runs on `chezmoi init`, so a machine whose config predates a prompt would otherwise fail every apply.

## Quick start (empty machine)

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply matteobortolazzo
```

That single command installs chezmoi, clones this repo, prompts for the profile, and applies. On Arch it installs all packages (pacman + AUR via yay), enables system services (NetworkManager, bluetooth, docker, greetd, …), wires DMS to autostart with niri, and bootstraps the toolchain (oh-my-zsh, rustup, dotnet, fnm/node, tpm). **Reboot when it finishes** — greetd is enabled but deliberately not started mid-apply.

Secrets are skipped on the first pass if the 1Password CLI isn't signed in yet (see below) — everything else completes.

### Installer choices (CachyOS / Arch)

**Pick no desktop environment.** Everything graphical comes from these dotfiles — niri, DMS, portals and fonts via `packages/arch-desktop.txt`, the greetd/regreet login via `arch-system.txt` and `system/greetd/`. A desktop profile from the installer (niri included) can only *add* packages no list tracks, and the lists are additive: `pacman -S --needed` never removes anything, so installer leftovers persist invisibly and can still win a dependency resolution. That has bitten three times now — `joyutils`, `noctalia-qs`, and SDDM.

SDDM is the one that breaks the boot: CachyOS enables it for every desktop profile, so it holds `display-manager.service` before greetd is ever installed. `run_once_after_45-greetd.sh.tmpl` detects and disables an incumbent display manager, but it deliberately doesn't uninstall anything — run the audit in [`packages/README.md`](packages/README.md) after a profile install to find the rest of the residue.

**Keep the NVIDIA driver checkbox** on machines that have one. It's independent of the desktop choice, and `nvidia-open-dkms` is deliberately stripped from the package lists precisely because it comes from there.

### 1Password (secrets + SSH agent)

Secrets in `~/.config/environment` and the SSH agent come from 1Password. Until `op` is installed *and* signed in, `chezmoi apply` simply skips them; re-run apply afterwards to fill them in.

```bash
# Arch (installed automatically by the package lists)  /  macOS: via Brewfile
op signin
```

Enable the SSH agent in the 1Password desktop app: **Settings → Developer → SSH Agent**.

On **WSL**, 1Password runs on the Windows side: enable its SSH agent on Windows, and the dotfiles bridge to it automatically via `wsl2-ssh-agent` (installed by `run_once_after_60-wsl.sh`).

## Day-to-day commands

```bash
chezmoi diff              # Preview pending changes
chezmoi apply             # Apply source state to ~/
chezmoi add ~/.config/foo # Track a new file
chezmoi update            # Pull remote changes + apply
```

## Dev toolchain

Bootstrapped by the `run_once_after_3x/4x` scripts. Everything installs **into `$HOME`** rather than via pacman, so versions stay independent of the system upgrade cycle — the matching `PATH`/`*_ROOT` entries live in `.zshrc`. Each script exits early when its target binary already exists, so re-applying is free.

| Script | Installs | Where |
|---|---|---|
| `30-oh-my-zsh`, `31-zsh-plugins`, `32-tmux-plugins` | Oh My Zsh, zsh plugins, tpm | `~/.oh-my-zsh`, `~/.tmux/plugins` |
| `33-rustup` | rustup via rustup.rs (`--no-modify-path`) | `~/.cargo` |
| `34-dotnet` | .NET LTS via dotnet-install.sh | `~/.dotnet` (`$DOTNET_ROOT`) |
| `35-npm-globals` | fnm Node LTS + global npm packages | fnm prefix |
| `40-aspire` | Aspire CLI, standalone build | `~/.aspire/bin` |
| `44-lazyboards` | `go install` lazyboards | `~/go/bin` |

`main`-profile only: `38-opt-webp` (libwebp into `/opt/webp`), `39-pen` (Pen via `~/.config/scripts/install-pen.sh`), `23-tailscale` (enables `tailscaled`).

Two non-obvious ones:

- **`35-npm-globals`** installs an fnm-managed Node first if the current one is `system` or absent. Without it npm resolves to the system (Homebrew) prefix, which can be foreign-owned — global installs then fail with `EACCES`.
- **`50-jetbrains-wayland`** is a `run_after_` (every apply, not once): it appends `-Dawt.toolkit.name=WLToolkit` to each IDE's `*64.vmoptions` for native Wayland rendering, and new JetBrains IDEs only create that file after their first launch.

Docker and sysbox (Docker-in-Docker) have their own sections below.

## Gaming / sim-rig host

`gaming = true` (the desktop; see [`docs/gaming.md`](docs/gaming.md) for hardware, the two-session split, and the Fanatec/Sunshine pitfalls) adds:

- `arch-gaming.txt` + `arch-aur-gaming.txt` — Steam, `gamescope-session-cachyos`, Sunshine, `hid-fanatecff-dkms`. **CachyOS-only**: several of these aren't in stock Arch's repos and would abort the whole transaction.
- `26-gaming` — the glue the packages don't do and that fails *silently* when missing: `games` group (hid-fanatecff's udev rules grant wheelbase access to it, and nothing adds you — without it the wheel enumerates as a plain joystick with no force feedback and no error anywhere), `gamemode` group, udev reload, and `scx_loader` for the latency-oriented `scx_lavd` scheduler.
- `27-sshd` — the desktop is also the remote dev box. Gated on `gaming` rather than a role var of its own; split them the moment a machine wants one without the other. Hardening (`PasswordAuthentication no`) only applies once an authorized key is actually present.

Two sessions run from the same greetd: niri for the desktop *and* for sim racing native-fullscreen, `gamescope-session-cachyos` for couch gaming on the TV. Sims deliberately do not run under gamescope.

## WSL notes

- `run_once_after_60-wsl.sh` writes `/etc/wsl.conf` (systemd on, Windows PATH trimmed for fast shells — `/mnt/c/Windows/System32` is re-added in `.zshrc` so `wslview`/`clip.exe` keep working), enables docker, and installs the SSH-agent bridge. Run `wsl --shutdown` from Windows once after the first apply.
- Copy `docs/wslconfig.example` to `%USERPROFILE%\.wslconfig` on the Windows host for memory caps, mirrored networking, and `autoMemoryReclaim`.

## Printing & scanning

`main` profile, `run_once_after_46-printing.sh.tmpl`. Aims at driverless first: CUPS plus Avahi/nss-mdns covers IPP Everywhere (AirPrint) over the network, `ipp-usb` gives the same driverless path over a USB cable, and `hplip` covers HP hardware predating IPP Everywhere. `sane` + `sane-airscan` + `simple-scan` pick up the scanner half of a multifunction.

The script enables `cups.socket` and `avahi-daemon`, splices `mdns_minimal [NOTFOUND=return]` into `/etc/nsswitch.conf` so `.local` printer names resolve, and adds you to `lp` and `scanner` (hplip's USB backend and the sane udev rules that tag devices `GROUP="scanner"` instead of relying on uaccess — takes effect at next login).

`ipp-usb` has no enable step: its udev rule starts the service on plug-in. A printer already connected when it was installed needs a replug or `sudo systemctl start ipp-usb`.

Add a printer with `system-config-printer`, the web UI at <http://localhost:631>, `lpadmin`, or `hp-setup -i` for HP over USB.

## Hardware quirks

### NVIDIA + suspend (laptops with NVIDIA GPU)

On machines with the proprietary NVIDIA driver, s2idle suspend corrupts GPU
state on resume — the symptom is a system that is hyper slow and unusable
after unlocking from a long idle lock, requiring a reboot.

`run_once_after_22-nvidia-suspend.sh.tmpl` applies the Arch-wiki fix on first
apply: writes `/etc/modprobe.d/nvidia-power-management.conf` with
`NVreg_PreserveVideoMemoryAllocations=1`, regenerates the initramfs, and
enables `nvidia-{suspend,resume,hibernate}.service`. The script is a no-op
on hosts without `nvidia-suspend.service` installed. A reboot is required
after first apply for the modprobe option to take effect.

## Docker

Arch ships `docker` with its units disabled and the `docker` group empty, so a
fresh machine has no `/var/run/docker.sock` and no unprivileged access to it —
`docker ps` fails with `dial unix /var/run/docker.sock: no such file or
directory`. `24-services` enables `docker.socket` (socket activation starts
`dockerd` on the first client connection) and adds you to the `docker` group.
Group membership only takes effect on the next login, so it comes for free with
the post-install reboot; after a later apply, log out and back in (or `newgrp
docker` for one shell). On WSL the same setup lives in `60-wsl` instead.

## Sysbox (nested Docker-in-Docker)

[sysbox](https://github.com/nestybox/sysbox) is a container runtime that lets
unprivileged containers run Docker, systemd, or Kubernetes inside themselves
with real isolation (no `--privileged`). Arch-only (`main` profile); installed
from the AUR since there's no official package.

`run_once_after_25-sysbox.sh.tmpl` handles the parts the AUR package doesn't:

- Enables `sysbox.service` — AUR packages don't auto-enable systemd units the
  way sysbox's official `.deb` postinst does.
- Registering `sysbox-runc` as a Docker runtime (`/etc/docker/daemon.json`
  `runtimes.sysbox-runc`) isn't automated — do it once by hand, then
  `sudo systemctl restart docker`.
- Loads netfilter modules (`ip_tables`, `iptable_nat`, `ip6_tables`,
  `ip6table_nat`, `nf_nat`) via `system/docker/modules-load-docker-iptables.conf`.
  systemd >= 259 dropped automatic legacy-iptables module loading, so without
  this, dockerd running *inside* a sysbox container fails to create its NAT
  chain with `can't load module ip_tables ... Operation not permitted`
  (containers can never load kernel modules themselves — it has to already be
  loaded on the host).

Verify with `docker run --runtime=sysbox-runc -it --hostname=syscont
nestybox/alpine-docker:latest`, then inside: `dockerd > /var/log/dockerd.log
2>&1 &` followed by `docker run -it busybox`.

## Repo layout notes

- `packages/` — pacman/AUR/brew package lists; editing a list re-triggers the install scripts on the next apply (see `packages/README.md`).
- `system/` — files outside `$HOME` (greetd/regreet, docker iptables modules); mirrored to `/etc` by `run_once_after_45-greetd.sh.tmpl` / `run_once_after_25-sysbox.sh.tmpl` via sudo.
- `docs/` — reference material not deployed anywhere (`gaming.md`, `wslconfig.example`).
- DMS runtime files (`settings.json`, `niri/dms/outputs.kdl`) are chezmoi `create_` entries: seeded once on a fresh machine, then owned by DMS — `chezmoi apply` never overwrites them.

## Recovery

If greetd fails on boot: switch to TTY2 (`Ctrl+Alt+F2`) and run
`sudo systemctl disable --now greetd` to fall back to plain TTY login.

If the login screen isn't regreet, a different display manager owns the seat:

```bash
readlink -f /etc/systemd/system/display-manager.service   # who holds the alias
systemctl is-enabled sddm greetd
```

`chezmoi apply` disables whatever it finds there in favour of greetd, effective
next reboot. It never stops the running one — that would kill the session mid-apply.
