# Dotfiles — Arch Linux / macOS (chezmoi)

Cross-platform dotfiles managed with chezmoi. Primary target is an Arch Linux laptop running niri (Wayland compositor) with DankMaterialShell. Terminal-only configs (zsh, tmux, neovim, yazi, ghostty, lazygit, bat) are shared with macOS.

## Operating context

Claude Code runs directly from the chezmoi source directory (`~/.local/share/chezmoi/`). This means:

- The `.claude/` folder and this `CLAUDE.md` are tracked with the dotfiles
- File paths use chezmoi's naming conventions, not target paths
- Git operations happen here directly (no need for `chezmoi cd`)
- Edits to source files require `chezmoi apply` to take effect in `~/`

### Path mapping reference

| Source path | Target path |
|---|---|
| `dot_config/` | `~/.config/` |
| `dot_zshrc` | `~/.zshrc` |
| `dot_ideavimrc` | `~/.ideavimrc` |
| `private_` prefix | File with restricted permissions |
| `executable_` prefix | File with +x permission |
| `exact_` prefix | Directory managed exactly (extra files removed) |
| `modify_` prefix | Script that rewrites the target: current contents on stdin, new contents on stdout |
| `.tmpl` suffix | Template processed by chezmoi |

## Stack

| Layer | Tool | Config path | Notes |
|---|---|---|---|
| Bootloader | limine (+ `limine-entry-tool`, `limine-snapper-sync`) | `/etc/default/limine`, `/boot/limine.conf` | Linux-only, system-level. On a `headless` host, `system/limine/85-headless-entry` (a `limine-entry-tool` post hook) adds and re-asserts a second entry booting to `multi-user.target`. See `docs/headless.md`. |
| Display manager / greeter | greetd + dux-greeter (`dux-greeter-bin`, AUR) | `/etc/greetd/config.toml` (mirrored from `system/greetd/` by `run_once_after_45-greetd.sh.tmpl`); theme/wallpaper cache in `/var/cache/dms-greeter`, filled by `dms-greeter sync` | Linux-only, system-level. Same look as the dux lock screen; hosts its own minimal niri session (config generated at `/etc/greetd/niri/config.kdl`). |
| WM / compositor | niri | `~/.config/niri/` | Scrollable-tiling Wayland compositor, Linux-only; selected as the default greetd session. Config is `dot_config/niri/config.kdl` (KDL); hot-reloads on save. |
| Shell (bar/launcher/notif/lock/idle/session/wallpaper/OSD) | DankMaterialShell (dms) | pulled in by `systemctl --user add-wants niri.service dms` | Quickshell+QML+Go single daemon; auto-started via niri's `Wants=dms`. IPC via `dms ipc call <module> <action>`. |
| Auth agent | polkit-gnome | — | GUI auth dialogs; started via exec-once, Linux-only |
| Captive-portal login | NetworkManager connectivity check + `captive-portal.service` | `system/NetworkManager/20-connectivity.conf` (mirrored to `/etc/NetworkManager/conf.d/` by `run_once_after_29-captive-portal.sh.tmpl`), `dot_config/niri/scripts/executable_captive-portal-watch.sh` | Linux-only, `main` profile. Opens a private Zen window when NM reports connectivity `portal`. Watcher is pulled in by `niri.service` via `Wants=`, like dms. |
| Terminal | Ghostty | `~/.config/ghostty/` | Cross-platform |
| File manager (TUI) | yazi | `~/.config/yazi/` | Cross-platform; only `theme.toml` tracked |
| File transfer | LocalSend | — (no tracked config) | Cross-platform (Linux/macOS/Android/iOS). AirDrop alternative. Needs `53317` tcp+udp, opened by `28-firewall` on all Linux `main` machines for the home LAN, plus tcp on Tailscale. See `docs/localsend.md`. |
| Editor | Neovim | `~/.config/nvim/` | Cross-platform, Lua-based |
| Editor (IDE) | IdeaVim | `~/.ideavimrc` | Cross-platform, JetBrains plugin |
| Multiplexer | tmux | `~/.config/tmux/tmux.conf` or `~/.tmux.conf` | Cross-platform |
| Shell | zsh | `~/.zshrc` | Cross-platform, Oh My Zsh |
| Shell history | atuin | `~/.config/atuin/config.toml` | Cross-platform; local-only (no account/sync/network), sync recipe in `docs/atuin.md` |
| Git TUI | lazygit | `~/.config/lazygit/` | YAML config, cross-platform |
| Syntax highlighting | bat | `~/.config/bat/` | Config + tmTheme, cross-platform |
| System info | neofetch | `~/.config/neofetch/` | Shell-like config, cross-platform |
| Git config | git | `~/.config/git/` | Cross-platform |
| Env overrides | direnv | per-project `.envrc` | Cross-platform; loads env per directory |
| UPS | NUT (`nut`) | `/etc/nut/*` (mirrored from `system/nut/` by `run_onchange_after_51-ups.sh.tmpl`) | Linux-only, system-level, `ups` gate. Tecnoware EXA Plus 1500 on `nutdrv_qx` (USB `0665:5161`). Clean shutdown on `LB` **or** 5 min on battery, plus killpower at `final.target`. See `docs/ups.md`. |
| Stream Deck panel | `deckd` (Go, `deckd/`) | `~/.local/bin/deckd`, `/etc/udev/rules.d/70-streamdeck.rules`, `/etc/systemd/system/streamdeck.service` (rendered from `system/streamdeck/*.in` by `run_onchange_after_52-streamdeck.sh.tmpl`) | Linux-only, `deck` gate. Original V2 (`0fd9:006d`) driven in pure Go over hidraw; system unit with `User=`, bound to `dev-streamdeck.device`. Status tiles + `desktop`/power keys for the headless desktop. See `docs/streamdeck.md`. |
| Lock-screen security key | `pam-u2f` + `libfido2` | `/etc/pam.d/dankshell-u2f` (mirrored from `system/pam/` by `run_onchange_after_53-fido.sh.tmpl`) | Linux-only, `main`. The service DMS's **Security key** toggle resolves; ours drops `nouserok` and requires key-side user verification (fingerprint, PIN fallback). Enrollment (`pamu2fcfg`) is manual and per key. See `docs/fido.md`. |
| Dotfile mgr | chezmoi | `~/.local/share/chezmoi/` | Source of truth |

