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

**The ultrawide makes naive desktop capture the wrong approach.** Capturing a
5120x1440 output and sending it to a 16:9 TV letterboxes into a thin horizontal
strip with most of the panel wasted — see the 32:9/16:9 section below for the
two ways out (drop the output to a 16:9 mode for the stream, or run
`gamescope-session-cachyos`, which drives the output itself). Either way the two
sessions stay separate rather than one serving both.

niri is not wlroots-based, so Sunshine's `wlr-export-dmabuf` capture path is
unavailable. The options are:

- **KMS capture** — compositor-agnostic, and the only Sunshine path with
  end-to-end HDR. Needs `CAP_SYS_ADMIN`, applied by
  `run_once_after_26-gaming.sh.tmpl`.
- **xdg-desktop-portal ScreenCast** — works (`xdg-desktop-portal-gnome` is
  already in `arch-desktop.txt`), no HDR.

In practice Sunshine picks a third one: niri does implement
`zwlr_screencopy_manager_v1` even though it is not wlroots-based, so the log
reports `[wlgrab] Selected monitor ... DP-1`. That path works and needs no
capability, but it captures the 32:9 output as-is — fine for a desk test, still
the wrong shape for the TV.

### Enabling it

The systemd user unit is **`app-dev.lizardbyte.app.Sunshine.service`**.
`sunshine.service` is only an `[Install] Alias`, so it does not resolve until
the real unit has been enabled once — `systemctl --user enable sunshine.service`
fails with `not-found` on a fresh machine.

It is `WantedBy=graphical-session.target`, and that is the only correct way to
start it. Starting it by hand from a tty or over SSH gives it no
`WAYLAND_DISPLAY` and no output; the encoder probe then walks nvenc → vulkan →
vaapi → software, fails all four, and ends at:

```
Fatal: Unable to find display or encoder during startup.
Fatal: Please check that a display is connected and powered on.
```

That message is about the *session*, not the hardware — the fix is to bring up
a session (`desktop up niri` / `desktop up gamescope`) and let the target pull
Sunshine in, or `systemctl --user restart app-dev.lizardbyte.app.Sunshine.service`
once one is running. A healthy startup logs `Found H.264/HEVC/AV1 encoder:
*_nvenc` and the monitor name.

### The prep hook

`dot_config/sunshine/stream-prep.sh` is wired into Sunshine's
`global_prep_cmd` (`do` = `on`, `undo` = `off`) and does two things:

- **Holds off DMS's idle lock**, which would otherwise lock the box out from
  under a running stream. `dms ipc call inhibit enable` takes no argument — the
  reason is a separate `inhibit reason <text>` call.
- **Optionally switches DP-1 to a 16:9 mode** for the duration of the stream,
  then restores whatever mode was in effect. **Off by default**
  (`SUNSHINE_STREAM_MODE=off`) — see below.

It always exits 0. Prep commands run without a shell, so there is no `|| true`
to lean on and a non-zero exit aborts the stream before it starts. Under
`gamescope-session` neither `dms` nor `niri` is running and both steps no-op.

`niri msg output DP-1 mode auto` is **not** a way to restore the desk mode: it
selects the connector's *preferred* mode, which on this panel is 3840x1080, not
the 5120x1440 that `config.kdl` sets. The hook records the outgoing mode to
`$XDG_RUNTIME_DIR/sunshine-stream-prep.mode` and plays it back verbatim.

`sunshine.conf` is rewritten wholesale by the web UI, so it is tracked as
`dot_config/sunshine/modify_sunshine.conf`: it re-asserts the one
`global_prep_cmd` line and passes every other key through untouched.

### 32:9 desk, 16:9 TV

Sunshine captures the output as it is, so streaming the native 5120x1440 mode
lands on the TV as a thin letterboxed strip with most of the frame wasted. The
Odyssey does expose true 16:9 modes — `niri msg outputs` lists
`2560x1440@120`, `1920x1080@120` and `1920x1080@60` alongside the ultrawide
ones — so the desk panel can simply be dropped to 1440p16:9 while streaming,
which is also the bitrate/latency starting point recommended below. That is
what the prep hook does, and it is why the niri session is usable for couch
streaming at all.

**The mode switch breaks XWayland games, which is why it defaults to off.** niri
changes the Wayland output mode, but `xwayland-satellite` does not propagate it
to the X screen: `xrandr` keeps reporting `Screen 0: current 5120 x 1440` while
`niri msg outputs` says 2560x1440. A Proton title then renders 5120 wide into an
output displaying 2560 of it, and exactly half the game is visible — measured on
Spec Ops: The Line. Native Wayland clients follow the mode correctly, so the
switch is opt-in via `SUNSHINE_STREAM_MODE` rather than removed.

That leaves the **16:9 dummy plug as the real fix**: a genuine 16:9 output means
no mode switching, so nothing to propagate and nothing to desynchronise.

