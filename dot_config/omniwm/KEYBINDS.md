# OmniWM shortcuts on macOS

`Mod` from the niri setup is **Caps Lock** here. OmniWM remaps it to a Hyper key
that sends Control+Option+Command (`systemHyperTrigger = "CapsLock"`,
`hyperKeyModifiers` in `settings.toml`). Command is left alone so native app
shortcuts (copy/paste, undo, save, find, tabs…) keep working.

Hyper deliberately excludes Shift, so Caps+Shift is a separate layer (niri's
`Mod+Shift`). Control and Option are already part of Hyper, so niri's
`Mod+Ctrl` and `Mod+Alt` binds move to other keys: resize follows niri's
default Minus/Equal layout, and monitors sit on Comma/Period.

| Keys | Action |
|---|---|
| Caps+H / J / K / L | Focus left / down / up / right |
| Caps+Shift+H / L | Move column left / right |
| Caps+Shift+J / K | Move window down / up in a column |
| Caps+, / . | Consume into / expel from the neighbouring column (skhd → `omniwmctl`) |
| Caps+[ / ] | Previous / next workspace |
| Caps+Shift+[ / ] | Move window to workspace up / down |
| Caps+Shift+I / U | Move column to workspace up / down (niri `Mod+Ctrl+Shift+, / .`) |
| Caps+1…9 | Switch to workspace 1…9 |
| Caps+Shift+1…9 | Move window to workspace 1…9 |
| Caps+Q | Close focused window, keeping the app running |
| Caps+V | Toggle focused window floating |
| Caps+F | Toggle full column width |
| Caps+M | Expand column to the available width |
| Caps+Shift+F | Center visible columns |
| Caps+Z | Toggle OmniWM fullscreen without a macOS Space |
| Caps+G | Toggle tabbed column |
| Caps+P | Expel window from its column |
| Caps+S | Overview |
| Caps+D | Command palette |
| Caps+- / = | Shrink / grow column width (niri `Mod+Ctrl+H / L`) |
| Caps+Shift+- / = | Shrink / grow window height (niri `Mod+Ctrl+J / K`) |
| Caps+0 | Reset window height (niri `Mod+Ctrl+0`) |
| Caps+R / Caps+Shift+R | Cycle column width presets forward / back (niri `Mod+Ctrl+. / ,`) |
| Caps+← / → | Focus previous / next monitor (niri `Mod+Alt+, / .`) |
| Caps+Shift+← / → | Move window to previous / next monitor (niri `Mod+Alt+Shift+, / .`) |
| Caps+` | Focus last monitor |
| Caps+T | New Ghostty window, while Ghostty is running and has Accessibility permission |
| Caps+B | Focus or launch Zen Browser (skhd) |
| Caps+E | Finder (skhd) |
| Caps+Escape | Lock screen (skhd) |
| Option+` | Quake terminal (OmniWM extra, no niri equivalent) |

Everything else OmniWM ships bound by default (Option+Tab, Option+Shift+Arrows,
Control+Option+1…9, …) is unassigned so it cannot shadow app shortcuts.

OmniWM's default layout is niri-style scrolling columns. Its workspace layout
can be changed to Hyprland-style dwindle in Settings. Keep one native macOS Space
per display and use OmniWM workspaces for tiling.

Some niri bindings have no macOS equivalent and stay unmapped: the DMS panels
(`Mod+A/W/R`, `Mod+Shift+N/D`) and the screenshot keys.