## System theme

Glassmorphic Dark - translucent surfaces with blur effects and warm gold accents on a dark base. Core principle: **depth through transparency and blur** rather than solid colors.

### Glassmorphic Dark palette

| Token | Value | Usage |
|---|---|---|
| `bg-solid` | `#1a1a1e` | Opaque fallbacks |
| `bg-glass` | `rgba(20,20,24,0.55)` | Translucent panels |
| `bg-glass-deep` | `rgba(20,20,24,0.75)` | Tooltips, dropdowns |
| `surface` | `#242428` | Terminal bg, raised elements |
| `surface-raised` | `#2c2c31` | Cards, panels |
| `border` | `rgba(255,255,255,0.08)` | Subtle dividers |
| `border-focus` | `rgba(255,255,255,0.15)` | Active window |
| `text-primary` | `#e8e4df` | Body text |
| `text-secondary` | `#9a9590` | Muted labels |
| `text-disabled` | `#5a5752` | Placeholders |
| `accent` | `#c8a67e` | Warm gold - focused elements |
| `accent-muted` | `#8a7560` | Lower intensity accent |
| `urgent` | `#cf6a6a` | Errors |
| `success` | `#7ab88a` | Positive |
| `warning` | `#d4a954` | Warnings |
| `info` | `#6fa3c7` | Informational |

### ANSI Terminal colors

```
0=#1a1a1e, 1=#cf6a6a, 2=#7ab88a, 3=#d4a954, 4=#6fa3c7, 5=#b88aaf, 6=#6abab0, 7=#e8e4df
8=#5a5752, 9=#e08080, 10=#90d0a0, 11=#e8c070, 12=#88b8d8, 13=#d0a0c8, 14=#80d0c8, 15=#faf7f2
```

