# Dotfiles — Arch Linux / macOS (chezmoi)

Cross-platform dotfiles managed with chezmoi. Primary target is an Arch Linux laptop running niri (Wayland, primary) with Hyprland kept as an alternate session selectable at greetd. Terminal-only configs (zsh, tmux, neovim, yazi, ghostty, lazygit, bat) are shared with macOS.

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
| `.tmpl` suffix | Template processed by chezmoi |

## Stack

| Layer | Tool | Config path | Notes |
|---|---|---|---|
| Display manager / greeter | greetd + regreet (via cage) | `/etc/greetd/{config,regreet}.{toml,css}` (mirrored from `system/greetd/` by `run_once_after_45-greetd.sh.tmpl`) | Linux-only, system-level. Themed via custom `regreet.css` (Glassmorphic Dark). Pacman hook in `system/pacman-hooks/` keeps the broken `hyprland-uwsm.desktop` session hidden across hyprland upgrades. |
| WM / compositor (primary) | niri | `~/.config/niri/` | Scrollable-tiling Wayland compositor, Linux-only; selected as the default greetd session. Config is `dot_config/niri/config.kdl` (KDL); hot-reloads on save. |
| Shell (primary; bar/launcher/notif/lock/idle/session/wallpaper/OSD) | DankMaterialShell (dms) | pulled in by `systemctl --user add-wants niri.service dms` | Quickshell+QML+Go single daemon; auto-started via niri's `Wants=dms`. IPC via `dms ipc call <module> <action>`. |
| WM / compositor (alternate) | Hyprland | `~/.config/hypr/` | Wayland, Linux-only; selectable at greetd. |
| Shell (alternate, paired with Hyprland) | noctalia-shell | `~/.config/noctalia/` | Quickshell-based single daemon; configured via in-app GUI; IPC via `qs -c noctalia-shell ipc call ...` |
| Auth agent | polkit-gnome | — | GUI auth dialogs; started via exec-once, Linux-only |
| Terminal | Ghostty | `~/.config/ghostty/` | Cross-platform |
| File manager (TUI) | yazi | `~/.config/yazi/` | Cross-platform; only `theme.toml` tracked |
| Editor | Neovim | `~/.config/nvim/` | Cross-platform, Lua-based |
| Editor (IDE) | IdeaVim | `~/.ideavimrc` | Cross-platform, JetBrains plugin |
| Multiplexer | tmux | `~/.config/tmux/tmux.conf` or `~/.tmux.conf` | Cross-platform |
| Shell | zsh | `~/.zshrc` | Cross-platform, Oh My Zsh |
| Git TUI | lazygit | `~/.config/lazygit/` | YAML config, cross-platform |
| Syntax highlighting | bat | `~/.config/bat/` | Config + tmTheme, cross-platform |
| System info | neofetch | `~/.config/neofetch/` | Shell-like config, cross-platform |
| Git config | git | `~/.config/git/` | Cross-platform |
| Env overrides | direnv | per-project `.envrc` | Cross-platform; loads env per directory |
| Dotfile mgr | chezmoi | `~/.local/share/chezmoi/` | Source of truth |

## System theme

Glassmorphic Dark - translucent surfaces with blur effects and warm gold accents on a dark base. Core principle: **depth through transparency and blur** rather than solid colors.

### Glassmorphic Dark palette

| Token | Value | Usage |
|---|---|---|
| `bg-solid` | `#1a1a1e` | Opaque fallbacks |
| `bg-glass` | `rgba(20,20,24,0.55)` | noctalia panels |
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

Applied to: niri (borders + shadow in `dot_config/niri/config.kdl`), DankMaterialShell (theming via its own settings + matugen integration), Hyprland, noctalia-shell (custom user color scheme: "Glassmorphic Dark"), Ghostty, yazi, Neovim (catppuccin macchiato), regreet (`/etc/greetd/regreet.css`).

### Wallpaper

Wallpapers live in `~/Pictures/Wallpapers/`. Pick/change via noctalia Settings → Wallpaper (Hyprland session) or DMS's wallpaper module (niri session). The current selection is persisted differently by each shell:

- **DMS (niri)** writes `~/.local/state/DankMaterialShell/session.json` (`wallpaperPath`, or `monitorWallpapers` when `perMonitorWallpaper` is true).
- **noctalia (Hyprland)** writes `~/.cache/noctalia/wallpapers.json`.

The greetd install script (`run_once_after_45-greetd.sh.tmpl`) resolves the greeter background in this precedence — **DMS → noctalia → first file in `~/Pictures/Wallpapers/`** — and mirrors the result to `/var/lib/regreet/background.jpg` so the login screen matches the desktop. The sync runs on `chezmoi apply`; if you change wallpaper mid-session, re-run apply before the next reboot to refresh the greeter background. Under niri, the `layer-rule { match namespace="^quickshell$"; place-within-backdrop true; }` in `dot_config/niri/config.kdl` places DMS's wallpaper inside niri's overview backdrop, so the overview shows the wallpaper instead of a solid color.

