# Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/). Linux starts from a **CachyOS bare TTY installation**, then these dotfiles install [niri](https://github.com/YaLTeR/niri), [Dux Shell](https://duxlabs.dev/) (formerly DankMaterialShell; still `dms`), and greetd/dux-greeter. Terminal configs (zsh, tmux, neovim, yazi, ghostty, lazygit, bat) are shared with macOS. The existing Arch-based WSL profile remains available for compatibility.

## Machine axes

`chezmoi init` stores platform, role, hardware and remote-access answers in `~/.config/chezmoi/chezmoi.toml`:

| Prompt | Axis | Values |
|---|---|---|
| `profile` | Platform — packages, compositor, interop | `main` / `wsl` / `mac` |
| `macMode` | Mac tool selection | `minimal` (browser + real-iPhone builds) / `full-dev`; missing values retain full development tools |
| `org` | Work ownership; must match the 1Password item name in the Private vault | org name, blank for personal |
| `gaming` | Role — gaming / sim-rig host | `true` / `false` |
| `headless` | Boot policy — second limine entry booting to `multi-user.target`, desktop started on demand | `true` / `false`, defaults to `false` |
| `ups` | Hardware — a UPS is on this box's USB: NUT monitoring and clean shutdown on a power cut | `true` / `false`, defaults to `false` |
| `deck` | Hardware — a Stream Deck is plugged into this box: builds `deckd`, the status panel, and its udev rule + system unit | `true` / `false`, defaults to `false` |
| `tuxedo` | Hardware — TUXEDO laptop drivers, matching kernel headers and Control Center | `true` / `false`, defaults to `false`; Linux `main` only |
| `devHost` | The dev box's MagicDNS hostname, reached as `ssh <devHost>` | hostname, blank for none |
| `devUser` | Username on the remote dev box | blank to use this machine's username |

| Profile | What you get |
|---|---|
| `main` | Full CachyOS desktop: niri + DMS, greetd, GUI apps, system services |
| `wsl` | Terminal stack + docker, WSL host tuning, no Windows interop |
| `mac` | Shared terminal stack, OmniWM, Ghostty and GUI apps via Homebrew/Brewfile |

Linux and full-dev Macs get the shared development tools, including OpenCode and PostgreSQL clients. Minimal Macs keep the browser, desktop utilities, shell, Node and physical-iPhone debugging tools. Native CachyOS and macOS machines also enable SSH access. The old `dev` flag is ignored; `macMode` selects Mac tools. `devHost` and `devUser` still select an SSH client destination. See [Mac profiles and cleanup](docs/mac-profiles.md).

The gaming desktop runs the same platform as the laptop (CachyOS + niri + DMS + greetd), with gaming and hardware options layered on. These options and `headless` are only prompted on Linux `main`; they do not install desktop hardware support on macOS or WSL.

`headless` is a boot policy: SSH access does not imply booting without a desktop. Keep it false on a laptop that should show its greeter on every boot.

`ups` is a fact about the hardware, independent of SSH access and `headless`: it says a UPS data cable is plugged into *this* box, which decides whether NUT is installed and which machine gets to tell the UPS to cut its output. An unattended box with no UPS must not ship a monitor that can shut it down.

`deck` is the same kind of fact: a Stream Deck is plugged into this box, so `52-streamdeck` builds `deckd` and wires it to the device. See [`docs/streamdeck.md`](docs/streamdeck.md).

Templates read the newer vars with `dig "gaming" false .` rather than `.gaming`. `.chezmoi.toml.tmpl` only runs on `chezmoi init`, so a machine whose config predates a prompt would otherwise fail every apply. The flip side: an existing machine is **not** re-prompted when a var is added, so `dig` returns the default and the new role is off until you run `chezmoi init` again (it keeps the existing answers and only asks the new question) or add the line to `~/.config/chezmoi/chezmoi.toml` by hand.

## Quick start (empty machine)

Install CachyOS with **no desktop environment**, boot into the installed system,
connect to the network (`nmtui` for Wi-Fi), and log in as your normal sudo-capable
user. Install bootstrap prerequisites before cloning:

