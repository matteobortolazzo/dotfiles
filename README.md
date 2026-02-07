# Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://www.chezmoi.io/). Primary target is Arch Linux with Hyprland (Wayland). Terminal configs (zsh, tmux, neovim, yazi, ghostty, lazygit, bat) are shared with macOS.

## Prerequisites

### 1Password

Secrets are stored in 1Password and pulled during `chezmoi apply`, so 1Password must be set up first.

**Arch Linux:**

```bash
pacman -S 1password 1password-cli
```

**macOS:**

```bash
brew install --cask 1password
brew install 1password-cli
```

Then sign in to the CLI:

```bash
op signin
```

Enable the SSH agent in the 1Password desktop app: **Settings > Developer > SSH Agent**.

### chezmoi

**One-liner** (installs chezmoi and applies dotfiles):

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply matteobortolazzo
```

Or install separately first:

```bash
# Arch
pacman -S chezmoi

# macOS
brew install chezmoi
```

Then init and apply:

```bash
chezmoi init matteobortolazzo
chezmoi apply
```

### chezmoi config

Create `~/.config/chezmoi/chezmoi.toml` with:

```toml
[onepassword]
  mode = "account"
```

This tells chezmoi to use 1Password account mode for secret resolution.

## Per-project ADO environment

Global secrets (OpenAI, Anthropic, GitHub, etc.) are auto-populated into `~/.config/environment` by chezmoi templates. The file is sourced by `.zshrc`.

For per-project Azure DevOps overrides, [direnv](https://direnv.net/) is hooked into zsh and `.envrc` files are globally gitignored.

Create an `.envrc` in the project root:

```bash
export ADO_ORG="my-org"
export AZURE_DEVOPS_EXT_PAT="$(op read 'op://Private/ADO PAT - my-org/credential')"
export ADO_MCP_AUTH_TOKEN="$AZURE_DEVOPS_EXT_PAT"
```

Then allow it:

```bash
direnv allow
```

## Day-to-day commands

```bash
chezmoi diff              # Preview pending changes
chezmoi apply             # Apply source state to ~/
chezmoi add ~/.config/foo # Track a new file
chezmoi add --template ~/ # Track as template (for OS-specific files)
chezmoi update            # Pull remote changes + apply
```