### Blur configuration

| Component | Blur | Notes |
|---|---|---|
| niri | no native window blur | Compositor doesn't support per-window blur; transparent terminals show wallpaper through the transparent workspace background. |
| Hyprland | size=6, passes=3 | Window blur (Hyprland session only) |
| Ghostty | opacity=0.88 | Terminal transparency |
| DankMaterialShell | no panel blur on niri | Quickshell layer is placed within niri's backdrop rather than blurred. |
| noctalia-shell | layerrule blur on `noctalia-background-.*` | Bar/panel/launcher blur-through (Hyprland session only) |

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

- **Templates** (`.tmpl` suffix) — use for any file that differs between Linux and macOS. Currently used for `environment.tmpl` (secrets via 1Password).
- **OS branching** — use `{{ if eq .chezmoi.os "linux" }}` / `{{ if eq .chezmoi.os "darwin" }}`.
- **`.chezmoiignore`** — gates Linux-only config paths behind `{{ if ne .profile "main" }}` (`.config/niri`, `.config/hypr`, `.config/noctalia`, `.config/ghostty`).
- **Secrets** — never commit plaintext. Use chezmoi's password-manager integration or `age` encryption.
- After any change: `chezmoi diff` → review → `chezmoi apply`.

## Platform rules

| Scope | Linux | macOS | Shared |
|---|---|---|---|
| niri, DankMaterialShell, polkit-gnome | ✓ | — | — |
| Hyprland, noctalia-shell (alternate session) | ✓ | — | — |
| Neovim, tmux, zsh, yazi, Ghostty, lazygit, bat, neofetch, git, IdeaVim | ✓ | ✓ | ✓ |
| Package manager | pacman / yay (AUR) | brew | — |

When editing a **shared** config, always test or reason about both platforms. Use chezmoi templates or runtime `if` guards when a value must differ (paths, clipboard commands, etc.).

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

# Hyprland (alternate session; changes auto-reload on save)

# noctalia-shell (alternate session; single daemon; restart by killing + relaunching)
qs -c noctalia-shell                                     # Run shell (also via exec-once)
qs -c noctalia-shell ipc call launcher toggle            # Open launcher
qs -c noctalia-shell ipc call lockScreen lock            # Lock
qs -c noctalia-shell ipc call sessionMenu toggle         # Power menu
qs -c noctalia-shell ipc call settings toggle            # In-app settings GUI
qs -c noctalia-shell ipc call state all                  # Dump current state