Applied to: niri (borders + shadow in `dot_config/niri/config.kdl`), DankMaterialShell (theming via its own settings + matugen integration), Ghostty, yazi, Neovim (catppuccin macchiato), dux-greeter (synced from the shell theme by `dms-greeter sync`).

### Wallpaper

Wallpapers live in `~/Pictures/Wallpapers/`. Pick/change via DMS's wallpaper module (`dms ipc call wallpaper next`). DMS writes the selection to `~/.local/state/DankMaterialShell/session.json` (`wallpaperPath`, or `monitorWallpapers` when `perMonitorWallpaper` is true).

The greetd install script (`run_once_after_45-greetd.sh.tmpl`) runs `dms-greeter sync`, which copies the shell's settings, session state (wallpaper) and matugen colors into `/var/cache/dms-greeter/` so the login screen matches the desktop. The greeter reads only that cache, never `$HOME`; if you change wallpaper or Settings → Greeter options mid-session, run `dms-greeter sync` before the next reboot. The `layer-rule { match namespace="^quickshell$"; place-within-backdrop true; }` in `dot_config/niri/config.kdl` places DMS's wallpaper inside niri's overview backdrop, so the overview shows the wallpaper instead of a solid color.

### Blur configuration

| Component | Blur | Notes |
|---|---|---|
| niri | no native window blur | Compositor doesn't support per-window blur; transparent terminals show wallpaper through the transparent workspace background. |
| Ghostty | opacity=0.95 | Terminal transparency |
| DankMaterialShell | no panel blur on niri | Quickshell layer is placed within niri's backdrop rather than blurred. |

### Window decorations

- `rounding = 12`, `gaps_in = 8`, `gaps_out = 16`
- Active border: `rgba(255,255,255,0.15)`
- Inactive border: `rgba(255,255,255,0.08)`
- Shadow color: `rgba(0,0,0,0.25)`

**Design principles:**
- Dark base with translucent surfaces
- Gold accent (`#c8a67e`) for active/focused states
- Subtle white borders for depth
- Blur-through for glass effect
- Consistent rgba backgrounds across components

## Chezmoi structure

Source state lives in `~/.local/share/chezmoi/`. Key conventions:

- **Templates** (`.tmpl` suffix) — use for any file that differs between Linux and macOS. Currently used for `private_environment.tmpl` (secrets via 1Password, rendered `0600`).
- **OS branching** — use `{{ if eq .chezmoi.os "linux" }}` / `{{ if eq .chezmoi.os "darwin" }}`.
- **`.chezmoiignore`** — gates Linux-only config paths behind `{{ if ne .profile "main" }}` (`.config/niri`, `.config/dms`); Ghostty is shared with macOS. It also gates on **runtime capability**: it probes both `op signin --raw` and `op vault list`, with output discarded and a shared five-second timeout, and ignores `.config/environment` when either fails. The rule for anything secret-bearing is **ignore the target, never render a placeholder**: a secretless file would overwrite working exports on a box that merely could not reach 1Password. `dot_config/private_environment.tmpl` carries no `op` guard of its own; `.chezmoiignore` owns the skip decision. Wrap any `output` probe in `|| echo <fallback>`; a non-zero exit aborts the whole template.
- **Data vars** — `.chezmoi.toml.tmpl` prompts for `profile` (`main`/`wsl`/`mac`), `org`, and the SSH client destination `devHost`/`devUser`. Linux `main` additionally prompts for `gaming`, the `headless` boot policy, and hardware flags `ups`, `deck`, `tuxedo`. All machines share development tools, PostgreSQL clients and DNS tools; native Linux and macOS machines enable SSH. The old `dev` flag is ignored and omitted on re-init. `devHost` is still a client alias target, skipped on the matching host; `devUser` is blank when the local username is correct. No gaming or hardware flag is implied by SSH access.
- **New data vars must be read with `dig`**, not `.foo` — `.chezmoi.toml.tmpl` only runs on `chezmoi init`, so machines whose config predates a prompt would otherwise fail to apply. Use `{{ if dig "gaming" false . }}`, matching `dot_config/private_environment.tmpl`.
- **Files the app rewrites at runtime** — three escape hatches, in order of preference:
  - **`modify_`** when you want to manage *some* keys and let the app own the rest. The source file is a script; chezmoi pipes the current target in on stdin and takes stdout as the new target. Used by `dot_claude/modify_settings.json`, which `jq`-merges a managed block over whatever Claude Code last wrote. Objects merge, **arrays replace**; the merge cannot *delete* a key, so retiring one means adding its path to that script's `RETIRED` list for a release. Emit canonical output (`jq -S`) or every runtime write shows up as a diff.
  - **`create_`** when the file is purely app-owned and only needs seeding on a fresh machine (`dot_config/dms/create_settings.json`, `dot_config/niri/dms/create_outputs.kdl`). Note the cost: later changes never propagate to machines that already have the file.
  - A plain managed file only when the app never writes back. Otherwise `chezmoi apply` silently clobbers runtime state and `chezmoi status` stays dirty forever.
