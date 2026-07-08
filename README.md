# Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/). Primary target is Arch Linux running [niri](https://github.com/YaLTeR/niri) (scrollable-tiling Wayland compositor) with [DankMaterialShell](https://danklinux.com/) as the desktop shell, behind a greetd/regreet login. Terminal configs (zsh, tmux, neovim, yazi, ghostty, lazygit, bat) are shared with macOS and WSL.

## Profiles

`chezmoi init` prompts once for a machine profile:

| Profile | What you get |
|---|---|
| `main` | Full Arch desktop: niri + DMS, greetd, GUI apps, system services |
| `wsl` | Terminal stack + docker, WSL host tuning, Windows SSH-agent bridge |
| `mac` | Terminal stack via Homebrew/Brewfile |

## Quick start (empty machine)

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply matteobortolazzo
```

That single command installs chezmoi, clones this repo, prompts for the profile, and applies. On Arch it installs all packages (pacman + AUR via yay), enables system services (NetworkManager, bluetooth, greetd, …), wires DMS to autostart with niri, and bootstraps the toolchain (oh-my-zsh, rustup, dotnet, fnm/node, tpm). **Reboot when it finishes** — greetd is enabled but deliberately not started mid-apply.

Secrets are skipped on the first pass if the 1Password CLI isn't signed in yet (see below) — everything else completes.

### 1Password (secrets + SSH agent)

Secrets in `~/.config/environment` and the SSH agent come from 1Password. Until `op` is installed *and* signed in, `chezmoi apply` simply skips them; re-run apply afterwards to fill them in.

```bash
# Arch (installed automatically by the package lists)  /  macOS: via Brewfile
op signin
```

Enable the SSH agent in the 1Password desktop app: **Settings → Developer → SSH Agent**.

On **WSL**, 1Password runs on the Windows side: enable its SSH agent on Windows, and the dotfiles bridge to it automatically via `wsl2-ssh-agent` (installed by `run_once_after_60-wsl.sh`).

## Day-to-day commands

```bash
chezmoi diff              # Preview pending changes
chezmoi apply             # Apply source state to ~/
chezmoi add ~/.config/foo # Track a new file
chezmoi update            # Pull remote changes + apply
```

## WSL notes

- `run_once_after_60-wsl.sh` writes `/etc/wsl.conf` (systemd on, Windows PATH trimmed for fast shells — `/mnt/c/Windows/System32` is re-added in `.zshrc` so `wslview`/`clip.exe` keep working), enables docker, and installs the SSH-agent bridge. Run `wsl --shutdown` from Windows once after the first apply.
- Copy `docs/wslconfig.example` to `%USERPROFILE%\.wslconfig` on the Windows host for memory caps, mirrored networking, and `autoMemoryReclaim`.

## Hardware quirks

### NVIDIA + suspend (laptops with NVIDIA GPU)

On machines with the proprietary NVIDIA driver, s2idle suspend corrupts GPU
state on resume — the symptom is a system that is hyper slow and unusable
after unlocking from a long idle lock, requiring a reboot.

`run_once_after_22-nvidia-suspend.sh.tmpl` applies the Arch-wiki fix on first
apply: writes `/etc/modprobe.d/nvidia-power-management.conf` with
`NVreg_PreserveVideoMemoryAllocations=1`, regenerates the initramfs, and
enables `nvidia-{suspend,resume,hibernate}.service`. The script is a no-op
on hosts without `nvidia-suspend.service` installed. A reboot is required
after first apply for the modprobe option to take effect.

## Repo layout notes

- `packages/` — pacman/AUR/brew package lists; editing a list re-triggers the install scripts on the next apply (see `packages/README.md`).
- `system/` — files outside `$HOME` (greetd/regreet); mirrored to `/etc` by `run_once_after_45-greetd.sh.tmpl` via sudo.
- `docs/` — reference material not deployed anywhere (e.g. `wslconfig.example`).
- DMS runtime files (`settings.json`, `niri/dms/outputs.kdl`) are chezmoi `create_` entries: seeded once on a fresh machine, then owned by DMS — `chezmoi apply` never overwrites them.

## Recovery

If greetd fails on boot: switch to TTY2 (`Ctrl+Alt+F2`) and run
`sudo systemctl disable --now greetd` to fall back to plain TTY login.
