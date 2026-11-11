# Remote access and Herdr

## Machine policy

| Machine | Everyday remote access | Recovery |
| --- | --- | --- |
| Native Linux (`main`) | Tailscale SSH, with the Linux username | OpenSSH with an authorized key on the trusted LAN, or local console |
| macOS | Tailscale networking + key-based Remote Login | Remote Login over the LAN, or local console |
| WSL | Outbound SSH client over Tailscale | No inbound SSH daemon configured |
| Android | Tailscale networking + Herdr connecting to Linux over SSH | Keep another client or local console available |

Tailscale provides the network path. Tailscale SSH additionally authenticates
the caller through their tailnet identity and SSH access rules. On a Linux host
with it enabled, port 22 on the Tailscale address goes to Tailscale's SSH server;
port 22 on the LAN address still goes to OpenSSH. Enabling it does not delete
`authorized_keys` or rewrite OpenSSH configuration.

Keep all existing authorized keys for LAN recovery and Mac access. The repository
does not manage private keys or `authorized_keys`; this change removes automatic
agent forwarding, not keys. `IdentityAgent` still supplies keys from 1Password on
native clients and the regular OpenSSH agent on WSL. Use `ssh -A` only when a
particular remote command needs access to your agent.

The standard macOS Tailscale app cannot host Tailscale SSH; that requires the
separate open-source `tailscaled` variant. Keep the existing app and Remote Login.

## Enable Linux access

`24-tailscale-ssh` runs after the Tailscale service setup, on every native Linux
`main` host. It skips already enabled hosts and does not accept a disconnect
automatically. If applying over Tailscale, enable it from a local terminal or run:

```sh
sudo tailscale set --ssh --accept-risk=lose-ssh
```

This can disconnect existing SSH sessions over Tailscale. Then rerun
`chezmoi apply`. The tailnet policy must allow both network access to port 22
and SSH access to the chosen Linux username. A `check` rule can require a browser
sign-in before a connection completes. Do not disable OpenSSH or remove LAN keys.

For personal devices whose SSH client cannot display browser approval, use this
own-device policy in the Tailscale admin console. Keep unrelated rules; replace
the overlapping own-device `check` rule rather than leaving it matched against
non-root users, since `check` rules take precedence over `accept` rules:

```json
"ssh": [
  {
    "action": "accept",
    "src": ["autogroup:member"],
    "dst": ["autogroup:self"],
    "users": ["autogroup:nonroot"]
  },
  {
    "action": "check",
    "src": ["autogroup:member"],
    "dst": ["autogroup:self"],
    "users": ["root"]
  }
]
```

This still authenticates the caller through Tailscale and restricts access to
their own devices. Root still requires browser approval. The dotfiles cannot
change the tailnet's centrally managed policy; enabling the host is separate.

```sh
ssh mborto@amd-desktop       # Tailscale SSH through MagicDNS
ssh mborto@<desktop-LAN-IP>  # OpenSSH using an authorized key
```

## Herdr desktop, headless and mobile

`43-herdr` installs Herdr TUI and `herdr-core` (`hc`) on Linux and macOS, including
headless hosts and WSL. Native Linux and Mac hosts additionally receive the desktop
app unless `headless = true`. Each installer is skipped when its binary is already
installed. Installation uses the official release installers, which verify their
downloaded binaries; upgrades remain explicit.

The official Android app connects to **herdr-core**, not the TUI's separate
server. Agents started in the TUI do not appear in the official mobile app.
Start mobile-visible agents with core, for example:

```sh
hc server status
hc run --bg codex
hc ls
```

Connect Tailscale on Android. In the official Herdr app, enter the desktop's
MagicDNS name (`amd-desktop`), Linux username (`mborto`), and port `22`.
Follow any sign-in approval shown by Tailscale. A GitHub/Tailscale account name
is not the Linux username. No desktop session or GUI app is needed on the host.

## Everyday laptop work and quick SSH access