- **Machine- or repo-specific state stays out of the source.** This repo is **public**. `modify_`'s merge is what makes that practical: `~/.claude/settings.json` keeps its machine-local `autoMode.environment` (a trust-boundary map of a *private* work repo — internal domains, CI secret names, absolute paths) while git only ever carries the managed keys. Per-project settings belong in that project's `.claude/settings.local.json`, which is gitignored.
- **Secrets** — never commit plaintext. Use chezmoi's password-manager integration or `age` encryption.
- After any change: `chezmoi diff` → review → `chezmoi apply`.

## Platform rules

| Scope | Linux | macOS | Shared |
|---|---|---|---|
| niri, DankMaterialShell, polkit-gnome | ✓ | — | — |
| Neovim, tmux, zsh, yazi, Ghostty, lazygit, bat, neofetch, git, IdeaVim | ✓ | ✓ | ✓ |
| Package manager | pacman / yay (AUR) | brew | — |
| Captive-portal watcher (`29-captive-portal`) | `main` only | — | — |
| Tailscale (`23-tailscale`); NM/resolved DNS wiring `main` only | `main` + `wsl` | — | — |
| Steam / gamescope-session / Sunshine / Fanatec FFB | `main` + `gaming` | — | — |
| SSH server (`27-sshd`) | `main` | Remote Login | ✓ |
| Scoped ufw rules (`28-firewall`) | `main` | — | — |
| PostgreSQL / DNS clients | `main` + `wsl` | `libpq` + built-in DNS | ✓ |
| NUT / UPS monitoring (`51-ups`), `arch-ups.txt` | `main` + `ups` | — | — |
| Stream Deck panel (`52-streamdeck`, `deckd/`) | `main` + `deck` only | — | — |
| LocalSend | `main` only | ✓ (Brewfile) | — |
| Security-key unlock (`53-fido`, `pam-u2f`) | `main` only | — | — |
| Headless boot entry + on-demand session (`49-headless-boot`) | `headless` only | — | — |
| Hibernation: `@swap` subvolume + swapfile, `resume=` on the limine cmdline, lid → suspend-then-hibernate (`48-hibernate`) | `main` + `tuxedo` | — | — |

When editing a **shared** config, always test or reason about both platforms. Use chezmoi templates or runtime `if` guards when a value must differ (paths, clipboard commands, etc.).

### Gaming / sim-rig host