# direnv
direnv allow                      # Trust .envrc in current directory
direnv edit .                     # Create/edit .envrc and auto-allow
```

## Editing guidelines

When editing configs, you're working with **source files** using chezmoi naming (e.g., `dot_config/waybar/config.jsonc` → `~/.config/waybar/config.jsonc`). After editing, run `chezmoi apply` to sync changes to the home directory.

1. **niri** (`dot_config/niri/config.kdl`) — KDL format, hot-reloads on save of the target file (so `chezmoi apply` triggers a live reload). Binds use `Mod+<Key> { <verb>; }` syntax. Two orthogonal axes: horizontal **columns** (`focus-column-left/right`, `Mod+H`/`Mod+L`) and vertical **workspaces** (`focus-workspace-up/down`, `Mod+[`/`Mod+]`); windows can additionally **stack inside a column** (`focus-window-up/down`, `Mod+J`/`Mod+K`) — build a stack with `Mod+,`/`Mod+.` (`consume-or-expel-window-left/right`), toggle to tabbed display with `Mod+G`. Pop!_OS-style program keys: `Mod+Q` closes, `Mod+T` opens terminal. The bind list is long — read `config.kdl` before adding new ones, and verify in-session with `Mod+/` (hotkey overlay). Wire shell features through `dms ipc call <module> <action>`.
2. **DankMaterialShell** — Quickshell+QML+Go shell, auto-started by `niri.service` via `Wants=dms`. All shell features (panels, launcher, notifications, control center, lock, power menu, wallpaper, OSD) are reached via `dms ipc call <module> <action>` — never spawn its components directly from binds. The `layer-rule { match namespace="^quickshell$"; place-within-backdrop true; }` in the niri config is what makes the wallpaper visible in niri's overview. Plugins live in DMS's plugin system (Quickshell QML modules); registry at <https://danklinux.com/plugins>.
3. **Hyprland** (`dot_config/hypr/hyprland.conf` and splits, alternate session) — Hyprland DSL, not JSON/TOML. Changes hot-reload after apply. Always define new keybinds with `$mainMod`. Wire shell features through the `$ipc` variable (`$ipc = qs -c noctalia-shell ipc call`). Keep `exec-once` block tidy and grouped.
4. **noctalia-shell** (alternate session, paired with Hyprland) — Configured via the in-app Settings GUI (open with SUPER+R). User color schemes live in `~/.config/noctalia/color-schemes/`. Don't hand-edit JSON unless reproducing it on a new machine — let the GUI write it, then `chezmoi add ~/.config/noctalia` to capture. Docs: <https://docs.noctalia.dev/v4/>. Full IPC reference: <https://docs.noctalia.dev/v4/getting-started/keybinds/>.
5. **Neovim** — Lua config under `~/.config/nvim/`. Respect existing plugin manager and structure. Don't switch plugin managers without asking.
6. **tmux** — Single config file. Prefer `~/.config/tmux/tmux.conf` (XDG) if already set up that way.
7. **zsh** — Oh My Zsh framework. Keep `.zshrc` lean. Shared aliases/functions should work on both GNU and BSD coreutils.
8. **yazi** — TOML config. Cross-platform; only `theme.toml` currently tracked. Avoid Linux-only previewer commands without a macOS fallback.
9. **Ghostty** — Plain config file. Cross-platform terminal emulator.
10. **lazygit** — YAML config (`config.yml`). Cross-platform Git TUI.
11. **bat** — Config file + theme. Cross-platform syntax highlighter.
12. **git** — Standard git config format. Cross-platform.
13. **IdeaVim** — Vim-like config at `~/.ideavimrc`. Cross-platform JetBrains Vim emulation.
14. **greetd / regreet** — Source files in `system/greetd/` (`config.toml`, `regreet.toml`, `regreet.css`, `environments`) and `system/pacman-hooks/hide-uwsm-session.hook`. They are NOT under `$HOME`, so chezmoi can't sync them directly — `run_once_after_45-greetd.sh.tmpl` mirrors them into `/etc/greetd/` and `/etc/pacman.d/hooks/` via `sudo install`. The script reruns when its content hash changes; if you only edit a tracked sub-file (`regreet.css`, etc.) you can force a rerun with `chezmoi apply` after touching the script, or render+execute it directly: `chezmoi execute-template < run_once_after_45-greetd.sh.tmpl | bash`. Reboot or `sudo systemctl restart greetd` to see CSS/config changes (regreet only loads them on greeter start). The pacman hook fires on every `hyprland` install/upgrade and re-applies `Hidden=true` to `/usr/share/wayland-sessions/hyprland-uwsm.desktop` — only the plain `hyprland.desktop` session works on this machine.

## Workflow

Since we're working directly in the chezmoi source directory:

- **Edit source files directly** — no need for `chezmoi edit` or `chezmoi cd`
- **Git operations happen here** — commit, push, pull as normal
- **Apply after editing** — run `chezmoi diff` → `chezmoi apply` to sync to `~/`
- **One concern per commit** — prefix with tool name: `niri: rebind column ops`, `dms: tweak control center spacing`, `noctalia: tweak control center`, `nvim: configure LSP`
- **Adding new files** — use `chezmoi add ~/.config/foo/bar` to track a file (creates source entry with correct naming)
- **Templates** — if a config must differ per-OS, convert with `chezmoi chattr +template <file>`

## Documentation resources

For up-to-date documentation, use Context7 MCP:

| Tool | Context7 library ID |
|---|---|
| niri | resolve via `mcp__context7__resolve-library-id` (search "yalter/niri"); fallback to the wiki at <https://github.com/YaLTeR/niri/wiki> |
| Hyprland | `/websites/wiki_hypr_land` |

For DankMaterialShell, the repo is <https://github.com/AvengeMedia/DankMaterialShell>, docs are at <https://danklinux.com/docs/dankmaterialshell/>, and the plugin registry is at <https://danklinux.com/plugins>.

For noctalia-shell, fetch the docs site directly (no Context7): <https://docs.noctalia.dev/v4/>.

Query with `mcp__context7__resolve-library-id` (to find library IDs) and `mcp__context7__query-docs` (to fetch docs).

## What NOT to do

- Don't install packages — suggest the command, let me run it.
- Don't change the shell (it's zsh everywhere).
- Don't restructure the chezmoi source directory layout without asking.
- Don't convert working non-template files to templates unless there's an actual cross-platform difference.
- Don't add compositor/WM keybinds that conflict with existing ones — read `dot_config/niri/config.kdl` first (and `hyprland.conf` if touching the alternate session). `Mod+/` in-session shows niri's full bind list.
