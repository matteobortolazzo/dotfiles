# Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/). Primary target is Arch Linux running [niri](https://github.com/YaLTeR/niri) (scrollable-tiling Wayland compositor) with [DankMaterialShell](https://danklinux.com/) as the desktop shell, behind a greetd/regreet login. Terminal configs (zsh, tmux, neovim, yazi, ghostty, lazygit, bat) are shared with macOS and WSL.

## Machine axes

`chezmoi init` prompts once for five values — four independent axes plus the dev box's hostname — stored in `~/.config/chezmoi/chezmoi.toml`:

| Prompt | Axis | Values |
|---|---|---|
| `profile` | Platform — packages, compositor, interop | `main` / `wsl` / `mac` |
| `org` | Work ownership; must match the 1Password item name in the Private vault | org name, blank for personal |
| `gaming` | Role — gaming / sim-rig host | `true` / `false` |
| `dev` | Role — remote dev box: inbound sshd + the firewall rule for it | `true` / `false`, defaults to the `gaming` answer |
| `devHost` | The dev box's MagicDNS hostname, aliased as `ssh desktop` | hostname, blank for none |

| Profile | What you get |
|---|---|
| `main` | Full Arch desktop: niri + DMS, greetd, GUI apps, system services |
| `wsl` | Terminal stack + docker, WSL host tuning, no Windows interop |
| `mac` | Terminal stack via Homebrew/Brewfile |

They stay orthogonal on purpose: the gaming desktop runs the same platform as the laptop (CachyOS + niri + DMS + greetd), so it is `profile = "main"` with the roles layered on, not a profile of its own. `gaming` and `dev` happen to coincide there — that one box is both the sim rig and the remote dev target — but they are separate vars because a headless dev box needs no Steam and a couch-gaming host has no business accepting logins.

Templates read the newer vars with `dig "gaming" false .` rather than `.gaming`. `.chezmoi.toml.tmpl` only runs on `chezmoi init`, so a machine whose config predates a prompt would otherwise fail every apply. The flip side: an existing machine is **not** re-prompted when a var is added, so `dig` returns the default and the new role is off until you run `chezmoi init` again (it keeps the existing answers and only asks the new question) or add the line to `~/.config/chezmoi/chezmoi.toml` by hand.

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

Secrets in `~/.config/environment` (mode `0600`) and the SSH agent come from 1Password. Until `op` is installed *and* signed in, `chezmoi apply` simply skips them; re-run apply afterwards to fill them in.

```bash
# Arch (installed automatically by the package lists)  /  macOS: via Brewfile
op signin
```

Enable the SSH agent in the 1Password desktop app: **Settings → Developer → SSH Agent**.

On **WSL** there is no 1Password agent to talk to: the Linux app isn't installed, and the Windows one is out of reach because the distro runs with `[automount] enabled=false` (no `/mnt/c`, so no `powershell.exe` and no bridge). That profile uses the plain OpenSSH agent instead — `ssh-agent.socket` (enabled by `run_once_after_60-wsl.sh`) with `SSH_AUTH_SOCK` set in `.zshrc`, so `AddKeysToAgent yes` loads a key from `~/.ssh` on first use. Git over HTTPS is unaffected: it authenticates through `gh auth git-credential`.

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

`main`-profile only: `38-opt-webp` (libwebp into `/opt/webp`), `39-pen` (Pen via `~/.config/scripts/install-pen.sh`), `23-tailscale` (enables `tailscaled`, and fixes the NetworkManager/systemd-resolved wiring MagicDNS depends on — see below).

Two non-obvious ones:

- **`35-npm-globals`** installs an fnm-managed Node first if the current one is `system` or absent. Without it npm resolves to the system (Homebrew) prefix, which can be foreign-owned — global installs then fail with `EACCES`.
- **`50-jetbrains-wayland`** is a `run_after_` (every apply, not once): it appends `-Dawt.toolkit.name=WLToolkit` to each IDE's `*64.vmoptions` for native Wayland rendering, and new JetBrains IDEs only create that file after their first launch.

Docker and sysbox (Docker-in-Docker) have their own sections below.

## Shell history

