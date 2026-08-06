# Gaming / sim-rig host

Applies to the desktop (`profile = "main"`, `gaming = true`): CachyOS, Ryzen 7
9800X3D, RTX 5080, single Samsung Odyssey 49" ultrawide (5120x1440, 32:9),
Fanatec ClubSport V2/V2.5 wheelbase. It is also the remote dev box, reached over
SSH from the laptop.

## The ultrawide

5120x1440 at 240Hz needs either DSC over DP 1.4 or DP 2.1 UHBR. Blackwell has
DP 2.1, so use a DP 2.1-rated cable into the GPU and the link runs uncompressed —
worth doing, since DSC on NVIDIA + Wayland is the layer that historically causes
mode-setting oddities.

niri's globals in `config.kdl` are laptop-tuned (`default-column-width proportion
1.0`, smallest preset `0.5`), which on this panel means a 5120px-wide terminal and
nothing narrower than 2560px. The per-output `layout {}` override in the `DP-1`
block fixes that with thirds/quarters and `center-focused-column "always"` — see
the comments there for why `always` rather than the global `on-overflow`.

**HDR is unavailable on the desktop** — niri has no HDR support at all. This is a
VA panel, not OLED, so the loss is small: gamescope drives HDR itself for couch
gaming, sims don't use it, and VA HDR is unremarkable to begin with. Not worth
adding a Plasma session for on its own. (No burn-in concern either, so the static
DMS bar is fine for long dev sessions.)

Sims at 32:9 need per-title FOV work: AC/ACC handle 5120x1440 natively, iRacing
wants its multi-projection settings rather than a stretched single view.

## Two modes, deliberately not unified

|                  | Sim rig (local Odyssey)          | Couch (TV over ethernet)      |
| ---------------- | -------------------------------- | ----------------------------- |
| Session          | niri, game native fullscreen     | `gamescope-session-cachyos`   |
| Display path     | direct scanout, VRR on-demand    | gamescope composites, HDR     |
| Input            | Fanatec wheel + pedals via evdev | gamepad                       |
| Latency budget   | every frame counts               | encode already costs ~20 ms   |

The sim does **not** run under gamescope. The game is already native-res on the
attached panel, so nesting only adds a compose+scale step. niri's direct scanout
on a fullscreen window is the shortest path available.

greetd/regreet lets you pick the session per boot, so both modes coexist without
either compromising for the other. niri stays the default session; do not make
gamescope-session the default — Sunshine needs a logged-in session, and "nobody
logged in" is the classic way couch streaming fails when you're already on the
sofa.

### Why not KDE

Plasma buys nothing on frame rate — the compositor is out of the frame path for a
fullscreen game. It has two things niri lacks: HDR (niri's output config has no
HDR/color-management option at all) and tearing control. The HDR gap is covered
where it matters, because gamescope drives HDR itself in the couch session. VRR
is not a gap: niri has `variable-refresh-rate on-demand=true`.

Switching would fork `.chezmoiignore`, drop DankMaterialShell, and require
re-porting Glassmorphic Dark — the exact divergence this repo exists to prevent.

Two things would flip the default to Plasma, and neither requires rewriting
anything here — greetd sessions are additive, so `pacman -S plasma-meta` installs
alongside niri and regreet just gains an entry:

- **VRR or the 240Hz mode misbehaves under niri.** kwin gets far more testing on
  exotic high-bandwidth modes, and niri's own docs hedge that "some drivers have
  various issues with VRR". This is the one thing that can only be settled
  empirically on this panel.
- **VR.** SteamVR on Wayland is unreliable and an X11-capable session is the
  standard workaround.

## Fanatec

Force feedback comes from `hid-fanatecff-dkms` (AUR), module `hid_fanatec`.

**ClubSport V2/V2.5 (`0EB7:0001` / `0EB7:0004`) is marked experimental upstream**,
with no documented notes on what does and doesn't work — validate before trusting
the rig. Fully supported bases are CSL DD / DD Pro / ClubSport DD (`0EB7:0020`)
and CSL Elite.

Three failure modes, each of which looks like "nothing happened":

1. **Wheelbase not in PC mode** — the driver never binds. You get a working
   joystick with no FFB and no error.
2. **Not in the `games` group** — `fanatec.rules` grants device access to that
   group and nothing adds you to it. Handled by
   `run_once_after_26-gaming.sh.tmpl`; needs a re-login to take effect.
3. **DKMS not rebuilt after a kernel bump** — see the `linux-cachyos-headers`
   note in `packages/README.md`. The setup script warns when `modinfo
   hid_fanatec` fails.

Verify:

```bash
ls /dev/input/by-id/ | grep -i fanatec
fftest /dev/input/event<N>       # linuxconsole
oversteer                        # rotation, FFB gain, centring
```

In Steam, set **Controller → Steam Input → Disabled** per sim title, otherwise
Steam remaps the wheel axes into a virtual gamepad and pedal calibration breaks.

Proton: `proton-cachyos` handles Assetto Corsa / ACC well. iRacing is
"works with tweaks" tier — expect launch options or Proton-GE. `protontricks` is
installed for per-prefix fixes.

## Streaming to the TV

**The ultrawide makes desktop capture the wrong approach.** Capturing a 5120x1440
output and sending it to a 16:9 TV letterboxes into a thin horizontal strip with
most of the panel wasted. Couch mode therefore has to be the
`gamescope-session-cachyos` session with gamescope set to the TV's resolution
(`-W 3840 -H 2160`), not Sunshine pointed at the niri desktop. This is the main
reason the two sessions stay separate rather than one session serving both.

niri is not wlroots-based, so Sunshine's `wlr-export-dmabuf` capture path is
unavailable. The options are:

- **KMS capture** — compositor-agnostic, and the only Sunshine path with
  end-to-end HDR. Needs `CAP_SYS_ADMIN`, applied by
  `run_once_after_26-gaming.sh.tmpl`.
- **xdg-desktop-portal ScreenCast** — works (`xdg-desktop-portal-gnome` is
  already in `arch-desktop.txt`), no HDR.

Validate the network with Steam Remote Play + Steam Link first: Steam does its own
capture and encode, so it sidesteps all of the above and needs zero config. Then
move to Sunshine + Moonlight for 4K/HDR and non-Steam titles — NVENC AV1 on
Blackwell makes that comfortable. Prefer an Android TV Moonlight client that
decodes AV1 over a TV's built-in app.

DMS's idle lock will lock the box out from under a running stream. Wire an idle
inhibitor into Sunshine's app prep commands — check the verb with
`dms ipc call idle`.

## Remote dev

`run_once_after_27-sshd.sh.tmpl` enables `sshd` and writes
`/etc/ssh/sshd_config.d/10-hardening.conf` — but only once
`~/.ssh/authorized_keys` is non-empty, so a headless box can't lock itself out.
Tailscale covers off-LAN access.

`~/.ssh/config` on the *other* machines gets a `Host desktop` entry with
`ForwardAgent yes`. Agent forwarding rather than a key on the desktop, because
its 1Password agent socket needs an unlocked GUI that an SSH session doesn't
have.

## CPU note

The 9800X3D is single-CCD, so none of the core-parking / CCD-preference tuning
written for the 9950X3D applies. `linux-cachyos` plus `scx_lavd` via
`scx_loader` (enabled by the setup script) is the whole story.