The desktop (`gaming = true`) runs two modes from the same greetd: niri for the desktop *and* for sim racing native-fullscreen on its attached monitor, and `gamescope-session-cachyos` for couch gaming streamed to the TV. Sims deliberately do **not** run under gamescope. See `docs/gaming.md` for the reasoning, the Fanatec/`hid-fanatecff` pitfalls, and the Sunshine capture constraints (niri is not wlroots-based, so KMS capture is the HDR-capable path). The GPU is an **RTX 4080 (Ada)**: DLSS 4 override, single-frame DLSS FG, Smooth Motion and Reflex apply; Multi Frame Gen and (officially) DLSS 5 do not. All NVIDIA toggles are env vars, wired through the `nvrun` Steam launch-option wrapper (`dot_local/bin/executable_nvrun`, gaming-gated in `.chezmoiignore`) — never per-game `user_settings.py`, which pacman overwrites. The DLSS 5 experiment relies on a leaked, patched NVIDIA runtime and is deliberately not automated; the procedure is `docs/nvidia.md`.

### Headless boot

The desktop is also `headless = true`: limine carries a second entry, `CachyOS (headless)`, that boots the same kernel with `systemd.unit=multi-user.target`, so the box comes up as an SSH target with no greetd, no compositor and no GPU session. Nothing is disabled to achieve it — `graphical.target` is simply never reached. The desktop is started on demand with `desktop up niri` / `desktop up gamescope` (autologin via `greetd-autologin@.service`, works over SSH) or `desktop greeter` (dux-greeter at the desk). See `docs/headless.md`.

## Key commands

```bash
# Chezmoi
chezmoi diff                      # Preview pending changes
chezmoi apply                  # Apply to home directory
chezmoi add ~/.config/foo/bar     # Track a new file
chezmoi add --template ~/.config/foo/baz  # Track as template
chezmoi edit ~/.config/foo/bar    # Edit source state copy (not needed when already in source dir)
chezmoi update                    # Pull remote + apply

# niri (config hot-reloads on save of ~/.config/niri/config.kdl)
niri msg action focus-column-left              # Trigger any action from the CLI
niri msg windows                               # List current windows
niri msg outputs                               # List monitors with modes/positions
niri msg workspaces                            # List workspaces
# Mod+/ in-session opens niri's built-in hotkey overlay (live cheat sheet).

# DankMaterialShell (auto-started under niri via Wants=dms)
dms ipc call spotlight toggle                  # App launcher
dms ipc call control-center toggle             # Quick settings panel
dms ipc call notifications toggle              # Notifications panel
dms ipc call lock lock                         # Lock screen
dms ipc call powermenu toggle                  # Power menu
dms ipc call settings toggle                   # In-app settings GUI
dms ipc call wallpaper next                    # Cycle wallpaper

# On-demand desktop (headless hosts; see docs/headless.md)
desktop up niri                                # autologin session, works over SSH
desktop up gamescope                           # couch-gaming session
desktop greeter                                # dux-greeter on the monitor instead
desktop down                                   # back to a plain TTY
desktop status                                 # what owns vt1

# direnv
direnv allow                      # Trust .envrc in current directory
direnv edit .                     # Create/edit .envrc and auto-allow
```

## Editing guidelines

When editing configs, you're working with **source files** using chezmoi naming (e.g., `dot_config/niri/config.kdl` → `~/.config/niri/config.kdl`). After editing, run `chezmoi apply` to sync changes to the home directory.

