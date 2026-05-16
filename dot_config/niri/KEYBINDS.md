# niri keybindings

`Mod` = Super (Windows key). In-session, `Mod+/` opens niri's live
hotkey overlay — that's always authoritative if this file gets stale.
Generated from `dot_config/niri/config.kdl`.

## Mental model in one minute

- A **workspace** is an **infinite horizontal strip of columns**.
- Workspaces themselves stack **vertically** — one above the other.
- A **column** holds **one window** by default; you can stack multiple
  windows inside one column.
- A stacked column can be rendered as **tabs** instead of a vertical pile.

| Axis | Verb | Default key |
|---|---|---|
| Between columns (left ↔ right) | `focus-column-left/right` | `Mod+H` / `Mod+L` |
| Between workspaces (up ↕ down) | `focus-workspace-up/down` | `Mod+[` / `Mod+]` |
| Inside a stacked column (or between tabs) | `focus-window-up/down` | `Mod+K` / `Mod+J` |

## How to scroll

| To scroll… | Key | Mouse |
|---|---|---|
| Left/right across columns | `Mod+H` / `Mod+L` | `Mod+Wheel ← / →` |
| Up/down across workspaces | `Mod+[` / `Mod+]` | `Mod+Wheel ↑ / ↓` |
| Inside a stacked column / between tabs | `Mod+K` / `Mod+J` | (no default) |

## Apps & launch

| Keys | Action |
|---|---|
| `Mod+T` | Ghostty terminal |
| `Mod+B` | Zen browser (focus if open, else launch) |
| `Mod+E` | Thunar (file manager) |
| `Mod+D` | DMS spotlight (app launcher) |
| `Mod+Print` | Screenshot region → clipboard |

## Window / column

| Keys | Action |
|---|---|
| `Mod+Q` | Close window |
| `Mod+V` | Toggle floating |
| `Mod+M` / `Mod+F` | Maximize column |
| `Mod+Z` | Fullscreen window |
| `Mod+P` | Expel window from column (pop out of stack) |
| `Mod+,` / `Mod+.` | Consume / expel left or right — build / tear a stack |
| `Mod+G` | Toggle tabbed display (stacked column ↔ i3-style tabs) |
| `Mod+Shift+F` | Center visible columns |
| `Mod+Ctrl+H` / `Mod+Ctrl+L` | Shrink / grow column 10% |
| `Mod+Ctrl+,` / `Mod+Ctrl+.` | Cycle preset width back / forward |

## Focus (vim keys)

| Keys | Action |
|---|---|
| `Mod+H` / `Mod+L` | Focus column left / right |
| `Mod+J` / `Mod+K` | Focus window down / up (inside a stacked or tabbed column) |
| `Mod+Wheel ←/→` | Focus column left / right |

## Move within scrolling layout

| Keys | Action |
|---|---|
| `Mod+Shift+H` / `Mod+Shift+L` | Move column left / right |
| `Mod+Shift+J` / `Mod+Shift+K` | Move window down / up in stack |
| `Mod+Shift+,` / `Mod+Shift+.` | Move column left / right (alias of `Shift+H/L`) |

## Workspaces (vertical — workspaces stack top-to-bottom)

| Keys | Action |
|---|---|
| `Mod+[` / `Mod+]` | Focus workspace up / down |
| `Mod+Shift+[` / `Mod+Shift+]` | Move window to workspace up / down |
| `Mod+Ctrl+Shift+,` / `Mod+Ctrl+Shift+.` | Move whole column to workspace up / down |
| `Mod+Wheel ↑ / ↓` | Focus workspace up / down |
| `Mod+1` … `Mod+9` | Jump to workspace N |
| `Mod+Shift+1` … `Mod+Shift+9` | Send window to workspace N |
| `Mod+S` | Overview (see all workspaces) |

## Monitors

| Keys | Action |
|---|---|
| `Mod+Alt+,` / `Mod+Alt+.` | Focus monitor left / right |
| `Mod+Alt+Shift+,` / `Mod+Alt+Shift+.` | Move window to monitor left / right |

## Shell (DankMaterialShell)

| Keys | Action |
|---|---|
| `Mod+A` | Control center |
| `Mod+R` | DMS settings |
| `Mod+W` | Next wallpaper |
| `Mod+Shift+N` | Toggle notifications panel |
| `Mod+Shift+D` | Toggle Do-Not-Disturb |
| `Mod+Escape` | Lock |
| `Ctrl+Alt+Del` | Power menu |
| `Mod+/` | Hotkey overlay (live cheat sheet) |

## Hardware keys

Volume, mic-mute, brightness (screen + keyboard), play / pause / next /
prev, display off, RF-kill, sleep — wired to the standard `XF86…`
keys. See `binds {}` in `config.kdl` for the exact action mapping.

## Recipes

### Build a tabbed group from two windows

1. Open two ghostty windows: `Mod+T`, `Mod+T` → two columns side by side.
2. Focus the left one (`Mod+H`).
3. `Mod+.` → pulls the right window into the same column as a stack.
4. `Mod+G` → renders the stack as tabs. A thin gold bar on the left of
   the column marks the active tab; faded white bars mark the others.
5. `Mod+J` / `Mod+K` → switch tabs.
6. `Mod+G` again → back to vertical stack.
7. `Mod+P` (or `Mod+.` again) → expel the focused tab back into its own
   column.
