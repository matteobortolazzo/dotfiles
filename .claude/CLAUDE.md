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
| Shell (bar/launcher/notif/lock/idle/session/wallpaper/OSD) | noctalia-shell | `~/.config/noctalia/` | Quickshell-based single daemon; configured via in-app GUI; IPC via `qs -c noctalia-shell ipc call ...` |
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

Applied to: Hyprland, noctalia-shell (custom user color scheme: "Glassmorphic Dark"), Ghostty, yazi, Neovim (catppuccin macchiato).

### Wallpaper

Stored at `~/Pictures/Wallpapers/wp6990351.jpg`. Set via noctalia Settings → Wallpaper.

### Blur configuration

| Component | Blur | Notes |
|---|---|---|
| Hyprland | size=6, passes=3 | Window blur |
| Ghostty | opacity=0.88 | Terminal transparency |
| noctalia-shell | layerrule blur on `noctalia-background-.*` | Bar/panel/launcher blur-through |

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
- **`.chezmoiignore`** — gates Linux-only config paths behind `{{ if ne .profile "main" }}` (`.config/hypr`, `.config/noctalia`, `.config/ghostty`).
- **Secrets** — never commit plaintext. Use chezmoi's password-manager integration or `age` encryption.
- After any change: `chezmoi diff` → review → `chezmoi apply`.

## Platform rules

| Scope | Linux | macOS | Shared |
|---|---|---|---|
| Hyprland, noctalia-shell, polkit-gnome | ✓ | — | — |
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

# noctalia-shell (single daemon; restart by killing + relaunching)
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

1. **Hyprland** (`dot_config/hypr/hyprland.conf` and splits) — Hyprland DSL, not JSON/TOML. Changes hot-reload after apply. Always define new keybinds with `$mainMod`. Wire shell features through the `$ipc` variable (`$ipc = qs -c noctalia-shell ipc call`). Keep `exec-once` block tidy and grouped.
2. **noctalia-shell** — Configured via the in-app Settings GUI (open with SUPER+R). User color schemes live in `~/.config/noctalia/color-schemes/`. Don't hand-edit JSON unless reproducing it on a new machine — let the GUI write it, then `chezmoi add ~/.config/noctalia` to capture. Docs: <https://docs.noctalia.dev/v4/>. Full IPC reference: <https://docs.noctalia.dev/v4/getting-started/keybinds/>.
3. **Neovim** — Lua config under `~/.config/nvim/`. Respect existing plugin manager and structure. Don't switch plugin managers without asking.
4. **tmux** — Single config file. Prefer `~/.config/tmux/tmux.conf` (XDG) if already set up that way.
5. **zsh** — Oh My Zsh framework. Keep `.zshrc` lean. Shared aliases/functions should work on both GNU and BSD coreutils.
6. **yazi** — TOML config. Cross-platform; only `theme.toml` currently tracked. Avoid Linux-only previewer commands without a macOS fallback.
7. **Ghostty** — Plain config file. Cross-platform terminal emulator.
8. **lazygit** — YAML config (`config.yml`). Cross-platform Git TUI.
9. **bat** — Config file + theme. Cross-platform syntax highlighter.
10. **git** — Standard git config format. Cross-platform.
11. **IdeaVim** — Vim-like config at `~/.ideavimrc`. Cross-platform JetBrains Vim emulation.

## Workflow

Since we're working directly in the chezmoi source directory:

- **Edit source files directly** — no need for `chezmoi edit` or `chezmoi cd`
- **Git operations happen here** — commit, push, pull as normal
- **Apply after editing** — run `chezmoi diff` → `chezmoi apply` to sync to `~/`
- **One concern per commit** — prefix with tool name: `noctalia: tweak control center`, `nvim: configure LSP`
- **Adding new files** — use `chezmoi add ~/.config/foo/bar` to track a file (creates source entry with correct naming)
- **Templates** — if a config must differ per-OS, convert with `chezmoi chattr +template <file>`

## Documentation resources

For up-to-date documentation, use Context7 MCP:

| Tool | Context7 library ID |
|---|---|
| Hyprland | `/websites/wiki_hypr_land` |

For noctalia-shell, fetch the docs site directly (no Context7): <https://docs.noctalia.dev/v4/>.

Query with `mcp__context7__resolve-library-id` (to find library IDs) and `mcp__context7__query-docs` (to fetch docs).

## What NOT to do

- Don't install packages — suggest the command, let me run it.
- Don't change the shell (it's zsh everywhere).
- Don't restructure the chezmoi source directory layout without asking.
- Don't convert working non-template files to templates unless there's an actual cross-platform difference.
- Don't add compositor/WM keybinds that conflict with existing ones — read `hyprland.conf` first.
