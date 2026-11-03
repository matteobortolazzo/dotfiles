# Configuration review — 2026-11-03

The supported Linux installation path is CachyOS with no desktop selected,
followed by `chezmoi init --apply` with profile `main`. The dotfiles install Niri,
Dux Shell, audio, portals and greetd. macOS uses the `mac` profile; the existing
Arch WSL profile remains compatible.

## Corrections

- Bare TTY boot: enable `graphical.target` as well as greetd; do not start the
  display manager during the installation session. Pin WirePlumber as the
  PipeWire session manager and include ALSA and XDG directory support.
- TUXEDO: opt-in hardware flag, current drivers and Control Center, headers for
  every installed kernel, `tccd` and its sleep service, and one power manager.
- Dux Shell 2: seed `~/.config/dms`; copy legacy config/state/data before seeding
  without overwriting migrated settings or deleting the originals. The executable
  and systemd service remain `dms`.
  A legacy config directory is archived before the compatibility symlink replaces it.
- macOS: resolve both Homebrew prefixes, propagate PATH between bootstrap
  scripts, install the desktop 1Password app, Zen, Toolbox, ImageMagick, Python,
  tree-sitter-cli, Prettier and StyLua. Share Ghostty's theme with the Mac.
- Neovim: update the plugin lockfile after isolated verification, configure LSP
  capabilities before Mason enables servers, add Go LSP/parsers and TSX, enable
  Treesitter for `sh` and React filetypes, and avoid image output on a Linux TTY.
- Shell/tmux: restore Cargo's PATH and use the same TPM directory in the installer
  and tmux config.
- Environment: shell-quote 1Password values so punctuation is preserved when zsh
  sources the generated file.
- Niri: use its built-in Xwayland Satellite integration once; do not force an
  NVIDIA VA-API/GLX driver on Intel/AMD or hybrid laptops.
- Services: check actual unit existence instead of treating a successful empty
  `systemctl list-unit-files` result as an installed service.
- AUR: attempt all packages, report failures, and return failure so chezmoi
  retries on the next apply. Do not suggest bypassing source checksums.
- Shared tools: remove the `dev` flag and its manifest; move PostgreSQL and DNS
  clients to the Linux terminal baseline, and add Homebrew `libpq` to Mac PATH.
  OpenCode was already shared. No PostgreSQL server is enabled.
- SSH: enable sshd and the scoped ufw rules on all native Linux PCs; enable and
  verify macOS Remote Login. Gaming/hardware flags remain Linux `main` only.
- 1Password: probe the same sign-in handshake used by chezmoi before rendering
  secrets, preserving the existing environment when the desktop app is unavailable.

## Verification and limits

`python3 tests/check_config.py` renders every installer for the normal desktop,
TUXEDO laptop, gaming/headless/UPS/Stream Deck host, macOS and legacy WSL.
It checks shell syntax, JSON/TOML parsing, Niri syntax when installed, and runs the
Dux migration twice against temporary directories to check preservation.
It also verifies migration away from `dev` and isolates native Linux roles from WSL.
`python3 tests/test_ssh.py` checks the Mac Remote Login flow with a fake system
command, including permission failures that return success without enabling SSH.
`python3 tests/test_onepassword.py` exercises real chezmoi applies in temporary
homes with a fake CLI, checking secret preservation and successful rendering.

Neovim is exercised separately with isolated XDG config/data/cache/state paths
under `/tmp`; `tests/nvim-smoke.lua` checks LSP capabilities, formatter wiring,
Telescope and highlighting for shell, Lua, Go, gomod, JSX, TSX and Markdown.
This is configuration verification, not an assertion that every language server
has installed successfully on every host.

No system package upgrade, bootloader change or live desktop restart is part of
this review. Physical TUXEDO fan/suspend/backlight behaviour and Mac Accessibility
permissions require checks on those machines. Also check Bluetooth/audio,
screensharing and monitor arrangements after the first reboot. Existing monitor
positions are hardware-specific; DMS owns `niri/dms/outputs.kdl` after seeding.

On an existing machine, run `chezmoi init` for the new TUXEDO answer and Mac
script PATH, then review `chezmoi diff`, apply and reboot Linux. A changed
`run_once` script runs once for its new content; it does not continuously update
tools it bootstrapped. Keep rolling package updates and language-toolchain
updates separate from applying dotfiles.

The local pacman database resolved the terminal, desktop and system manifests.
The AUR RPC confirmed the two TUXEDO packages; a later full AUR manifest lookup
failed DNS resolution even outside the sandbox, so availability of every other
AUR package was not reverified. No AUR build was attempted during this review.

## Upstream references

- [CachyOS installation](https://wiki.cachyos.org/installation/installation_on_root/).
- [TUXEDO Control Center and driver requirement](https://github.com/tuxedocomputers/tuxedo-control-center),
  [AUR driver](https://aur.archlinux.org/packages/tuxedo-drivers-dkms),
  [AUR Control Center](https://aur.archlinux.org/packages/tuxedo-control-center-bin).
- [Dux 2.0 XDG paths](https://github.com/duxlabs-dev/dux-shell/blob/v2.0.0/quickshell/Common/Paths.qml)
  and [process management](https://duxlabs.dev/docs/dms/cli-process-management).
- [Treesitter requirements and activation](https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md)
  and [Mason LSP setup ordering](https://github.com/mason-org/mason-lspconfig.nvim).
- [Homebrew tree-sitter-cli](https://formulae.brew.sh/formula/tree-sitter-cli),
  [ImageMagick](https://formulae.brew.sh/formula/imagemagick),
  [libpq](https://formulae.brew.sh/formula/libpq),
  [OmniWM setup](https://omniwm.app/guides/install/),
  [skhd service](https://github.com/asmvik/skhd).
- [macOS Remote Login](https://support.apple.com/guide/mac-help/mchlp1066/mac)
  and [systemsetup](https://support.apple.com/guide/remote-desktop/apd95406b8d/mac).
- [Arch bind package](https://archlinux.org/packages/extra/x86_64/bind/), which
  provides the former `bind-tools` package name.
- [Ghostty configuration precedence](https://ghostty.org/docs/config) and
  [chezmoi script lifecycle](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/).