Open the Herdr desktop app on the laptop, connect `mborto@amd-desktop`, and create
the space on that remote machine. Spaces group tabs; tabs arrange panes; terminal
panes run in the desktop's core. The graphical client can close while those
programs continue. Herdr TUI has a separate server and cannot attach to core.

For quick access from any SSH client, no graphical app is required:

```sh
ssh mborto@amd-desktop
hc                    # pick a core terminal
# Or select one explicitly:
hc ls
hc attach t1          # replace t1 with an ID from hc ls
```

`Ctrl+\` detaches from an attached core terminal, leaving its program running.
This accesses the same core terminals as the desktop and phone apps, but does
not provide the TUI's full workspace interface.

## Laptop keyboard: Ctrl+S and tmux-style keys

Native graphical hosts receive the official Herdr tmux-prefix example under the
dotfiles-owned name `dotfiles-prefix`, rebound to match `tmux.conf`: `Ctrl+S`
prefix, 500 ms repeat window. The popup shows the bindings; `?` expands the
list and Escape cancels.

| After Ctrl+S | Action |
| --- | --- |
| `c` | New tab |
| `h` or `\|` / `v` or `-` | Split right / down |
| Arrows | Focus another pane |
| `n` / `p` | Next / previous tab |
| `1`–`9`, `0` | Select tab 1–9, 10 |
| `J` / `K` | Next / previous space |
| `f` or `z` | Zoom pane |
| `x` | Close pane and end its terminal |
| `d` | Minimize the app window; programs keep running |
| `Ctrl+S` again | Send a literal Ctrl+S to the terminal |

The app has no resize action, so tmux's `j`/`k`/`l` resize exists only in the
TUI. The Herdr **TUI** gets the same layout from
`dot_config/herdr/modify_config.toml`, which owns the `[keys]` tables of
`~/.config/herdr/config.toml` and leaves the rest to Herdr: `j`/`k`/`l` resize,
`q` detaches, and `Ctrl+T`/`Ctrl+G`/`Ctrl+F`/`Ctrl+Z` open the same zsh,
lazygit, yazi and `~/.zshrc` popups as tmux. Check it with `herdr config check`
and load it with `herdr server reload-config`. Nesting tmux inside Herdr means
both want `Ctrl+S`; Herdr gets it first.

`Ctrl+S` is captured by the app instead of reaching the foreground program;
press it twice when that program needs it. The mod invokes `hc keys` to forward
literal keys, including to remote terminals; it does not add a network service.
This prefix is for the graphical app; SSH `hc attach` still uses `Ctrl+\` to detach.

The `modify_keys.json.tmpl` merge preserves existing key bindings and adds the
prefix. Fresh installs are seeded from upstream Linux/macOS default key files
retrieved on 2026-11-10. Herdr treats customized key files as user-owned, so new
upstream shortcuts need merging into these snapshots when updating the app.
Headless hosts and WSL skip this graphical configuration. The upstream mod's
Apache-2.0 license is included alongside it.

## Diagnose a failed phone connection

1. Check that both devices are connected to the same tailnet. Try the desktop's
   Tailscale IP if the phone cannot resolve its MagicDNS name.
2. Confirm Tailscale SSH is enabled: `tailscale debug prefs` should report
   `"RunSSH": true`. Password authentication remains disabled in OpenSSH.
3. Read `journalctl -u tailscaled --since '10 minutes ago'`. A connection from
   the phone followed by no granted session means SSH authentication has not
   completed; inspect the client's sign-in prompt and the tailnet SSH policy.
4. After authentication succeeds, run `hc server status` and `hc ls` as the
   Linux user. An empty agent list can mean agents were started in the TUI instead
   of core. Ensure `~/.local/bin` is on the remote command's PATH, or invoke
   `~/.local/bin/herdr-core` explicitly when diagnosing.

References: [Tailscale SSH](https://tailscale.com/docs/features/tailscale-ssh),
[Herdr mobile](https://herdr.dev/mobile/), [herdr-core](https://herdr.dev/core/),
[official prefix mod](https://herdr.dev/mods/herdrdev/tmux-prefix/).