`Ctrl-R` is [Atuin](https://atuin.sh/) on every profile: a sqlite-backed search TUI with vim keys, seeded from the old plain histfile by `36-atuin`. **Local only** — no account, no sync, no network (the sync server is a separate package that isn't installed). `↑` stays plain zsh recall. The binding is handed to `zsh-vi-mode`'s `zvm_after_init_commands` hook rather than bound inline, because that plugin re-inits at the first prompt and silently overwrites anything `.zshrc` bound. See [`docs/atuin.md`](docs/atuin.md) for that trap and for the self-hosted-sync recipe.

## Gaming / sim-rig host

`gaming = true` (the desktop; see [`docs/gaming.md`](docs/gaming.md) for hardware, the two-session split, and the Fanatec/Sunshine pitfalls) adds:

- `arch-gaming.txt` + `arch-aur-gaming.txt` — Steam, `gamescope-session-cachyos`, Sunshine, `hid-fanatecff-dkms`. **CachyOS-only**: several of these aren't in stock Arch's repos and would abort the whole transaction.
- `26-gaming` — the glue the packages don't do and that fails *silently* when missing: `games` group (hid-fanatecff's udev rules grant wheelbase access to it, and nothing adds you — without it the wheel enumerates as a plain joystick with no force feedback and no error anywhere), `gamemode` group, udev reload, and `scx_loader` for the latency-oriented `scx_lavd` scheduler.
Two sessions run from the same greetd: niri for the desktop *and* for sim racing native-fullscreen, `gamescope-session-cachyos` for couch gaming on the TV. Sims deliberately do not run under gamescope.

Sunshine's ports are opened by `28-firewall` (below) — that script is gated on `dev`, so a gaming host that is *not* also a dev box never enables ufw and needs no rules.

## Remote dev box

`dev = true` (the desktop) turns the machine into an SSH target. Two scripts, and both are needed — either one alone leaves the box looking up and answering nothing:

- `27-sshd` — enables `sshd.service`. Hardening (`PasswordAuthentication no`, `PermitRootLogin no`) is written to `/etc/ssh/sshd_config.d/10-hardening.conf` **only once `~/.ssh/authorized_keys` is non-empty**. Writing it against an empty key file would lock out every remote login on a box whose whole point is being headless. Until then the script prints the `ssh-copy-id` + re-run instructions.
- `28-firewall` — opens port 22 in ufw (`limit`, so brute force is throttled without fail2ban), plus an interface rule for `tailscale0` and, on a `gaming` host, Sunshine's ports.

It also pulls `packages/arch-dev.txt` — currently `bind-tools`, for `dig`/`host`/`nslookup`. Debugging a remote box is mostly DNS questions (is MagicDNS resolving, is systemd-resolved answering), and none of those tools are in `base`.

The firewall half is the one that bites, because its failure mode is indistinguishable from a dead service. ufw's default inbound policy is `DROP`, and CachyOS's installer can leave ufw *enabled with an empty rule set* — at which point `systemctl status sshd` is green, `Server listening on 0.0.0.0 port 22` is in the journal, `ss -tlnp` shows the socket, and every inbound SYN is still dropped in netfilter before sshd sees it. There is no log line for a packet that never arrives, so the journal shows nothing at all. Diagnose it with:

```bash
sudo ufw status verbose     # "Status: active" + no 22/tcp rule == this bug
journalctl -u sshd -n 20    # zero connection lines == packets aren't arriving
```

`28-firewall` adds its rules *before* enabling ufw, so it is safe to run over an existing SSH session.

### Reaching it from outside the LAN

Over Tailscale, so nothing is forwarded on the router and the tailnet is the perimeter. From any device signed into the tailnet, anywhere:

```bash
ssh desktop        # alias from private_dot_ssh/config.tmpl
```

The target comes from the `devHost` data var rather than a hostname baked into the ssh config, and the block is skipped when `devHost` equals `.chezmoi.hostname` — no machine carries an alias pointing at itself, and Tailscale derives the MagicDNS name from the system hostname, so that comparison is exact. Renaming the desktop is a one-line config change on each client.

`HostName` is the **short** MagicDNS name rather than the FQDN: the tailnet suffix is pushed to every member as a DNS search domain, so the short name resolves on its own and the tailnet ID stays out of this repo. Set `devHost` to `<host>.<tailnet>.ts.net` on a client that has MagicDNS off. `28-firewall`'s `tailscale0` rule is what lets the connection in; the LAN rule is separate and rate-limited.

MagicDNS is the fragile part, and it fails quietly. NetworkManager writes `/etc/resolv.conf` as a regular file by default, which is what makes `tailscale status` report *"systemd-resolved and NetworkManager are wired together incorrectly"*. Lookups usually still work — NM writes `nameserver 127.0.0.53`, which is resolved's stub — but NM owns that file and rewrites it on interface changes, so one reconnect can swap in the router's DNS and `*.ts.net` stops resolving with nothing in any log. `23-tailscale` installs `system/NetworkManager/10-dns-systemd-resolved.conf` (`dns=systemd-resolved` + `rc-manager=unmanaged`) and symlinks `/etc/resolv.conf` to resolved's stub. Check it with:

```bash
resolvectl status | head -3           # want "resolv.conf mode: stub", not "foreign"
tailscale status                      # health warnings print after the peer list
resolvectl query amd-desktop.<tailnet>.ts.net
```

Per-link scoping is the point: resolved sends `*.ts.net` to `100.100.100.100` on `tailscale0` and everything else to the LAN resolver. Flattening every interface into one `resolv.conf` loses that.

## WSL notes

- `run_once_after_60-wsl.sh` writes `/etc/wsl.conf` (systemd on, `[automount] enabled=false`, Windows PATH trimmed for fast shells), enables docker, and enables `ssh-agent.socket`. Run `wsl --shutdown` from Windows once after the first apply.
- **No Windows interop by design.** With automount off, `/mnt/c` is empty and no `*.exe` can be executed, so `wslview`/`$BROWSER`, `clip.exe`, and any 1Password-on-Windows SSH bridge are all unavailable — the configs don't reference them. Two things still work and are worth knowing: the clipboard, via WSLg's Wayland display plus `wl-clipboard` (installed by `10-pacman`), and Windows-side files, over the network path (`\\wsl$`) or `scp`. If you ever want `/mnt/c` back, drop the `[automount]` block from `/etc/wsl.conf`, `wsl --shutdown`, and revisit the WSL branches in `.zshrc` and `~/.ssh/config`.
- Copy `docs/wslconfig.example` to `%USERPROFILE%\.wslconfig` on the Windows host for memory caps, mirrored networking, and `autoMemoryReclaim`.

## Captive-portal wifi (hotel / airport / train)

`main` profile, `run_once_after_29-captive-portal.sh.tmpl`. Joining a network that
wants a click-through login used to leave you with a connected wifi icon and no
working traffic, because nothing on niri reacts to that state — GNOME Shell has
the handler built in, a bare compositor doesn't.

Two halves, both needed:

- **Detection** is NetworkManager's own connectivity check, pinned in
  `/etc/NetworkManager/conf.d/20-connectivity.conf`. NM fetches a plain-HTTP URL
  (`ping.archlinux.org/nm-check.txt`); a gateway that rewrites the reply moves NM
  from `full` to `portal`. Plain HTTP is the requirement, not an oversight — an
  intercepted HTTPS request can't be rewritten without a cert warning.
- **Reaction** is `captive-portal.service`, a user unit pulled in by
  `niri.service` (same wiring as dms). It runs
  `~/.config/niri/scripts/captive-portal-watch.sh`, which uses `nmcli monitor`
  as a wake-up, re-reads the state, and opens a **private** Zen window on each
  transition *into* `portal` — private so the portal's cookies and redirect
  junk stay out of the everyday profile, transition-only so a flapping link
  can't reopen the browser on every check.

The browser is pointed at `http://neverssl.com`, not at NM's check URL:
`archlinux.org` is HSTS-preloaded, so a browser would silently upgrade it to
HTTPS before the gateway ever saw the request. Override with
`CAPTIVE_PORTAL_URL` if a specific network needs a different bait URL.

For the gateway that passes NM's check but still gates real traffic, trigger it
by hand:

```bash
~/.config/niri/scripts/captive-portal-watch.sh --now
nmcli -t -f CONNECTIVITY general status   # what NM currently thinks
journalctl --user -u captive-portal -f    # what the watcher saw
```

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
- Registers `sysbox-runc` as a Docker runtime by installing
  `system/docker/daemon.json` to `/etc/docker/daemon.json` (and restarting a
  running dockerd). The AUR package doesn't do this the way sysbox's `.deb`
  postinst does, so without it `docker run --runtime=sysbox-runc` fails with
  `unknown or invalid runtime name`. The script owns that file wholesale — put
  any other daemon settings in `system/docker/daemon.json`, not in `/etc`.
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
- `system/` — files outside `$HOME` (greetd/regreet, docker daemon.json + iptables modules, the two NetworkManager drop-ins: connectivity check and DNS); mirrored to `/etc` by `run_once_after_45-greetd.sh.tmpl` / `run_once_after_25-sysbox.sh.tmpl` / `run_once_after_29-captive-portal.sh.tmpl` / `run_once_after_23-tailscale.sh.tmpl` via sudo.
- `docs/` — reference material not deployed anywhere (`gaming.md`, `atuin.md`, `wslconfig.example`).
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