1. **niri** (`dot_config/niri/config.kdl`) — KDL format, hot-reloads on save of the target file (so `chezmoi apply` triggers a live reload). Binds use `Mod+<Key> { <verb>; }` syntax. Two orthogonal axes: horizontal **columns** (`focus-column-left/right`, `Mod+H`/`Mod+L`) and vertical **workspaces** (`focus-workspace-up/down`, `Mod+[`/`Mod+]`); windows can additionally **stack inside a column** (`focus-window-up/down`, `Mod+J`/`Mod+K`) — build a stack with `Mod+,`/`Mod+.` (`consume-or-expel-window-left/right`), toggle to tabbed display with `Mod+G`. Pop!_OS-style program keys: `Mod+Q` closes, `Mod+T` opens terminal. The bind list is long — read `config.kdl` before adding new ones, and verify in-session with `Mod+/` (hotkey overlay). Wire shell features through `dms ipc call <module> <action>`.
   **Per-host overrides** go in `dot_config/niri/host.kdl.tmpl`, pulled in by `include "host.kdl"` at the end of `config.kdl`; it renders empty where nothing applies, and must always render (niri fails the whole config on a missing include). On `tuxedo` it carries `include "render.kdl"`: on the hybrid laptop eDP hangs off the Intel iGPU and the external DP port off the RTX 3050, and rendering on the GPU that does not drive the screen means a cross-GPU copy every frame — laggy cursor/animations, worst after a lock/DPMS cycle (niri-wm/niri#3095, #4708). `render.kdl` is untracked runtime state (seeded by `create_render.kdl`): `dot_config/niri/scripts/executable_render-device.sh`, run as an `ExecStartPre` drop-in on `niri.service` (`dot_config/systemd/user/niri.service.d/render-device.conf`), writes `render-drm-device` for the NVIDIA node (plus `emulate-zero-presentation-time`) when anything is connected to the NVIDIA card, else the iGPU node. `render-drm-device` is only read at niri startup, so docking/undocking needs a logout to switch GPUs; power state is deliberately ignored — the GPU driving the screen is what matters.
2. **DankMaterialShell** — Quickshell+QML+Go shell, auto-started by `niri.service` via `Wants=dms`. All shell features (panels, launcher, notifications, control center, lock, power menu, wallpaper, OSD) are reached via `dms ipc call <module> <action>` — never spawn its components directly from binds. The `layer-rule { match namespace="^quickshell$"; place-within-backdrop true; }` in the niri config is what makes the wallpaper visible in niri's overview. Plugins live in DMS's plugin system (Quickshell QML modules); registry at <https://danklinux.com/plugins>. DMS-owned runtime files (`~/.config/DankMaterialShell/settings.json`, `zen.css` (matugen output), `~/.config/niri/dms/outputs.kdl`) are tracked as chezmoi `create_` entries: seeded on a fresh machine, never overwritten by `chezmoi apply` — DMS rewrites them at runtime.
3. **Neovim** — Lua config under `~/.config/nvim/`. Respect existing plugin manager and structure. Don't switch plugin managers without asking.
4. **tmux** — Single config file. Prefer `~/.config/tmux/tmux.conf` (XDG) if already set up that way.
5. **zsh** — Oh My Zsh framework. Keep `.zshrc` lean. Shared aliases/functions should work on both GNU and BSD coreutils. **Keybindings must go through `zvm_after_init_commands`**, never `bindkey`/`eval` inline: `zsh-vi-mode` defers its own init to the first `precmd` and rebinds every keymap, silently wiping anything `.zshrc` bound (applies to atuin, fzf, television — see `docs/atuin.md`).
6. **yazi** — TOML config. Cross-platform; only `theme.toml` currently tracked. Avoid Linux-only previewer commands without a macOS fallback.
7. **Ghostty** — Plain config file. Cross-platform terminal emulator.
8. **lazygit** — YAML config (`config.yml`). Cross-platform Git TUI.
9. **bat** — Config file + theme. Cross-platform syntax highlighter.
10. **git** — Standard git config format. Cross-platform.
11. **IdeaVim** — Vim-like config at `~/.ideavimrc`. Cross-platform JetBrains Vim emulation.
12. **greetd / dux-greeter** — Source file in `system/greetd/` (`config.toml`, plus the `greetd-autologin@.service` unit installed by `49`). It is NOT under `$HOME`, so chezmoi can't sync it directly — `run_once_after_45-greetd.sh.tmpl` mirrors it into `/etc/greetd/` via `sudo install`, then runs `dms-greeter sync`. The script reruns when its content hash changes; to force it, render+execute it directly: `chezmoi execute-template < run_once_after_45-greetd.sh.tmpl | bash`. Reboot or `sudo systemctl restart greetd` (from a TTY/SSH — it kills the running session) to see config changes. The greeter is its own niri session as the `greeter` user: its config is generated by sync at `/etc/greetd/niri/config.kdl`, manual tweaks go in `/etc/greetd/niri_overrides.kdl`. Theme, wallpaper, "remember last user/session" and fingerprint options come from the shell's Settings → Greeter tab and only reach the greeter on the next sync; the greeter never reads `$HOME`. Never install `greetd-regreet`/`cage` alongside: the old regreet files are gone from the source tree.

13. **NUT / UPS** — same split as greetd: sources in `system/nut/`, mirrored to `/etc/nut/` (plus `/etc/tmpfiles.d/` and `/etc/systemd/system/`) by `run_onchange_after_51-ups.sh.tmpl`. Unlike the greetd script this one is `run_onchange` and embeds a `sha256sum` of every mirrored file, so editing one re-triggers the apply — no manual re-run needed. `/etc/nut` is pacman-owned, so upgrades leave `.pacnew` files. Never commit a rendered `upsd.users`/`upsmon.conf`: they carry the shared password.

14. **Captive portal** — same split as greetd: `system/NetworkManager/20-connectivity.conf` is outside `$HOME`, so `run_once_after_29-captive-portal.sh.tmpl` mirrors it into `/etc/NetworkManager/conf.d/` and reloads NM (SIGHUP, no link teardown). The watcher (`dot_config/niri/scripts/executable_captive-portal-watch.sh`) is a normal tracked file. Don't set `response=` in the connectivity stanza — with it unset NM checks for the `X-NetworkManager-Status: online` header instead, and a body string that doesn't match byte-for-byte reports a portal on every network. The browser URL must stay plain-HTTP *and* off the HSTS preload list.

15. **NetworkManager drop-ins** — `system/NetworkManager/` holds one file per concern, numbered as it lands in `/etc/NetworkManager/conf.d/`, and each is installed by the script that owns the feature, not by one shared script: `10-dns-systemd-resolved.conf` by `23-tailscale` (MagicDNS needs resolved to own `/etc/resolv.conf`), `20-connectivity.conf` by `29-captive-portal`. They touch different sections (`[main]` vs `[connectivity]`), so NM merges them. Keep the directory spelled `NetworkManager` — a second `system/networkmanager/` is a distinct path on Linux and would silently collide on a case-insensitive checkout. Always `reload`, never `restart`, NetworkManager in these scripts: a restart drops every active link, and apply can be running over the SSH session it would kill.

16. **Headless boot / limine** — `/boot/limine.conf` is **not** written by `chezmoi apply`. `run_once_after_49-headless-boot.sh.tmpl` only installs `system/limine/85-headless-entry` to `/etc/boot/hooks/post.d/` (plus the `greetd-autologin@.service` + `/etc/greetd/autologin-*.toml` pair); that hook owns the `CachyOS (headless)` entry and re-asserts it after every `limine-entry-tool` run. It must be a hook, not a one-shot write: `limine-entry-tool` rewrites the file on every kernel update. The entry goes directly *above* `/+CachyOS`, and `comment: machine-id=` must stay directly *under* that name line — limine attaches options to the entry above them, and both `limine-entry-tool` and `limine-snapper-sync` find their OS entry by that comment. Put anything between the name and the marker and the machine-id moves to the headless entry: snapper sync reports "no kernel entry" and every kernel update strands another duplicate `/+CachyOS` block. Never write the BLAKE2 `#<hash>` suffix into the entry — it changes on every kernel rebuild and a stale hash is a boot failure. Verify a headless boot with `cat /proc/cmdline`, not by reading `limine.conf`. `run_once` will not re-fire after an edit; re-run it the same way as the greetd script (`chezmoi execute-template < ... | bash`), or just `sudo /etc/boot/hooks/post.d/85-headless-entry`.

17. **Stream Deck / deckd** — same split as NUT: `system/streamdeck/70-streamdeck.rules.in` and `streamdeck.service.in` are rendered (`@USER@` = `id -un`, `@HOME@` = `$HOME`) and installed to `/etc/udev/rules.d/` and `/etc/systemd/system/` by `run_onchange_after_52-streamdeck.sh.tmpl`, which also builds `deckd/` (its own Go module, in `.chezmoiignore`) into `~/.local/bin/deckd`. The script embeds a `sha256sum` of both `.in` files and every `deckd/**/*.go`, `go.mod`, `go.sum`, so editing any of them re-triggers the apply and the service is restarted only if the binary, rule or unit changed. Three traps: the rule must use **`OWNER=`, not `uaccess`** — a headless boot has no seat session, so the uaccess ACL is never granted and deckd just logs "could not open device"; the unit must use **absolute `@HOME@` paths, never `%h`** — in a system unit `%h` is `/root`; and the deck's buttons rely on `system/polkit/49-desktop-units.rules.in` (greetd units + reboot/power-off for your user), which is installed by `49-headless-boot`, not by `52`. `desktop` tries `systemctl --no-ask-password` first and falls back to `sudo`, so it works with or without that rule — but deckd, having no terminal, only works with it.

18. **Security-key unlock / pam_u2f** — same split as NUT: `system/pam/dankshell-u2f` is mirrored to `/etc/pam.d/` by `run_onchange_after_53-fido.sh.tmpl` (hash embedded, cmp-guarded). The file name is load-bearing: it is the service DMS's lock-screen **Security key** toggle resolves, and DMS only leaves it alone because it carries no `BEGIN DMS LOCKSCREEN U2F AUTH` marker — never add one. Never add `nouserok` back: on this standalone service it means an unlock for a user with no `u2f_keys`. Keep the two-line `userverification=1` / `pinverification=1` form from `pam_u2f(8)`, so a key with a fingerprint sensor and a plain key both work. `~/.config/Yubico/u2f_keys` is per key and per origin (`pam://<hostname>`) and is not tracked.

## Workflow

Since we're working directly in the chezmoi source directory:

- **Edit source files directly** — no need for `chezmoi edit` or `chezmoi cd`
- **Git operations happen here** — commit, push, pull as normal
- **Apply after editing** — run `chezmoi diff` → `chezmoi apply` to sync to `~/`
- **One concern per commit** — prefix with tool name: `niri: rebind column ops`, `dms: tweak control center spacing`, `nvim: configure LSP`
- **Adding new files** — use `chezmoi add ~/.config/foo/bar` to track a file (creates source entry with correct naming)
- **Templates** — if a config must differ per-OS, convert with `chezmoi chattr +template <file>`

### UPS

The desktop (`ups = true`) has a Tecnoware EXA Plus 1500 on USB, driven by NUT. `docs/ups.md` has the reasoning; the two traps worth knowing before editing anything under `system/nut/`: **`vendorid`/`productid` must stay pinned** (`nutdrv_qx` picks no subdriver for `0665:5161` on its own and exits "no supported devices found", despite `port = auto`), and **the five-minute `ONBATT` timer in `upssched.conf` is the real shutdown policy** — `LB` on a Q\* unit comes off an uncalibrated voltage curve and can arrive after the inverter has already given up. `upsd.users` and `upsmon.conf` are tracked as `.in` files with an `@UPSPASS@` placeholder; the password is generated on the machine and must never land in the source tree.

## Documentation resources

For up-to-date documentation, use Context7 MCP:

| Tool | Context7 library ID |
|---|---|
| niri | resolve via `mcp__context7__resolve-library-id` (search "yalter/niri"); fallback to the wiki at <https://github.com/YaLTeR/niri/wiki> |

For DankMaterialShell, the repo is <https://github.com/AvengeMedia/DankMaterialShell>, docs are at <https://danklinux.com/docs/dankmaterialshell/>, and the plugin registry is at <https://danklinux.com/plugins>.

Query with `mcp__context7__resolve-library-id` (to find library IDs) and `mcp__context7__query-docs` (to fetch docs).

## What NOT to do

- Don't install packages — suggest the command, let me run it.
- Don't change the shell (it's zsh everywhere).
- Don't restructure the chezmoi source directory layout without asking.
- Don't convert working non-template files to templates unless there's an actual cross-platform difference.
- Don't add compositor/WM keybinds that conflict with existing ones — read `dot_config/niri/config.kdl` first. `Mod+/` in-session shows niri's full bind list.
