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
| `dot_ideavimrc` | `~/.ideavimrc` |
| `private_` prefix | File with restricted permissions |
| `executable_` prefix | File with +x permission |
| `exact_` prefix | Directory managed exactly (extra files removed) |
| `.tmpl` suffix | Template processed by chezmoi |

## Stack

| Layer | Tool | Config path | Notes |
|---|---|---|---|
| WM / compositor | Hyprland | `~/.config/hypr/` | Wayland, Linux-only |
| Bar | Waybar | `~/.config/waybar/` | Minimal transparent, dark icons for light wallpapers, Linux-only |
| Screen locker | hyprlock | `~/.config/hypr/hyprlock.conf` | Linux-only, Hyprland native |
| Idle daemon | hypridle | `~/.config/hypr/hypridle.conf` | Linux-only, Hyprland native |
| App launcher | rofi | `~/.config/rofi/` | Glassmorphic dark theme, Linux-only |
| Notifications | swaync | `~/.config/swaync/` | nova-dark theme, Linux-only |
| Logout menu | wlogout | `~/.config/wlogout/` | Linux-only |
| Auth agent | polkit-gnome | — | Provides GUI auth dialogs; started via exec-once, Linux-only |
| Wallpaper | hyprpaper | `~/.config/hypr/hyprpaper.conf` | Hyprland native wallpaper daemon, Linux-only |
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
| `bg-glass` | `rgba(20,20,24,0.55)` | Waybar, rofi, swaync |
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

Applied to: Hyprland, rofi, hyprlock, swaync, wlogout, Ghostty, yazi, Neovim (catppuccin macchiato).

### Waybar - Minimal Transparent Theme

Waybar uses a separate minimal theme optimized for light wallpapers:

| Token | Value | Usage |
|---|---|---|
| `icon` | `#3c3c40` | Default icon color |
| `icon-muted` | `#5a5a5e` | Inactive/disabled states |
| `icon-active` | `#1a1a1e` | Active/hovered elements |
| `warning` | `#8a6420` | Low battery warning |
| `critical` | `#8a3030` | Critical battery |
| `success` | `#3a6a4a` | Charging indicator |

Design: Fully transparent bar with no backgrounds or borders. Dark icons float directly over the wallpaper.

### Wallpaper

Stored at `~/Pictures/Wallpapers/wp6990351.jpg`. Set via hyprpaper config.

### Blur configuration

| Component | Blur | Notes |
|---|---|---|
| Hyprland | size=6, passes=3 | Window blur |
| Ghostty | opacity=0.88 | Terminal transparency |
| Waybar | — | Fully transparent, no blur |
| rofi/swaync | layerrule blur | Menu blur-through |

### Window decorations

- `rounding = 12`, `gaps_in = 8`, `gaps_out = 16`
- Active border: `rgba(255,255,255,0.15)`
- Inactive border: `rgba(255,255,255,0.08)`
- Shadow color: `rgba(0,0,0,0.40)`

**Design principles:**
- Dark base with translucent surfaces
- Gold accent (`#c8a67e`) for active/focused states
- Subtle white borders for depth
- Blur-through for glass effect
- Consistent rgba backgrounds across components

## Chezmoi structure

Source state lives in `~/.local/share/chezmoi/`. Key conventions:

- **Templates** (`.tmpl` suffix) — use for any file that differs between Linux and macOS. *Note: No templates are currently in use; this is documented for future reference.*
- **OS branching** — use `{{ if eq .chezmoi.os "linux" }}` / `{{ if eq .chezmoi.os "darwin" }}`.
- **`.chezmoiignore`** — exclude Linux-only configs on macOS and vice versa. *Note: No `.chezmoiignore` currently exists; example pattern for future use:*
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
| Hyprland, Waybar, hyprlock, hypridle, hyprpaper, rofi, swaync, wlogout, polkit-gnome | ✓ | — | — |
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

# hyprpaper (started via exec-once in hyprland.conf)
# Config: ~/.config/hypr/hyprpaper.conf

# hyprlock
hyprlock                          # Lock screen manually

# hypridle (started via exec-once in hyprland.conf)

# rofi
~/.config/rofi/launchers/apps.sh  # Run app launcher

# direnv
direnv allow                      # Trust .envrc in current directory
direnv edit .                     # Create/edit .envrc and auto-allow
```

## Editing guidelines

When editing configs, you're working with **source files** using chezmoi naming (e.g., `dot_config/waybar/config.jsonc` → `~/.config/waybar/config.jsonc`). After editing, run `chezmoi apply` to sync changes to the home directory.

1. **Hyprland** (`dot_config/hypr/hyprland.conf` and splits) — Hyprland DSL, not JSON/TOML. Changes hot-reload after apply. Always define new keybinds with `$mainMod`. Keep `exec-once` block tidy and grouped.
2. **Waybar** — `config.jsonc` (JSONC) + `style.css`. Use `hyprland/workspaces` and `hyprland/window` modules, NOT `sway/*`. Current aesthetic is minimal transparent with dark icons (macOS-style, no backgrounds/borders).
3. **swaync** — `config.json` (JSON) + `style.css` (imports theme). Theme directory: `themes/nova-dark/`. Icons directory: `icons/`. Reload with `swaync-client --reload-config` and `swaync-client --reload-css`.
4. **hyprlock** — Hyprland DSL config at `hyprlock.conf`. Defines lock screen appearance/behavior.
5. **hypridle** — Hyprland DSL config at `hypridle.conf`. Defines idle timeouts: dim (2.5min), lock (5min), DPMS (5.5min), suspend (30min). Also controls keyboard backlight. Started via exec-once in hyprland.conf.
6. **rofi** — rasi config format. Main config: `config.rasi`. Theme: `themes/glass.rasi` (glassmorphic dark). Launcher: `launchers/apps.rasi` + `apps.sh`. Utility scripts: `scripts/wifi.sh`, `scripts/bluetooth.sh`.
7. **wlogout** — `layout` file (custom format) + `style.css` (imports `nova.css` theme). Defines logout/reboot/shutdown menu.
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

## Per-project environment overrides (direnv)

Global secrets are set in `~/.config/environment` (from `environment.tmpl`). For per-project overrides (e.g., different ADO org), create an `.envrc` in the project root:

```bash
# .envrc — copy to project root, edit, then `direnv allow`
export ADO_ORG="my-org"
export AZURE_DEVOPS_EXT_PAT="$(op read 'op://Private/ADO PAT - my-org/credential')"
export ADO_MCP_AUTH_TOKEN="$AZURE_DEVOPS_EXT_PAT"
```

`.envrc` files are globally gitignored (`~/.config/git/ignore`) to prevent accidental secret commits.

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
