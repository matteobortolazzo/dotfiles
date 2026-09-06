# LocalSend

An AirDrop-equivalent that actually spans the four platforms in use here —
Linux, macOS, Android, iOS. Installed by the package lists (`localsend-bin` in
`packages/arch-aur-desktop.txt`, `cask "localsend"` in `packages/Brewfile`);
the phones are a manual store install. The firewall half is
`run_once_after_28-firewall.sh.tmpl`.

Nothing here is configured by chezmoi beyond the package and the ports.
LocalSend keeps its own state in `~/.local/share/localsend_app/` and there is no
config file worth tracking — the settings that matter (alias, save directory,
quick save) are per-machine choices, not dotfiles.

## Why this one

The requirement was all four platforms, no account, no cloud round-trip. That
eliminates almost everything:

| Candidate | Why not |
| --- | --- |
| **LocalSend** | — (chosen) |
| KDE Connect | Linux↔Android is excellent; the iOS client is a thin subset and file send is not the part that works well. |
| Warpinator | No iOS client at all. |
| Syncthing | Wrong model — continuous folder sync, not ad-hoc send — and no first-party iOS client. |
| PairDrop / Snapdrop | Kept as the *fallback*, see below. Browser-only, so no native share sheet, and the public instance means a third-party signalling server. |

LocalSend is LAN-only by design: discovery is multicast, transfer is a direct
HTTP(S) connection between the two devices, and no packet leaves the subnet.
There is no server to trust because there is no server.

## What actually goes over the wire

Worth knowing, because every failure mode below is one of these two being
blocked. Both use the same port number, which makes it easy to open one and
believe you have opened both.

| Leg | Protocol | Port | Purpose |
| --- | --- | --- | --- |
| Discovery | UDP multicast to `224.0.0.167` | 53317 | Devices announce themselves and answer announcements. |
| Transfer | TCP, HTTPS by default | 53317 | The REST API that carries metadata and file bytes. |

Under HTTPS the certificate is self-signed and per-install; the "fingerprint"
shown in the UI is its SHA-256. That is what pins a device across sessions, so a
reinstall legitimately shows up as a new device.

If multicast fails, LocalSend falls back to *legacy mode*: it POSTs
`/api/localsend/v2/register` to every address in the subnet. Slower, and it is
why a device sometimes appears after a long pause on a network that blocks
multicast — the fallback found it the hard way.

## The ufw trap

Only the desktop runs a firewall (`dev = true` gates `28-firewall`); the laptop
has no ufw and needs nothing. On the desktop, ufw's default-deny inbound drops
both legs in netfilter before LocalSend ever sees them, and the app has no way
to report that — it just doesn't list the device. The two rules are:

```bash
sudo ufw allow from 192.168.1.0/24 to any port 53317 proto udp   # discovery
sudo ufw allow from 192.168.1.0/24 to any port 53317 proto tcp   # transfer
```

Both are LAN-scoped, matching how sshd and Sunshine are scoped in the same
script. `to any` rather than a destination address is deliberate — the multicast
group `224.0.0.167` is not a LAN unicast address, so a destination-scoped rule
would miss the announcements entirely.

The two symptoms are distinguishable, which makes this quick to diagnose:

- **Desktop never appears** in the phone's device list → UDP is blocked.
- **Desktop appears, sends to it stall at 0%** → TCP is blocked.

## Off the LAN, over Tailscale

Multicast does not traverse a tailnet, so auto-discovery stops at the subnet
boundary. Manual discovery still works: *Add device by IP* in the LocalSend UI,
pointed at the peer's MagicDNS address, drives the same TCP register/upload API.
`28-firewall` opens 53317/tcp on `tailscale0` for exactly this, with no UDP
counterpart because there would be nothing to receive on it.

Tailscale's own `tailscale file cp` / `taildrop` covers the same ground for
Linux/macOS/Android/iOS and needs no firewall rule, since it rides the tailnet.
It is the better tool when both devices are already on the tailnet and worse
when they are not — hence keeping both.

## On the headless desktop

`headless = true` means the desktop usually boots to `multi-user.target` with no
compositor. LocalSend is a GUI app: with no session there is nothing listening
on 53317 and the box is invisible regardless of the firewall. Bring a session up
first (`desktop up niri`, see [`headless.md`](headless.md)) or use
`tailscale file cp`, which is served by `tailscaled` and works on a bare TTY.

## Browser fallback

For a device you cannot or do not want to install on — a borrowed laptop, a
locked-down work machine — LocalSend can hand out a plain URL. Share from the
app, and the receiver opens `http://<sender-ip>:53317` in any browser. Plain
HTTP for this path, so treat it as LAN-only.

[PairDrop](https://pairdrop.net) is the other fallback: pure browser on every
platform including iOS Safari, WebRTC peer-to-peer, with only the signalling
handshake touching the server. Self-hostable if the public instance is not
acceptable.

## Package choice

`localsend-bin` over the source `localsend`, deliberately. The source PKGBUILD
builds Flutter and Rust from scratch — `fvm`, `cargo`, `clang`, `cmake`, `llvm`,
`ninja` as make-dependencies — and would run that build on every version bump
inside an unattended `chezmoi apply`. `localsend-bin` repacks the upstream `.deb`
and depends on `fuse2`, `xdg-user-dirs` and `libayatana-appindicator`.

The cost is that `-bin` sometimes trails upstream by a patch release while the
maintainer catches up, and can sit flagged out-of-date for a while. That is
acceptable here: `21-aur.sh.tmpl` already retries failed packages one at a time
and reports them by name rather than aborting the apply.

### The ayatana libs

`ayatana-ido` and `libayatana-indicator` are in `packages/arch-desktop.txt` for
LocalSend's sake alone — nothing else here uses them and nothing pulls them in
any more. That is the repack biting: the `.deb` is built on Ubuntu against
libayatana-appindicator 0.5.x, so the binary links `libayatana-indicator3.so.7`
and `libayatana-ido3-0.4.so.0` directly, while Arch's libayatana-appindicator
0.6.0 dropped both from its `Depends On`. `localsend-bin`'s declared dependency
on libayatana-appindicator was once enough and no longer is.

The failure mode is why it is worth a paragraph: the app does not warn, it does
not open a window, it does not log anywhere. Launching from the app menu looks
like the click did nothing at all. Only running it from a terminal shows it:

```bash
localsend
# localsend: error while loading shared libraries: libayatana-indicator3.so.7:
# cannot open shared object file: No such file or directory
ldd /opt/localsend/localsend | grep 'not found'   # the general form
```

An Arch rebuild of libayatana-appindicator can strip another of these at any
time, so `ldd` on the binary is the first check whenever LocalSend stops
starting — before assuming the firewall or the network.

## Checks

```bash
ss -ulnp | grep 53317          # is anything listening (i.e. is the app running)
sudo ufw status verbose | grep 53317
```

`ss` showing nothing means the app is not running — check that before touching
the firewall. Both rules present and the peer still invisible usually means AP
isolation on the access point (common on guest wifi), which blocks client-to-
client traffic upstream of both machines; the Tailscale path is the way around
it.
