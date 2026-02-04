# Dotfiles — Arch Linux / macOS (chezmoi)

Cross-platform dotfiles managed with chezmoi. Primary target is an Arch Linux laptop running Hyprland (Wayland). Terminal-only configs (zsh, tmux, neovim, yazi, ghostty, lazygit, bat) are shared with macOS.

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
| `dot_zprofile` | `~/.zprofile` |
| `dot_ideavimrc` | `~/.ideavimrc` |
| `private_` prefix | File with restricted permissions |
| `executable_` prefix | File with +x permission |
| `exact_` prefix | Directory managed exactly (extra files removed) |
| `.tmpl` suffix | Template processed by chezmoi |

## Stack

| Layer | Tool | Config path | Notes |
|---|---|---|---|
| WM / compositor | Hyprland | `~/.config/hypr/` | Wayland, Linux-only |
| Bar | Waybar | `~/.config/waybar/` | Neumorphic circular buttons, transparent bar, Linux-only |
| Screen locker | hyprlock | `~/.config/hypr/hyprlock.conf` | Linux-only, Hyprland native |
| Idle daemon | hypridle | `~/.config/hypr/hypridle.conf` | Linux-only, Hyprland native |
| App launcher | rofi | `~/.config/rofi/` | Braun SK 1 light theme, Linux-only |
| Notifications | swaync | `~/.config/swaync/` | nova-dark theme, Linux-only |
| Logout menu | wlogout | `~/.config/wlogout/` | Linux-only |
| Auth agent | polkit-gnome | — | Provides GUI auth dialogs; started via exec-once, Linux-only |
| Wallpaper | awww (formerly swww) | — | Runtime daemon; Braun plastic-grain texture at `~/Pictures/wallpapers/braun-plastic.png` |
| Terminal | Ghostty | `~/.config/ghostty/` | Cross-platform |
| File manager (TUI) | yazi | `~/.config/yazi/` | Cross-platform; only `theme.toml` tracked |
| Editor | Neovim | `~/.config/nvim/` | Cross-platform, Lua-based |
| Editor (IDE) | IdeaVim | `~/.ideavimrc` | Cross-platform, JetBrains plugin |
| Multiplexer | tmux | `~/.config/tmux/tmux.conf` or `~/.tmux.conf` | Cross-platform |
| Shell | zsh | `~/.zshrc`, `~/.zprofile` | Cross-platform, Oh My Zsh |
| Git TUI | lazygit | `~/.config/lazygit/` | YAML config, cross-platform |
| Syntax highlighting | bat | `~/.config/bat/` | Config + tmTheme, cross-platform |
| System info | neofetch | `~/.config/neofetch/` | Shell-like config, cross-platform |
| Git config | git | `~/.config/git/` | Cross-platform |
| Dotfile mgr | chezmoi | `~/.local/share/chezmoi/` | Source of truth |

## System theme

Braun RT20/SK4/ET66 aesthetic - the desktop as a physical device surface. Inspired by Dieter Rams' work at Braun: RT20 radio (cream + wood), SK4 phonosuper, ET66 calculator. Core principle: **state via physical metaphors** (depression, indicator lights, mechanical pointers) rather than color changes.

### Braun RT20/SK4/ET66 palette

| Element | Value |
|---|---|
| Cream base | `#E8E4DC` (primary background) |
| Cream light | `#F2EFE8` (hover/highlight) |
| Cream shadow | `#D9D2C6` (pressed, borders) |
| Warm grey | `#B8B0A4` (disabled) |
| Fabric light | `#C4BDB0` (speaker grille) |
| Fabric mid | `#A89F8F` |
| Fabric dark | `#7A7265` |
| Amber primary | `#D4A04A` (indicator ON) |
| Amber bright | `#E8B04A` |
| Amber dim | `#8B7034` (indicator OFF) |
| Wood light | `#C09C6F` |
| Wood mid | `#A68B5B` (clock bg) |
| Text primary | `#2A2520` |
| Text secondary | `#5F503E` |
| Text muted | `#8A8278` |
| Green | `#5A6B4A` (success) |
| Red | `#AD1D1D` (critical) |
| Terminal bg | `#2A2520` (dark theme) |

Applied to: Hyprland borders, Waybar, rofi, hyprlock, swaync, Ghostty (dark).

### Physical state metaphors

- **Depression**: Buttons look pressed via inset shadows + `translateY(1px)`. Color stays same.
- **Indicator lights**: Small amber glow (via `box-shadow` + `border-left`) shows ON state. OFF = dim amber, ON = bright amber glow.
- **Mechanical pointer**: Active workspace marked by amber `border-bottom`, not color change.

### Wallpaper

Plastic-grain texture: cream `#E8E4DC` base + subtle monochrome noise (8% opacity).
Generated with ImageMagick, stored at `~/Pictures/wallpapers/braun-plastic.png`.

### Waybar module types

| Type | Use | Visual |
|---|---|---|
| Standard | Battery % | Transparent bg, text only |
| Fabric | Workspaces container | Horizontal stripe texture |
| Toggle | Network, BT, audio, notif | Cream button + amber indicator glow |
| Wood | Clock only | Wood gradient (RT20 beech veneer) |
| Launcher | App launcher | Cream + amber border ("equals key") |
| Power | Shutdown | Amber background |

### Window decorations

- `rounding = 8`, `gaps_in = 8`, `gaps_out = 16`
- Active border: amber `#D4A04A`
- Inactive border: cream shadow `#D9D2C6`
- Shadow range: 20

**Design principles:**
- Transparent Waybar with physical button metaphors
- No color change on interaction - use shadow/depression instead
- Amber is sacred: only for indicators, active pointers, launcher border
- Wood = time (clock only)
- Fabric texture = system status containers
- Use gammastep/wlsunset for comfortable night use

