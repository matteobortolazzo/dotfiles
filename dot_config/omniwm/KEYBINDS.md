# OmniWM shortcuts on macOS

`Mod` from the niri setup is **Command** here. Option remains niri's `Alt`.
skhd maps Command+Q to OmniWM's close focused window command. These global shortcuts
replace standard macOS app shortcuts while OmniWM is running.

| Keys | Action |
|---|---|
| Command+H / J / K / L | Focus left / down / up / right |
| Command+Shift+H / L | Move column left / right |
| Command+Shift+J / K | Move window down / up in a column |
| Command+[ / ] | Previous / next workspace |
| Command+Shift+[ / ] | Move window to workspace up / down |
| Command+1…9 | Switch to workspace 1…9 |
| Command+Shift+1…9 | Move window to workspace 1…9 |
| Command+Q | Close focused window, keeping the app running |
| Command+V | Toggle focused window floating |
| Command+F | Toggle full column width |
| Command+Z | Toggle OmniWM fullscreen without a macOS Space |
| Command+G | Toggle tabbed column |
| Command+P | Expel window from its column |
| Command+S | Overview |
| Command+D | Command palette |
| Command+Shift+F | Center visible columns |
| Control+Command+H / L | Shrink / grow column width |
| Control+Command+J / K | Shrink / grow window height |
| Control+Command+0 | Reset window height |
| Control+Command+, / . | Cycle column width presets |
| Control+Command+Shift+, / . | Move column to workspace up / down |
| Command+Option+, / . | Focus previous / next monitor |
| Command+Option+Shift+, / . | Move window to previous / next monitor |
| Command+T | New Ghostty window, while Ghostty is running and has Accessibility permission |
| Command+B | Focus or launch Zen Browser (skhd) |

OmniWM's default layout is niri-style scrolling columns. Its workspace layout
can be changed to Hyprland-style dwindle in Settings. Keep one native macOS Space
per display and use OmniWM workspaces for tiling.

Some niri bindings do not have direct OmniWM equivalents: launching the file
manager, shell panels and screenshots, and the separate consume-left/right
shortcuts. OmniWM's Option+Shift+Arrow keys can consume or expel windows.