```bash
sudo pacman -Syu --needed git curl
```

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply matteobortolazzo
```

That single command installs chezmoi, clones this repo, prompts for the profile, and applies. On CachyOS it installs all packages (pacman + AUR via yay), enables system services (NetworkManager, bluetooth, docker, greetd, …), wires DMS to autostart with niri, and bootstraps the toolchain (oh-my-zsh, rustup, dotnet, fnm/node, tpm). **Reboot when it finishes** — greetd is enabled but deliberately not started mid-apply.

Secrets are skipped on the first pass if the 1Password CLI isn't signed in yet (see below) — everything else completes.

### Installer choices (CachyOS)

**Pick no desktop environment.** Everything graphical comes from these dotfiles — niri, DMS, portals and fonts via `packages/arch-desktop.txt`, the greetd/dux-greeter login via `arch-system.txt`, `arch-aur-desktop.txt` and `system/greetd/`. A desktop profile from the installer (niri included) can only *add* packages no list tracks, and the lists are additive: `pacman -S --needed` never removes anything, so installer leftovers persist invisibly and can still win a dependency resolution. That has bitten three times now — `joyutils`, `noctalia-qs`, and SDDM.

SDDM is the one that breaks the boot: CachyOS enables it for every desktop profile, so it holds `display-manager.service` before greetd is ever installed. `run_once_after_45-greetd.sh.tmpl` detects and disables an incumbent display manager, but it deliberately doesn't uninstall anything — run the audit in [`packages/README.md`](packages/README.md) after a profile install to find the rest of the residue.

**Keep the NVIDIA driver checkbox** on machines that have one. It's independent of the desktop choice, and `nvidia-open-dkms` is deliberately stripped from the package lists precisely because it comes from there.

Choose `profile = "main"`. On the TUXEDO laptop also choose `tuxedo = true`.
Use `headless = false` for a normal laptop: starting the installation at a TTY is
different from choosing the optional headless boot policy. The setup enables
`graphical.target` and greetd for the next boot without interrupting the TTY.

### TUXEDO laptop

`tuxedo = true` installs `tuxedo-drivers-dkms` and `tuxedo-control-center-bin`,
installs headers matching every installed kernel, and enables `tccd` and
`tccd-sleep`. It masks `power-profiles-daemon` so two services do not compete to
manage the CPU. Use TUXEDO Control Center for power/fan profiles; DMS's PPD widget
is not the power controller on this machine. Reboot after the first apply and
check `dkms status` and `systemctl status tccd`.

Existing laptop: run `chezmoi init` to answer the new hardware prompt, or add
`tuxedo = true` under `[data]`, then apply. If you later turn this hardware flag
off on the same machine, disable `tccd`/`tccd-sleep`, unmask and enable
`power-profiles-daemon` explicitly; role changes do not uninstall hardware support.

### macOS

Install Apple's Command Line Tools (`xcode-select --install`) first. Run the
chezmoi bootstrap above with profile `mac`; Homebrew supports both Apple Silicon
and Intel prefixes. `chezmoi init` also sets the PATH inherited by every install
script, so run it once on an existing Mac to pick up that change.

The Brewfile includes 1Password **and** its CLI, Zen (used by the browser hotkey),
JetBrains Toolbox, ImageMagick, Python, tree-sitter-cli and Neovim formatters.
Open OmniWM and grant its requested Accessibility permissions, then enable
launch at login in the app. For the Zen hotkey, grant skhd Accessibility access
and run `skhd --start-service`. Open Docker Desktop and Tailscale to finish their
interactive setup. Enable the 1Password SSH agent as described below.

The SSH setup enables macOS Remote Login. If macOS blocks the command, enable
**System Settings → General → Sharing → Remote Login** and rerun the apply.
Check that your account is allowed in that panel. Alternatively, grant the
calling terminal Full Disk Access so `systemsetup` can enable it.

Ghostty loads the shared `~/.config/ghostty/config`, followed by the Mac-specific
keybindings in `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`.

### Neovim and updates

Use Neovim **0.12+** and tree-sitter-cli **0.26.1+** with the tracked Treesitter
`main` branch. Packages supply Prettier and StyLua; Mason supplies language
servers, including Go. Open a source file to load LSP, then check `:Mason`,
`:ConformInfo` and `:checkhealth`. Native parser/fzf builds need the C compiler
from `base-devel` on CachyOS or Command Line Tools on macOS.

The lockfile pins reviewed plugin revisions. `:Lazy restore` restores those
revisions; `:Lazy update` updates plugins and `:TSUpdate` updates their parsers.
Copy a deliberately updated lockfile back with `chezmoi add ~/.config/nvim/lazy-lock.json`.
OS packages stay rolling: use `yay -Syu` on CachyOS, or `brew update` then
`brew upgrade` on macOS. Bootstrap scripts do not continually upgrade user
toolchains: use `rustup update`, `fnm install --lts`, and the relevant .NET/Aspire
updaters separately.

Dux Shell 2 uses `~/.config/dms` and `~/.local/state/dms`. A before-script copies
legacy `DankMaterialShell` directories only when the new destination is absent,
preserving originals and any settings already migrated by Dux itself.
The old config directory is archived under `DankMaterialShell.backup.*` before
chezmoi installs the compatibility symlink `DankMaterialShell -> dms`.

Run the profile/render and migration checks with `python3 tests/check_config.py`.
See [configuration review](docs/configuration-review.md) for verification limits
and the upstream references used for this update.

### 1Password (secrets + SSH agent)

Secrets in `~/.config/environment` (mode `0600`) and the SSH agent come from 1Password.
`.chezmoiignore` checks both `op signin --raw` and `op vault list` and, when either fails,
ignores `~/.config/environment` entirely — chezmoi leaves the existing file alone rather
than rewriting it without secrets, and warns on stderr. The rest of the apply completes.
Re-run `chezmoi apply` once `op` is signed in to fill the file in.
Open and unlock 1Password and enable **Settings → Developer → Integrate with
1Password CLI** for a local apply. To deliberately leave secrets alone, run
`chezmoi apply --skip-secrets`.

`[onepassword] mode = "account"` needs an unlocked 1Password **desktop app** in the calling
session, so over SSH the secrets never resolve by design: apply completes, `~/.config/environment`
stays as it was, and it refreshes on the next apply from a local session. See
[`docs/headless.md`](docs/headless.md).

```bash
# Arch (installed automatically by the package lists)  /  macOS: via Brewfile
op signin
```

Enable the SSH agent in the 1Password desktop app: **Settings → Developer → SSH Agent**.

On **WSL** there is no 1Password agent to talk to: the Linux app isn't installed, and the Windows one is out of reach because the distro runs with `[automount] enabled=false` (no `/mnt/c`, so no `powershell.exe` and no bridge). That profile uses the plain OpenSSH agent instead — `ssh-agent.socket` (enabled by `run_once_after_60-wsl.sh`) with `SSH_AUTH_SOCK` set in `.zshrc`, so `AddKeysToAgent yes` loads a key from `~/.ssh` on first use. Git over HTTPS is unaffected: it authenticates through `gh auth git-credential`.

Secrets on WSL come from a plain CLI session instead, since `op signin` without the app prompts for the account password on every call. The WSL profile sets `[onepassword] prompt = false` and `.chezmoiignore` probes with `op whoami` (which never prompts), so sign in and apply from the same shell:

```bash
eval "$(op signin)" && chezmoi apply
```

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
| `30-oh-my-zsh`, `31-zsh-plugins`, `32-tmux-plugins` | Oh My Zsh, zsh plugins, tpm | `~/.oh-my-zsh`, `~/.config/tmux/plugins` |
| `33-rustup` | rustup via rustup.rs (`--no-modify-path`) | `~/.cargo` |
| `34-dotnet` | .NET LTS via dotnet-install.sh | `~/.dotnet` (`$DOTNET_ROOT`) |
| `35-npm-globals` | fnm Node LTS + global npm packages | fnm prefix |
| `40-aspire` | Aspire CLI, standalone build | `~/.aspire/bin` |
| `44-lazyboards` | `go install` lazyboards | `~/go/bin` |

`main`-profile only: `38-opt-webp` (libwebp into `/opt/webp`), `39-pen` (Pen via `~/.config/scripts/install-pen.sh`). `23-tailscale` runs on `main` and `wsl`: it enables `tailscaled` on both, and on `main` also fixes the NetworkManager/systemd-resolved wiring MagicDNS depends on (see below). WSL has no NetworkManager and owns `/etc/resolv.conf` itself, so there tailscaled uses its direct DNS mode instead.

Two non-obvious ones:

- **`35-npm-globals`** installs an fnm-managed Node first if the current one is `system` or absent. Without it npm resolves to the system (Homebrew) prefix, which can be foreign-owned — global installs then fail with `EACCES`.
- **`50-jetbrains-wayland`** is a `run_after_` (every apply, not once): it appends `-Dawt.toolkit.name=WLToolkit` (native Wayland rendering, JBR 21+ / 2024.2+) and `-Dsun.java2d.uiScale.enabled=true` to each IDE's `*64.vmoptions` under `~/.config/JetBrains/<IDE><version>/`, idempotently; new JetBrains IDEs only create that file after their first launch, so the flags land on the apply after that.

Docker and sysbox (Docker-in-Docker) have their own sections below.

## Shell history

`Ctrl-R` is [Atuin](https://atuin.sh/) on every profile: a sqlite-backed search TUI with vim keys, seeded from the old plain histfile by `36-atuin`. **Local only** — no account, no sync, no network (the sync server is a separate package that isn't installed). `↑` stays plain zsh recall. The binding is handed to `zsh-vi-mode`'s `zvm_after_init_commands` hook rather than bound inline, because that plugin re-inits at the first prompt and silently overwrites anything `.zshrc` bound. See [`docs/atuin.md`](docs/atuin.md) for that trap and for the self-hosted-sync recipe.

## Gaming / sim-rig host

`gaming = true` (the desktop; see [`docs/gaming.md`](docs/gaming.md) for hardware, the two-session split, and the Fanatec/Sunshine pitfalls, and [`docs/nvidia.md`](docs/nvidia.md) for the DLSS / Smooth Motion / Reflex / DLSS 5 runbook) adds:

- `arch-gaming.txt` + `arch-aur-gaming.txt` — Steam, `gamescope-session-cachyos`, Sunshine, `hid-fanatecff-dkms`. **CachyOS-only**: several of these aren't in stock Arch's repos and would abort the whole transaction.
- `nvrun` (`~/.local/bin`) — Steam launch-option wrapper that turns NVIDIA's Linux env vars (DLSS override, Smooth Motion, Reflex, the DLSS 5 ReShade route) into flags.
- `26-gaming` — the glue the packages don't do and that fails *silently* when missing: `games` group (hid-fanatecff's udev rules grant wheelbase access to it, and nothing adds you — without it the wheel enumerates as a plain joystick with no force feedback and no error anywhere), `gamemode` group, udev reload, and `scx_loader` for the latency-oriented `scx_lavd` scheduler.
Two sessions run from the same greetd: niri for the desktop *and* for sim racing native-fullscreen, `gamescope-session-cachyos` for couch gaming on the TV. Sims deliberately do not run under gamescope.

`28-firewall` runs on every Linux `main` machine and opens Sunshine's ports only when `gaming = true`.

## SSH access

SSH access is part of the baseline on all native machines. On CachyOS, two scripts configure the daemon and its firewall:

- `27-sshd` — enables `sshd.service`. Hardening (`PasswordAuthentication no`, `PermitRootLogin no`) is written to `/etc/ssh/sshd_config.d/10-hardening.conf` **only once `~/.ssh/authorized_keys` is non-empty**. Writing it against an empty key file would lock out every remote login on a box whose whole point is being headless. Until then the script prints the `ssh-copy-id` + re-run instructions.
- `28-firewall` — enables ufw and opens port 22 on the home LAN (`192.168.1.0/24`) and `tailscale0`, plus LocalSend and, on a `gaming` host, Sunshine's ports. Other networks use Tailscale; a different trusted LAN needs an explicit subnet rule. The SSH rule uses plain `allow`: the previous `limit` rule rejected idle sessions on their own retransmits.

On macOS, `27-sshd` enables the system's Remote Login service and verifies that it is on. macOS manages allowed users in **General → Sharing → Remote Login**. The legacy WSL profile keeps its terminal setup without enabling a separate inbound SSH server.

PostgreSQL clients (`psql`, `pg_dump`, `pg_restore`, `libpq`) and DNS tools are shared development tools. Linux installs `postgresql-libs` and `bind` from `arch-terminal.txt`; macOS installs Homebrew `libpq`, adds its binaries to the shell PATH, and uses its built-in DNS tools. No PostgreSQL server is installed or started by this change.

The firewall half is the one that bites, because its failure mode is indistinguishable from a dead service. ufw's default inbound policy is `DROP`, and CachyOS's installer can leave ufw *enabled with an empty rule set* — at which point `systemctl status sshd` is green, `Server listening on 0.0.0.0 port 22` is in the journal, `ss -tlnp` shows the socket, and every inbound SYN is still dropped in netfilter before sshd sees it. There is no log line for a packet that never arrives, so the journal shows nothing at all. Diagnose it with:

```bash
sudo ufw status verbose     # "Status: active" + no 22/tcp rule == this bug
journalctl -u sshd -n 20    # zero connection lines == packets aren't arriving
```

`28-firewall` adds its rules *before* enabling ufw, so it is safe to run over an existing SSH session.

The second trap is the mirror image: `ENABLED=yes` in `/etc/ufw/ufw.conf` is *not* `ufw.service`. Arch's `ufw enable` flips that flag and loads the chains for the current boot only, so a box enabled once comes back from a reboot with the config claiming the firewall is on and netfilter empty. ufw's own `is_enabled()` reads the config, not the kernel, so in that split state every `ufw allow` takes the reload path, fails to flush chains that don't exist, and aborts with a bare `ERROR: problem running` — which is why `28-firewall` reconciles the state before adding rules and runs `systemctl enable ufw` at the end.

### Reaching it from outside the LAN

Over Tailscale, so nothing is forwarded on the router and the tailnet is the perimeter. From any device signed into the tailnet, anywhere:

```bash
ssh amd-desktop    # the devHost entry from private_dot_ssh/config.tmpl
```

The target comes from the `devHost` data var rather than a hostname baked into the ssh config, and the block is skipped when `devHost` equals `.chezmoi.hostname` — no machine carries an alias pointing at itself, and Tailscale derives the MagicDNS name from the system hostname, so that comparison is exact. Renaming the desktop is a one-line config change on each client.

`HostName` is the **short** MagicDNS name rather than the FQDN: the tailnet suffix is pushed to every member as a DNS search domain, so the short name resolves on its own and the tailnet ID stays out of this repo. Set `devHost` to `<host>.<tailnet>.ts.net` on a client that has MagicDNS off. `28-firewall`'s `tailscale0` rule is what lets the connection in; the LAN rule separately allows the local subnet.

MagicDNS is the fragile part, and it fails quietly. NetworkManager writes `/etc/resolv.conf` as a regular file by default, which is what makes `tailscale status` report *"systemd-resolved and NetworkManager are wired together incorrectly"*. Lookups usually still work — NM writes `nameserver 127.0.0.53`, which is resolved's stub — but NM owns that file and rewrites it on interface changes, so one reconnect can swap in the router's DNS and `*.ts.net` stops resolving with nothing in any log. `23-tailscale` installs `system/NetworkManager/10-dns-systemd-resolved.conf` (`dns=systemd-resolved` + `rc-manager=unmanaged`) and symlinks `/etc/resolv.conf` to resolved's stub. Check it with:

```bash
resolvectl status | head -3           # want "resolv.conf mode: stub", not "foreign"
tailscale status                      # health warnings print after the peer list
resolvectl query amd-desktop.<tailnet>.ts.net
```

Per-link scoping is the point: resolved sends `*.ts.net` to `100.100.100.100` on `tailscale0` and everything else to the LAN resolver. Flattening every interface into one `resolv.conf` loses that.

### Headless boot

`headless = true` adds a second limine entry, `CachyOS (headless)`, that boots the same kernel with `systemd.unit=multi-user.target` — TTY login, sshd, Tailscale and docker, but no greetd, no compositor and no GPU session. The normal `CachyOS` entry is untouched. See [`docs/headless.md`](docs/headless.md) for the reasoning, the kernel-update caveat, and recovery.

Nothing is disabled or masked to achieve it: `greetd.service` stays enabled, and `graphical.target` — the thing that pulls it in — is simply never reached. That is why the graphical half stays byte-identical to the laptop's, and why a broken desktop is always one menu entry away from a working boot.

The desktop is then started on demand:

```bash
desktop up niri         # autologin into niri, works over SSH
desktop up gamescope    # autologin into the couch-gaming session
desktop greeter         # dux-greeter on the monitor; type the password at the desk
desktop down            # back to a plain TTY
```

`desktop greeter` is plain `systemctl start greetd`, which is useless from an SSH shell because somebody has to type a password. `desktop up` runs `greetd-autologin@<session>.service` — the same greetd, against a config whose `[initial_session]` logs straight in. That is the path couch gaming needs: Sunshine has nothing to capture until somebody is logged in, and finding that out from the sofa is the classic failure. Logging out of an autologin session drops you at dux-greeter, so the session picker is still reachable.

`49-headless-boot` writes the limine entry (above the `comment: machine-id=` line, so `limine-entry-tool` does not eat it on the next kernel update), sets `default_entry` by name and `remember_last_entry: no`, and installs the autologin configs plus `system/greetd/greetd-autologin@.service`.

## UPS

`ups = true` (the desktop) installs [NUT](https://networkupstools.org/) and points it at the Tecnoware EXA Plus 1500 on USB. A power cut then ends in a clean shutdown rather than a hard stop, and the UPS is told to cut its own output on the way down so it still has charge left to bring the box back when mains returns.

Two triggers, whichever comes first: the UPS raising `LB`, or **five minutes on battery**. The timer is the one that matters — a Megatec/Q\* unit derives `LB` from an uncalibrated voltage curve, so on an aged battery it arrives late or not at all, and `battery.charge` can still read 60% as the inverter gives up. Flickers cost nothing; the timer is cancelled on `ONLINE`.

```bash
upsc exa ups.status           # OL / OB / OB LB / OL CHRG
journalctl -u nut-monitor -f  # watch events live
```

`upsd` binds loopback only, so `28-firewall` has nothing to open. The shared `upsd`/`upsmon` password is generated on the machine and never enters this repo — `system/nut/` tracks the two files that need it as `.in` templates with a placeholder.

Two things the config cannot do for you: **plug the USB data cable in** (without it every unit still starts and protects nothing), and set the BIOS to *Restore AC Power Loss → Power On*, without which the killpower shutdown is a one-way trip. See [`docs/ups.md`](docs/ups.md).

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

## File transfer between devices (AirDrop alternative)

[LocalSend](https://localsend.org/) — native on Linux, macOS, Android and iOS, LAN-only, no account and no cloud hop. Installed by the package lists (`localsend-bin` on Arch, `cask "localsend"` on macOS); the phones are a manual store install.

Discovery is UDP multicast to `224.0.0.167:53317`, transfer is a direct HTTPS connection on `53317/tcp`. `28-firewall` opens both on the home LAN for every Linux `main` machine — the split matters when something breaks: **device never appears** is the UDP rule missing, **device appears but sends stall at 0%** is the TCP one. Off the home LAN there is no permitted multicast discovery, so add the peer by its MagicDNS IP; `53317/tcp` is open on `tailscale0` for that. On a headless-booted desktop nothing listens at all until a session is up — `tailscale file cp` works there instead, since it is served by `tailscaled`.

See [`docs/localsend.md`](docs/localsend.md) for the protocol detail, why `-bin` over the source PKGBUILD, and the browser-based fallbacks for a machine you can't install on.

## Security-key unlock (FIDO2)

Every Linux `main` machine installs `pam-u2f` + `libfido2` and
`run_onchange_after_53-fido.sh.tmpl` mirrors `system/pam/dankshell-u2f` into
`/etc/pam.d/`, the service DMS's **Security key** lock-screen toggle points at.
Nothing changes until a FIDO2 key is enrolled (`pamu2fcfg > ~/.config/Yubico/u2f_keys`)
and the toggle is on; from then on a touch plus the key's fingerprint or PIN
unlocks, and the password still works. The repo's service deliberately drops
DMS's `nouserok` (an unlock with no enrollment) and requires user verification
by the key, so a key left in the dock is not an unlock for whoever sits down.
See [`docs/fido.md`](docs/fido.md) for which key to buy and the enrollment steps.

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
enables `nvidia-{suspend,resume,hibernate,suspend-then-hibernate}.service`.
The script is a no-op on hosts without `nvidia-suspend.service` installed. A
reboot is required after first apply for the modprobe option to take effect.
The same file sets `NVreg_TemporaryFilePath=/var/tmp`: the driver stages
preserved VRAM in a file, and the default `/tmp` is tmpfs, which would just
inflate a hibernation image.

### Hibernation (TUXEDO laptop)

CachyOS installs zram-only swap, so a fresh machine cannot hibernate: there
is nothing on disk to write the image to. `run_once_after_48-hibernate.sh.tmpl`
(gated on the `tuxedo` flag) fixes that on first apply:

- creates a top-level Btrfs subvolume `@swap`, mounted at `/swap` from fstab
  like the other `@` subvolumes, so snapper never snapshots the swapfile and
  a rollback cannot strand `resume_offset`;
- creates `/swap/swapfile` sized to RAM with `btrfs filesystem mkswapfile`
  (NOCOW, no compression) and adds it to fstab at `pri=10` — zram stays at
  100, so everyday swapping still lands in RAM;
- appends `resume=UUID=… resume_offset=…` to the existing
  `KERNEL_CMDLINE[default]` line in `/etc/default/limine` and runs
  `limine-update`. The initramfs uses the `systemd` hook, which resumes from
  those parameters on its own;
- installs `sleep.conf.d/hibernate.conf` (`HibernateDelaySec=2h`) and
  `logind.conf.d/hibernate.conf` (lid close → `suspend-then-hibernate`, on
  battery and on mains).

The kernel only picks up the new command line on the next boot. Test with
`systemctl hibernate` after that reboot, and confirm the kernel saw the
parameters with `cat /proc/cmdline`. If the swapfile is ever recreated the
offset changes: re-run the script (its content hash is unchanged, so render
it by hand: `chezmoi execute-template < run_once_after_48-hibernate.sh.tmpl | bash`),
which strips the old `resume*=` parameters before appending the new ones.

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
- `system/` — files outside `$HOME` (greetd/dux-greeter + the on-demand autologin unit, docker daemon.json + iptables modules, the two NetworkManager drop-ins: connectivity check and DNS; the NUT config set; the Stream Deck udev rule + unit and the `desktop` polkit rule, as `.in` templates; the lock-screen `pam_u2f` service); mirrored to `/etc` by `run_once_after_45-greetd.sh.tmpl` / `run_once_after_49-headless-boot.sh.tmpl` / `run_once_after_25-sysbox.sh.tmpl` / `run_once_after_29-captive-portal.sh.tmpl` / `run_once_after_23-tailscale.sh.tmpl` / `run_onchange_after_51-ups.sh.tmpl` / `run_onchange_after_52-streamdeck.sh.tmpl` / `run_onchange_after_53-fido.sh.tmpl` via sudo.
- `deckd/` — the Stream Deck panel daemon (Go module), built into `~/.local/bin/deckd` by `52-streamdeck`; not deployed as a file.
- `docs/` — reference material not deployed anywhere (`gaming.md`, `nvidia.md`, `headless.md`, `atuin.md`, `localsend.md`, `ups.md`, `streamdeck.md`, `fido.md`, `wslconfig.example`).
- DMS runtime files (`settings.json`, `niri/dms/outputs.kdl`) are chezmoi `create_` entries: seeded once on a fresh machine, then owned by DMS — `chezmoi apply` never overwrites them.

## Recovery

If greetd fails on boot: switch to TTY2 (`Ctrl+Alt+F2`) and run
`sudo systemctl disable --now greetd` to fall back to plain TTY login.

If the login screen isn't dux-greeter, a different display manager owns the seat:

```bash
readlink -f /etc/systemd/system/display-manager.service   # who holds the alias
systemctl is-enabled sddm greetd
```

`chezmoi apply` disables whatever it finds there in favour of greetd, effective
next reboot. It never stops the running one — that would kill the session mid-apply.
