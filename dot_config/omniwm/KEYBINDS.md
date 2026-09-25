# OmniWM shortcuts on macOS

`Mod` from the niri setup is **Option** here. macOS reserves Command+Q for
quitting an entire app, so Option+Q closes only OmniWM's focused window.

| Keys | Action |
|---|---|
| Option+H / J / K / L | Focus left / down / up / right |
| Option+Shift+H / L | Move column left / right |
| Option+Shift+J / K | Move window down / up in a column |
| Option+[ / ] | Previous / next workspace |
| Option+Shift+[ / ] | Move window to workspace up / down |
| Option+1…9 | Switch to workspace 1…9 |
| Option+Shift+1…9 | Move window to workspace 1…9 |
| Option+Q | Close focused window, keeping the app running |
| Option+V | Toggle focused window floating |
| Option+F | Toggle full column width |
| Option+Z | Toggle OmniWM fullscreen without a macOS Space |
| Option+G | Toggle tabbed column |
| Option+P | Expel window from its column |
| Option+S | Overview |
| Option+D | Command palette |
| Option+Shift+F | Center visible columns |
| Control+Option+H / L | Shrink / grow column width |
| Control+Option+J / K | Shrink / grow window height |
| Control+Option+0 | Reset window height |
| Control+Option+, / . | Cycle column width presets |
| Control+Option+Shift+, / . | Move column to workspace up / down |
| Command+Option+, / . | Focus previous / next monitor |
| Command+Option+Shift+, / . | Move window to previous / next monitor |
| Option+T | New Ghostty window, while Ghostty is running and has Accessibility permission |
| Option+B | Focus or launch Zen Browser (skhd) |
| Command+T (in Ghostty) | New Ghostty window instead of a tab |

OmniWM's default layout is niri-style scrolling columns. Its workspace layout
can be changed to Hyprland-style dwindle in Settings. Keep one native macOS Space
per display and use OmniWM workspaces for tiling.

Some niri bindings do not have direct OmniWM equivalents: launching the file
manager, shell panels and screenshots, and the separate consume-left/right
shortcuts. OmniWM's Option+Shift+Arrow keys can consume or expel windows.