## Chezmoi structure

Source state lives in `~/.local/share/chezmoi/`. Key conventions:

- **Templates** (`.tmpl` suffix) — use for any file that differs between Linux and macOS. *Note: No templates are currently in use; this is documented for future reference.*
- **OS branching** — use `{{ if eq .chezmoi.os "linux" }}` / `{{ if eq .chezmoi.os "darwin" }}`.
- **`.chezmoiignore`** — exclude Linux-only configs on macOS and vice versa. Example pattern for future use:
  ```
  {{ if ne .chezmoi.os "linux" }}
  .config/hypr/**
  .config/waybar/**
  .config/rofi/**
  .config/swaync/**
  {{ end }}
  ```
- **Secrets** — never commit plaintext. Use chezmoi's password-manager integration or `age` encryption.
- After any change: `chezmoi diff` → review → `chezmoi apply`.

## Platform rules

| Scope | Linux | macOS | Shared |
|---|---|---|---|
| Hyprland, Waybar, hyprlock, hypridle, rofi, swaync, wlogout, polkit-gnome, awww | ✓ | — | — |
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

# Hyprland (changes auto-reload on save)
# Waybar
pkill waybar; waybar &            # Reload waybar

# swaync
swaync-client --reload-config     # Reload config
swaync-client --reload-css        # Reload styles

# awww
awww-daemon                       # Start daemon (exec-once in hyprland.conf)
awww img <path>                   # Set wallpaper

# hyprlock
hyprlock                          # Lock screen manually

# hypridle (started via exec-once in hyprland.conf)

# rofi
~/.config/rofi/launchers/apps.sh  # Run app launcher
```

## Editing guidelines

When editing configs, you're working with **source files** using chezmoi naming (e.g., `dot_config/waybar/config.jsonc` → `~/.config/waybar/config.jsonc`). After editing, run `chezmoi apply` to sync changes to the home directory.

1. **Hyprland** (`dot_config/hypr/hyprland.conf` and splits) — Hyprland DSL, not JSON/TOML. Changes hot-reload after apply. Always define new keybinds with `$mainMod`. Keep `exec-once` block tidy and grouped.
2. **Waybar** — `config.jsonc` (JSONC) + `style.css`. Use `hyprland/workspaces` and `hyprland/window` modules, NOT `sway/*`. Current aesthetic is Braun Calculator with neumorphic circular buttons floating on transparent bar.
3. **swaync** — `config.json` (JSON) + `style.css` (imports theme). Theme directory: `themes/nova-dark/`. Icons directory: `icons/`. Reload with `swaync-client --reload-config` and `swaync-client --reload-css`.
4. **hyprlock** — Hyprland DSL config at `hyprlock.conf`. Defines lock screen appearance/behavior.
5. **hypridle** — Hyprland DSL config at `hypridle.conf`. Defines idle timeouts: dim (2.5min), lock (5min), DPMS (5.5min), suspend (30min). Also controls keyboard backlight. Started via exec-once in hyprland.conf.
6. **rofi** — rasi config format. Main config: `config.rasi`. Theme: `themes/catppuccin.rasi`. Launcher: `launchers/apps.rasi` + `apps.sh`. Utility scripts: `scripts/wifi.sh`, `scripts/bluetooth.sh`.
7. **wlogout** — `layout` file (custom format) + `style.css`. Defines logout/reboot/shutdown menu.
8. **Neovim** — Lua config under `~/.config/nvim/`. Respect existing plugin manager and structure. Don't switch plugin managers without asking.
9. **tmux** — Single config file. Prefer `~/.config/tmux/tmux.conf` (XDG) if already set up that way.
10. **zsh** — Oh My Zsh framework. Keep `.zshrc` lean. Shared aliases/functions should work on both GNU and BSD coreutils.
11. **yazi** — TOML config. Cross-platform; only `theme.toml` currently tracked. Avoid Linux-only previewer commands without a macOS fallback.
12. **Ghostty** — Plain config file. Cross-platform terminal emulator.
13. **lazygit** — YAML config (`config.yml`). Cross-platform Git TUI.
14. **bat** — Config file + theme. Cross-platform syntax highlighter.
15. **git** — Standard git config format. Cross-platform.
16. **IdeaVim** — Vim-like config at `~/.ideavimrc`. Cross-platform JetBrains Vim emulation.

## Workflow

Since we're working directly in the chezmoi source directory:

- **Edit source files directly** — no need for `chezmoi edit` or `chezmoi cd`
- **Git operations happen here** — commit, push, pull as normal
- **Apply after editing** — run `chezmoi diff` → `chezmoi apply` to sync to `~/`
- **One concern per commit** — prefix with tool name: `waybar: add battery module`, `nvim: configure LSP`
- **Adding new files** — use `chezmoi add ~/.config/foo/bar` to track a file (creates source entry with correct naming)
- **Templates** — if a config must differ per-OS, convert with `chezmoi chattr +template <file>`

## Documentation resources

For up-to-date documentation, use Context7 MCP:

| Tool | Context7 library ID |
|---|---|
| Hyprland | `/websites/wiki_hypr_land` |
| Waybar | `/alexays/waybar` |

Query with `mcp__context7__resolve-library-id` (to find library IDs) and `mcp__context7__query-docs` (to fetch docs).

## What NOT to do

- Don't install packages — suggest the command, let me run it.
- Don't change the shell (it's zsh everywhere).
- Don't restructure the chezmoi source directory layout without asking.
- Don't convert working non-template files to templates unless there's an actual cross-platform difference.
- Don't add compositor/WM keybinds that conflict with existing ones — read `hyprland.conf` first.
