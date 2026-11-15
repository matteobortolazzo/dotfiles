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
real-iPhone inspection. Android builds use the `android-commandlinetools` cask
instead of Android Studio: `run_onchange_after_37-android-sdk` installs
`platforms;android-36`, `build-tools;36.0.0` and `platform-tools` into
`$(brew --prefix)/share/android-commandlinetools`, which `.zshrc` exports as
`ANDROID_HOME`. sdkmanager needs a JDK, which minimal does not install (any
`/usr/libexec/java_home` hit works, e.g. a JetBrains Runtime). The upload
keystore and its password come from 1Password like on every profile. lazygit
(`lg`) is kept too. Xcode is installed separately from Apple, with the
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

## 1Password CLI needs Full Disk Access for the terminal

Secrets (`~/.config/environment`, the Capgo OTA keys under
`~/.config/velka/capgo/`, the Android upload keystore) render only when
`.chezmoiignore`'s probe — `op signin --raw && op vault list` — succeeds
through the 1Password desktop app integration. On macOS that integration
talks to the app over files in its group container
(`~/Library/Group Containers/2BUA8C4S2C.com.1password/`), and macOS blocks
that folder unless the terminal (Ghostty) has permission to access other
apps' data. If the terminal is blocked, `op` cannot reach the app and reports
**"No accounts configured for use with 1Password CLI"** even with Settings →
Developer → *Integrate with 1Password CLI* on and the app unlocked.
`chezmoi apply` then warns that 1Password cannot authenticate and skips every
secret.

Fix: System Settings → Privacy & Security → **Full Disk Access**, add Ghostty,
restart it, then check with `op vault list` and run `chezmoi apply`. (Clicking
Allow on the "access data from other apps" prompt is enough if it shows up;
`tccutil reset SystemPolicyAppData com.mitchellh.ghostty` brings back an
answer that was previously denied.) Don't use `op account add` as a
workaround: the probe runs with stdin closed, so a password-only account can
never pass it.

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
