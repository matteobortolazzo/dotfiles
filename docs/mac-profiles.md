# Mac profiles

Keep `profile = "mac"` and set `macMode` under `[data]` in
`~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
profile = "mac"
macMode = "minimal" # or "full-dev"
```

`minimal` keeps Zen, 1Password, Ghostty, OmniWM/skhd, SoundSource, LocalSend,
Tailscale, tmux and a small shell/tooling set. fnm supplies Node/npm for
Capacitor and web builds; libimobiledevice and ios-webkit-debug-proxy support
real-iPhone inspection. Xcode is installed separately from Apple, with the
iOS platform needed to build for a physical device. Use the system `vi` for
terminal editing; the full Neovim/LSP stack is omitted.

`full-dev` adds the general development, Android/Java, Docker, Go, Rust,
.NET/Aspire, Neovim and document/media tools. Existing configs with no
`macMode` retain this behavior. Linux/WSL are unaffected by `macMode`.

Run `chezmoi apply` after changing the setting. Installation is additive:
switching modes does not silently uninstall applications or erase data.
The toolchain scripts use `run_onchange`, so a full-dev → minimal → full-dev
apply cycle reinstalls removed toolchains instead of remembering an old
`run_once` success.

## Reclaim space after switching to minimal

Close Xcode, Docker and any running builds. From the dotfiles source directory:

```sh
python3 scripts/mac-cleanup.py --simulators --docker-data
python3 scripts/mac-cleanup.py --simulators --docker-data --apply
```

The first command previews everything. The second requires the live chezmoi
config to select `mac:minimal`. Run as your normal user; Homebrew may ask for
administrator authentication when uninstalling Docker helpers or Java.
Failures are reported at the end with a nonzero exit status; successful steps
are safe to repeat.

The script removes installed full-dev-only Brewfile entries, general
toolchains, Android SDK/emulators, generated build caches, Neovim's downloaded
language servers, and global Playwright/Mermaid browser tooling. It then runs
Homebrew autoremove and cache cleanup. Dependencies needed by remaining tools
are protected by Homebrew; manually installed tools are left for inspection.

`--simulators` deletes **all** simulated devices, their data and downloaded
runtimes through `simctl`. Physical iPhone builds continue to use Xcode's iOS
SDK. Simulator-based tests and SwiftUI simulator previews will require a
runtime download again. Apple's [component management documentation](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components)
also describes removal from Xcode Settings → Components.

`--docker-data` deletes **all local Docker Desktop images, containers and
volumes**, including local databases. Omit it to preserve that data. Remote
Docker contexts and credentials in `~/.docker` stay intact.

Xcode itself, signing certificates, provisioning profiles, archives/dSYMs,
real-iPhone support, Android signing keys, browser profiles, SSH credentials
and source checkouts are preserved. Build caches will grow again with use.
Inspect other large directories before deleting anything else:

```sh
du -hd 1 ~/Library/Developer/Xcode /opt/homebrew/var/homebrew
du -hd 1 ~/Library/Caches ~/.local/share
df -h /
```

Do not manually strip SDKs or framework files from inside Xcode.app. For a
device-only workflow, decline optional simulator downloads when Xcode offers
them. Homebrew cleanup follows the supported [Homebrew cleanup commands](https://docs.brew.sh/Manpage.html).
