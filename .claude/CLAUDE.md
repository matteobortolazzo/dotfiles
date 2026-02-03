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
| Bar | Waybar | `~/.config/waybar/` | macOS-style layout, JSONC + CSS, Linux-only |
| Screen locker | hyprlock | `~/.config/hypr/hyprlock.conf` | Linux-only, Hyprland native |
| Idle daemon | hypridle | `~/.config/hypr/hypridle.conf` | Linux-only, Hyprland native |
| App launcher | rofi | `~/.config/rofi/` | Braun SK 1 light theme, Linux-only |
| Notifications | swaync | `~/.config/swaync/` | nova-dark theme, Linux-only |
| Logout menu | wlogout | `~/.config/wlogout/` | Linux-only |
| Auth agent | polkit-gnome | — | Provides GUI auth dialogs; started via exec-once, Linux-only |
| Wallpaper | awww (formerly swww) | — | Runtime daemon, no persistent config file |
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

Two complementary Braun-inspired themes:

### Braun SK 1 Light (desktop GUI)

Warm ivory cream with glossy plastic aesthetic, inspired by the 1955 Braun SK 1 radio.

| Element | Value |
|---|---|
| Background | Ivory cream (`#F5F2ED`) |
| Surface | Warm cream (`#EBE7E0`, `#E2DDD5`) |
| Text | Warm charcoal (`#2C2825`) |
| Accent | Honey amber (`#C4853A`) |
| Style | Glossy plastic (subtle highlight gradients, embossed shadows) |

Applied to: Hyprland borders, Waybar, rofi, hyprlock.

### Braun Dark (terminal TUI)

Dark complement to Braun SK 1 Light for terminal applications.

| Element | Value |
|---|---|
| Background | Dark charcoal (`#1E1B18`) |
| Surface | Warm dark (`#2C2825`, `#3D3835`) |
| Foreground | Warm cream (`#E8E4DD`) |
| Muted | `#A39E96`, `#6B6560` |
| Accent | Honey amber (`#C4853A`) |
| Accent bright | `#D9A05A` |
| Teal | `#6B9A9A` (directories, links) |
| Mauve | `#A67B9D` (keywords, special) |
| Green | `#7D9B73` (success, strings) |
| Red | `#C75D5D` (error, deletion) |

Applied to: Ghostty, yazi, bat, lazygit.

**Design principle:** No pure blue. Use teal (`#6B9A9A`) for traditional blue roles (directories, links).

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
2. **Waybar** — `config.jsonc` (JSONC) + `style.css`. Use `hyprland/workspaces` and `hyprland/window` modules, NOT `sway/*`. Current aesthetic is macOS-like — preserve that intent unless told otherwise.
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
