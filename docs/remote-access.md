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
[Herdr mobile](https://herdr.dev/mobile/), [herdr-core](https://herdr.dev/core/).