The `gamescope-session` route sidesteps the question differently: gamescope
drives the output itself and the game never sees the ultrawide. Note that
`gamescope-session-cachyos`'s launcher (`/usr/lib/steamos/gamescope-session`)
exposes no `-W`/`-H` knob — it takes the output's mode — so "gamescope set to
`-W 3840 -H 2160`" means patching the launcher, not setting an env var.

### Monitorless: it needs a dummy plug, not a config option

Streaming from the couch with the Odyssey switched off does **not** work by
config alone. Login is not the obstacle — `desktop up niri` autologins over SSH
with no greeter — the display is: niri 26.04 has no headless backend and no
virtual outputs (there is no `niri msg` verb for one, and the output docs only
describe matching *connected* monitors), and embedded gamescope likewise drives
a real DRM connector. Sunshine needs a connector reporting `connected`.

**This panel drops off when powered down** — measured, with the monitor off and
`cat /sys/class/drm/card1-DP-1/status` over SSH reporting `disconnected`. So
niri has no output at all and Sunshine has nothing to grab: couch streaming with
the Odyssey switched off requires a plug, not a setting. (The same check is how
to re-test if the monitor or cable is ever swapped; `connected` there would mean
the link survives standby and none of this is needed.)

**The software workarounds do not apply to this box.** `drm.edid_firmware=` and
`video=DP-1:e` are core-DRM helpers; the proprietary NVIDIA driver does not
honour them, and `modinfo nvidia` exposes no EDID-override parameter (only
`NVreg_*` registry dwords, none of which take an EDID). Every write-up of those
tricks is for amdgpu/i915/nouveau. So the options are to leave the monitor
powered on, or a hardware EDID dummy plug — DP-2, DP-3 and HDMI-A-1 are free.

A **16:9** dummy plug is worth preferring: it makes the connector permanently
present *and* removes the aspect-ratio problem at the source, which retires the
mode-switch half of `stream-prep.sh` (give it its own `output` block in
`config.kdl` and point Sunshine's `output_name` at it).

**Steam Remote Play avoids all of it**: Steam captures the game, not the
output, and renders at whatever the Steam Link client asks for. For Steam
titles it is both the easiest and the best-looking answer, and it is the right
way to validate the network first — zero config, its own capture and encode.
Sunshine earns its place on non-Steam titles and HDR.

### Client: Philips 55OLED854/12 (2019)

The TV runs Android TV, so Moonlight's native client installs on it directly — no
extra hardware. Its specs bound what is worth configuring:

- **Encode HEVC, not AV1.** Philips only added AV1 decode in its 2021 sets. The
  5080 encodes AV1 well and it is the wrong choice here.
- **4K60 ceiling, no VRR** — four HDMI 2.0b ports. Don't chase 120Hz.
- **~33 ms panel lag in Game mode**, which is the dominant term in the whole
  chain and is fixed. A faster streaming box cannot improve it; an external
  client only helps if the 2019 MediaTek SoC turns out to stutter on
  low-latency decode. Start at 1440p60 / ~40 Mbps and push up.
- **Enable Game mode and ALLM** (supported on Philips' 2019 OLEDs) before
  judging any of this.
- **The ethernet port is 100 Mbit** — confirmed, not just suspected: fast.com on
  the TV tops out at ~90 Mbps against a gigabit line, and the desktop's `eno1`
  negotiates 1000. It does not affect the 1440p60 / ~40 Mbps target (Moonlight
  traffic is LAN-only and that leaves 2x headroom), but it makes 4K60 marginal: good 4K60 HEVC
  wants 50-80 Mbps, which fits under ~90 with little burst headroom. Dropping
  HDR does not rescue it — 10-bit costs 10-20%, not half — so SDR is about as
  demanding as HDR at the same resolution and framerate. Judge it by Moonlight's
  performance overlay — achieved bitrate at target with no drops — rather than
  by the port speed.
- HDR10 is supported, so HDR streaming works — via the KMS capture path above.
- It is an OLED: don't leave a paused game or static HUD up for hours.

Rejected client options, so they don't get re-litigated:

- **`moonlight-xbox` on the Xbox already at the TV.** The UWP port is actively
  maintained, but it needs Developer Mode and sideloading via the Device Portal,
  and Dev Mode cannot run retail games — every switch between streaming and
  playing an Xbox game is a multi-minute reboot. It also does nothing for the
  panel lag, which is the dominant term. Only worth it if the console gets
  repurposed as a dedicated streaming box.
- **A €50 Google TV Streamer / Onn 4K Pro** beats the Xbox route if the TV's own
  SoC stutters: no reboots, no dev account, modern decoder. It is also the only
  way to lift the 100 Mbit bitrate ceiling, so it becomes the answer if 4K60 HDR
  is ever wanted. Still does not improve latency — the panel lag is the panel's.

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
