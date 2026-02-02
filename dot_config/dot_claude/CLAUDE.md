# Dotfiles — Arch Linux / macOS (chezmoi)

Cross-platform dotfiles managed with chezmoi. Primary target is an Arch Linux laptop running Hyprland (Wayland). Terminal-only configs (zsh, tmux, neovim, yazi, ghostty, lazygit, bat) are shared with macOS.

## Stack

| Layer | Tool | Config path | Notes |
|---|---|---|---|
| WM / compositor | Hyprland | `~/.config/hypr/` | Wayland, Linux-only |
| Bar | Waybar | `~/.config/waybar/` | macOS-style layout, JSONC + CSS, Linux-only |
| Notifications | swaync | `~/.config/swaync/` | Planned, not yet configured; Linux-only |
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

## Chezmoi structure

Source state lives in `~/.local/share/chezmoi/`. Key conventions:

- **Templates** (`.tmpl` suffix) — use for any file that differs between Linux and macOS. *Note: No templates are currently in use; this is documented for future reference.*
- **OS branching** — use `{{ if eq .chezmoi.os "linux" }}` / `{{ if eq .chezmoi.os "darwin" }}`.
- **`.chezmoiignore`** — exclude Linux-only configs on macOS and vice versa. Example pattern for future use:
  ```
  {{ if ne .chezmoi.os "linux" }}
  .config/hypr/**
  .config/waybar/**
  .config/swaync/**
  {{ end }}
  ```
- **Secrets** — never commit plaintext. Use chezmoi's password-manager integration or `age` encryption.
- After any change: `chezmoi diff` → review → `chezmoi apply -v`.
- Commit and push from the source directory (`chezmoi cd`).

## Platform rules

| Scope | Linux | macOS | Shared |
|---|---|---|---|
| Hyprland, Waybar, swaync (planned), awww | ✓ | — | — |
| Neovim, tmux, zsh, yazi, Ghostty, lazygit, bat, neofetch, git, IdeaVim | ✓ | ✓ | ✓ |
| Package manager | pacman / yay (AUR) | brew | — |

When editing a **shared** config, always test or reason about both platforms. Use chezmoi templates or runtime `if` guards when a value must differ (paths, clipboard commands, etc.).

## Key commands

```bash
# Chezmoi
chezmoi diff                      # Preview pending changes
chezmoi apply -v                  # Apply to home directory
chezmoi add ~/.config/foo/bar     # Track a new file
chezmoi add --template ~/.config/foo/baz  # Track as template
chezmoi edit ~/.config/foo/bar    # Edit source state copy
chezmoi cd                        # cd into source directory (for git ops)
chezmoi update                    # Pull remote + apply

# Hyprland (changes auto-reload on save)
# Waybar
pkill waybar; waybar &            # Reload waybar

# swaync (for when configured)
swaync-client --reload-config     # Reload config
swaync-client --reload-css        # Reload styles

# awww
awww-daemon                       # Start daemon (exec-once in hyprland.conf)
awww img <path>                   # Set wallpaper
```

## Editing guidelines

1. **Hyprland** (`hyprland.conf` and splits) — Hyprland DSL, not JSON/TOML. Changes hot-reload. Always define new keybinds with `$mainMod`. Keep `exec-once` block tidy and grouped.
2. **Waybar** — `config.jsonc` (JSONC) + `style.css`. Use `hyprland/workspaces` and `hyprland/window` modules, NOT `sway/*`. Current aesthetic is macOS-like — preserve that intent unless told otherwise.
3. **swaync** — Not yet configured. When set up: `config.json` (JSON) + `style.css`. Reload with `swaync-client --reload-config`.
4. **Neovim** — Lua config under `~/.config/nvim/`. Respect existing plugin manager and structure. Don't switch plugin managers without asking.
5. **tmux** — Single config file. Prefer `~/.config/tmux/tmux.conf` (XDG) if already set up that way.
6. **zsh** — Oh My Zsh framework. Keep `.zshrc` lean. Shared aliases/functions should work on both GNU and BSD coreutils.
7. **yazi** — TOML config. Cross-platform; only `theme.toml` currently tracked. Avoid Linux-only previewer commands without a macOS fallback.
8. **Ghostty** — Plain config file. Cross-platform terminal emulator.
9. **lazygit** — YAML config (`config.yml`). Cross-platform Git TUI.
10. **bat** — Config file + theme. Cross-platform syntax highlighter.
11. **git** — Standard git config format. Cross-platform.
12. **IdeaVim** — Vim-like config at `~/.ideavimrc`. Cross-platform JetBrains Vim emulation.

## Workflow

- One concern per commit. Prefix commits with the tool name: `waybar: add battery module`, `nvim: configure LSP`.
- Always `chezmoi diff` before `chezmoi apply`.
- When creating new config files, `chezmoi add` them — don't hand-create entries in the source directory.
- If a config must differ per-OS, convert to a `.tmpl` file with `chezmoi chattr +template <file>`.

## What NOT to do

- Don't install packages — suggest the command, let me run it.
- Don't change the shell (it's zsh everywhere).
- Don't restructure the chezmoi source directory layout without asking.
- Don't convert working non-template files to templates unless there's an actual cross-platform difference.
- Don't add compositor/WM keybinds that conflict with existing ones — read `hyprland.conf` first.
