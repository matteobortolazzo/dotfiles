# Gaming / sim-rig host

Applies to the desktop (`profile = "main"`, `gaming = true`): CachyOS, Ryzen 9
7900X3D, RTX 4080 (Ada, `AD103`), single Samsung Odyssey 49" ultrawide (5120x1440, 32:9),
Fanatec ClubSport V2/V2.5 wheelbase. It is also the remote dev box, reached over
SSH from the laptop.

## The ultrawide

5120x1440 at 240Hz needs either DSC over DP 1.4 or DP 2.1 UHBR. Ada tops out at
DP 1.4a, so the link runs with DSC — and DSC on NVIDIA + Wayland is the layer
that historically causes mode-setting oddities. If the 240Hz mode misbehaves,
test 120Hz (no DSC needed) before blaming niri or VRR.

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

greetd/dux-greeter lets you pick the session per boot, so both modes coexist without
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
alongside niri and dux-greeter just gains an entry:

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

Assetto Corsa's verified configuration uses **GE-Proton9-2, CSP 0.3.2-preview2,
and Pure 3.59 Highres**. See [the installation and repair runbook](assetto-corsa.md)
for the Wine font fix, weather/filter settings, partial CSP update diagnosis,
verification, and backups. Keep this per-game Proton selection when experimenting
with global defaults. iRacing is
"works with tweaks" tier — expect launch options or Proton-GE. `protontricks` is
installed for per-prefix fixes.

## NVIDIA features

Step-by-step runbook (test order: ordinary games → Content Manager AC → DLSS 5)
is in [`nvidia.md`](nvidia.md); this section is the reasoning.

The GPU is an **RTX 4080 (Ada)**, which bounds what "latest NVIDIA tech" means
here. The Linux driver (615.x, from the CachyOS installer) carries the same NGX
stack as Windows; the Windows-only parts are the NVIDIA App toggles (RTX HDR,
RTX Video, the DLSS override UI). On Linux every one of those is an environment
variable, so they are collected in **`~/.local/bin/nvrun`**
(`dot_local/bin/executable_nvrun`), a wrapper for Steam launch options:

```
nvrun [--no-dlss] [--smooth] [--reflex] [--hud] [--csp] [--nr] [--log] %command%
```

| Feature | Ada? | Flag | What it sets |
| --- | --- | --- | --- |
| DLSS 4 transformer SR/RR + newest DLLs | yes | default (`--no-dlss` to skip) | `PROTON_DLSS_UPGRADE=1` (`PROTON_ENABLE_NGX_UPDATER=1` for Valve's Proton), `DXVK_NVAPI_DRS_SETTINGS=…render_preset_latest`, `PROTON_FORCE_NVAPI=1` |
| DLSS Frame Generation (single) | yes, in titles that ship it | default | `ngx_dlss_fg_override=on` (part of the line above) |
| DLSS Multi Frame Generation | **no — Blackwell only** | — | — |
| Smooth Motion (driver FG, any game) | yes | `--smooth` | `NVPRESENT_ENABLE_SMOOTH_MOTION=1` |
| Reflex | yes | `--reflex` (DX11 needs nothing) | `DXVK_NVAPI_VKREFLEX=1`, `PROTON_VKD3D_LOWLATENCY=1` |
| DLSS indicator | — | `--hud` | `PROTON_DLSS_INDICATOR=1` |
| DLSS 5 neural rendering | **no — RTX 50 only, 40 "later this fall"** | `--nr` (community route, below) | `PROTON_FORCE_NVAPI=1`, `WINEDLLOVERRIDES=dxgi=n,b` |

Notes that are not obvious from the table:

- **Why the wrapper sets `DXVK_NVAPI_DRS_SETTINGS` itself.** Proton-CachyOS's
  `PROTON_DLSS_UPGRADE` downloads the DLLs and then only `setdefault()`s the
  override string with preset `default`. NVIDIA's Linux guide recommends
  `render_preset_latest`; that is the one that flips titles still shipping CNN
  DLSS onto the transformer model. The DRS overrides replace the in-game DLSS
  preset choice entirely. (NVIDIA's doc also says preset overrides are "not
  supported on Linux" — that sentence is about *native* Linux games; the
  dxvk-nvapi path for Proton is documented right above it on the same page.)
- **Smooth Motion is the only frame generation that reaches a DX11 game with
  no upscaler at all** (Assetto Corsa). It lives in `VK_LAYER_NV_present`, an
  implicit layer whose `enable_environment` is exactly that variable, and DXVK
  presents through Vulkan, so the API the game uses does not matter. It is
  interpolation on the final frame: latency stays that of the base framerate
  and artefacts cluster around the HUD and the car. For a sim that is the
  wrong trade unless the base is already locked — try it on ACC/EVO when they
  are GPU-bound, not on AC, which the 4080 runs far above the panel's refresh
  anyway. Never stack it on a title with native DLSS FG turned on.
- **Reflex on DX11/DX12 under Proton needs nothing** — dxvk-nvapi handles it.
  `--reflex` is for Vulkan-native games (the layer is disabled by default) and
  for the DX12 low-latency fork; both are harmless elsewhere.
- **Verify, don't trust.** `--hud` draws NVIDIA's own indicator; `--log` dumps
  `$HOME/steam-<appid>-<proton>.log`, where `nvapi` lines show whether NVAPI was
  exposed and which `nvngx_dlss` build loaded. `MANGOHUD=1` for the frametime.
- These are launch-option variables, so they apply the same under niri and
  under `gamescope-session`; Smooth Motion in the couch session is fine.
- **Pick the Proton per title.** Assetto Corsa is pinned to **GE-Proton9-2**
  after a CSP launch failure with GE-Proton11-7. For other titles,
  **Proton-CachyOS** (installed by pacman, system-wide) is the build whose DLSS
  downloader and indicator the wrapper targets first.
- GE-Proton vs Proton-CachyOS: both read every variable above
  (`PROTON_DLSS_UPGRADE` landed in GE-Proton 10-26). GE-Proton disables NVAPI
  unless the title is allowlisted, which is why `--dlss` forces it.

### Assetto Corsa: Content Manager, CSP, and the DLSS 5 experiment

AC now runs Content Manager, CSP preview, and Pure; the verified installation is
documented in [assetto-corsa.md](assetto-corsa.md). The Linux setup repos (`crmne/assetto-corsa-setup`,
`sihawido/assettocorsa-linux-setup`) all do the same thing: replace
`AssettoCorsa.exe` with Content Manager (original kept as
`AssettoCorsa_original.exe`), pin a GE-Proton, install CSP 0.2.x plus fonts
via protontricks. Steam's `%command%` then *is* Content Manager, and CM spawns
`acs.exe`. Environment is inherited down that chain, so `nvrun` goes in the
same launch options and reaches the renderer:

```
nvrun --csp %command%
```

`--csp` adds `dwrite=n,b`, CSP's loader DLL. If the setup repo's protonfix
already sets it, the duplicate is harmless.

**What DLSS 5 is, and why AC is "unofficial".** DLSS 5 (launched September
2026) is *3D-guided neural rendering*: a model that re-lights and re-materials
the frame, one frame in, one frame out, guided by the engine's depth and motion
vectors. It is not an upscaler or frame generator. Officially it runs on RTX 50
only; NVIDIA says RTX 40 support is coming but has shipped no driver for it.
The runtime is `nvngx_dlssnr.dll`, which NVIDIA has not released in any SDK or
Linux driver — every community route uses a **leaked** build, and the one
that runs on Ada is a **patched, unsigned** build (the "ShortFuse"
cross-generation `310.8.SF-v2`) with the hardware check removed and FP8 ops
remapped. That is why none of it is automated in these dotfiles: the wrapper
sets the environment, the binary is your call to fetch. Expect ~40% of the
frame rate gone on RTX 40 and no NVIDIA support.

AC adds a second problem: it is DX11 with no DLSS integration, so the model
has no depth or motion vectors to be guided by. The only working route today is
the ReShade "feeder": a ReShade add-on reads ReShade's depth buffer, estimates
motion vectors with a shader (hardware optical flow does not initialise under
Proton), synthesises a DLAA input, and runs the neural pass on that. Verified
by its author on an **RTX 4080, driver 610.57, GE-Proton 11-3** on other DX11
titles without DLSS. Text softens and trackside foliage smears; it is a
demo of the model, not a graphics upgrade for racing. The procedure:

1. Needs `7zip` and `unzip` on the host (both installed today; not in the package lists on purpose).
2. Clone `24high/DLSS5-Reshade-Linux-Steam` into a scratch directory and run
   its installer against **`acs.exe`**, the binary that renders — not the
   launcher, whichever one is sitting at `AssettoCorsa.exe`:

   ```
   ./dlss5-install.sh --model rtx40 --mode nr \
     ~/.local/share/Steam/steamapps/common/assettocorsa/acs.exe
   ```

   It drops ReShade's `dxgi.dll`, the bridge/forwarder add-ons, a real
   `d3dcompiler_47.dll` (Wine's lacks `[fastopt]`) and a fake `DriverStore`
   with the NGX core files into the prefix. **The fake DriverStore must be
   redone after every driver update.** `--mode dlaa` is the fallback if `nr`
   dies on the `E5017 … fastopt` shader error.
3. Launch options: `nvrun --csp --nr %command%` (`--nr` forces NVAPI and loads
   the game-folder `dxgi.dll`; without `dxgi=n,b` ReShade never runs). CSP's
   `dwrite.dll` and ReShade's `dxgi.dll` are different hooks and coexist, as
   they do on Windows.
4. In the session: Home → ReShade → enable `vort_MotionEffects`. Then
   `./check-dlss5.sh …/acs.exe` reads the log and reports dispatch counts and
   which `nvngx_dlssnr` hash loaded.
5. `--nr` and `--smooth` can be combined (Smooth Motion is a present-time
   layer); `--nr` and native DLSS FG cannot exist here because AC has neither.

Two things make this moot in a better way: CSP **0.3.0 preview** (Patreon
only) adds real DLSS Super Resolution inside AC, and the `ac-dlssg` mod adds
DLSS FG on top of it — a genuine integration with real motion vectors, which
is also what a future NR model would want. Neither is verified under Proton.
And when NVIDIA ships Ada support, the driver itself will carry
`nvngx_dlssnr.dll`; the same community tooling prefers the driver copy over the
leak, so the experiment above becomes `--model auto`.

## Streaming to the TV

**The ultrawide makes naive desktop capture the wrong approach.** Capturing a
5120x1440 output and sending it to a 16:9 TV letterboxes into a thin horizontal
strip with most of the panel wasted. The fix is the **16:9 dummy plug on DP-2**
(a UGREEN EDID dongle, pinned to 2560x1440@60 in `config.kdl`): streams capture
that output, and the prep hook turns the desk panel off for the duration — see
the sections below.

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
- **Turns the desk monitor (DP-1) off** for the duration of the stream, so the
  dummy plug (DP-2) is the only output: Sunshine's monitor pick (index 0 in the
  wlgrab list) and Steam's window placement then have exactly one possible
  answer. It turns DP-2 on first, since `dummy-output.service` keeps it off
  while the desk is connected. Only done when DP-2 is actually present — with the dummy unplugged,
  turning DP-1 off would leave the session with zero outputs. The
  `$XDG_RUNTIME_DIR/sunshine-stream-prep.desk-off` marker records that the hook
  (not the user) turned it off, so `off` only re-enables what `on` disabled.
  Overridable via `SUNSHINE_STREAM_OUTPUT` / `SUNSHINE_DESK_OUTPUT`.

It always exits 0. Prep commands run without a shell, so there is no `|| true`
to lean on and a non-zero exit aborts the stream before it starts. Under
`gamescope-session` neither `dms` nor `niri` is running and both steps no-op.

`sunshine.conf` is rewritten wholesale by the web UI, so it is tracked as
`dot_config/sunshine/modify_sunshine.conf`: it re-asserts the one
`global_prep_cmd` line and passes every other key through untouched.

### 32:9 desk, 16:9 TV: the dummy plug

The answer to "capture a 32:9 output for a 16:9 TV" is **don't** — capture the
16:9 dummy plug on DP-2 instead. `config.kdl` pins it to 2560x1440@60 (its
EDID prefers 3840x2160@60 with 16:10 modes right behind it, so an explicit
mode matters), the prep hook turns DP-1 off during streams, and the BPM
window rule opens Big Picture on DP-2. 1440p60 is deliberate: the TV is 4K60
with no VRR on a 100 Mbit port, so 4K capture would only buy per-frame
downscaling in the encoder.

**DP-2 is only on when something needs it.** With both outputs live, a
fullscreen sim or a Proton title can open on the dummy, i.e. on a screen
nobody can see. `dummy-output.service` (`dot_config/niri/scripts/dummy-output.sh`,
pulled in by `niri.service` via `Wants=`, wired by
`run_onchange_after_54-dummy-output.sh.tmpl`) applies one rule: desk monitor
connected → DP-2 off; desk monitor absent (powered off, headless) → DP-2 on;
stream running (the prep hook's marker exists) → DP-2 on. It re-checks on
every DRM hotplug and every niri config reload, because `niri msg output`
changes are temporary and niri drops them when that output's config block
changes. `stream-prep.sh on` turns DP-2 on before DP-1 off; `off` hands DP-2
back to the rule. The config still lists DP-2 as enabled, so niri never
starts with zero outputs before the watcher runs. One side effect: if the
Odyssey also drops off the bus in DPMS standby, idle-off moves the desk
workspaces onto DP-2 until the monitor wakes, and niri moves them back.

An earlier iteration instead switched DP-1 itself to a 16:9 mode for the
stream. **That breaks every XWayland game**: niri changes the Wayland output
mode, but `xwayland-satellite` does not propagate it to the X screen —
`xrandr` keeps reporting `Screen 0: current 5120 x 1440` while `niri msg
outputs` says 2560x1440, so a Proton title renders 5120 wide into an output
displaying 2560 of it and exactly half the game is visible (measured on Spec
Ops: The Line). The dummy plug is a permanently-16:9 output: nothing switches,
so nothing desynchronises. The mode-switch code was removed from
`stream-prep.sh` when the plug went in (git history has it).

The `gamescope-session` route sidesteps the question differently: gamescope
drives the output itself and the game never sees the ultrawide. A user-unit
drop-in (`gamescope-session.service.d/override.conf`) sets
`OUTPUT_CONNECTOR=DP-2` so it deterministically grabs the dummy — the
launcher's default is `*,eDP-1`, i.e. first-enumerated connector on this box.
Note that `gamescope-session-cachyos`'s launcher
(`/usr/lib/steamos/gamescope-session`) exposes no `-W`/`-H` knob — it takes
the output's preferred mode, so on the dummy it runs 3840x2160@60.

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

That plug is now installed: a UGREEN 4K EDID dongle on **DP-2**, with its own
`output` block in `config.kdl` (2560x1440@60 — its EDID advertises no serial,
so the connector name is the match). It makes the connector permanently
present *and* removes the aspect-ratio problem at the source, which is what
retired the mode-switch half of `stream-prep.sh`. Sunshine needs no
`output_name`: the prep hook turns DP-1 off before capture starts, so the
dummy is monitor 0 by elimination.

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

`~/.ssh/config` on the *other* machines gets a `Host <devHost>` entry with
`ForwardAgent yes`. Agent forwarding rather than a key on the desktop, because
its 1Password agent socket needs an unlocked GUI that an SSH session doesn't
have.

## CPU note

The 7900X3D is dual-CCD, with V-Cache on CCD0 only, so the
CCD-preference problem written up for the 9950X3D applies in full. Two pieces,
both installed by the setup script from `system/gaming/`:

- `scx_loader.toml` — `scx_lavd` in `Gaming` mode. `scx_loader` alone starts
  nothing; without this file it waits on D-Bus and the kernel stays on the
  stock scheduler. Verify with `scxctl get`.
- `70-amd-x3d-cache.rules` — writes `cache` to the `amd_x3d_vcache` driver's
  `amd_x3d_mode` on bind. The kernel default is `frequency`, which makes
  amd-pstate's preferred-core ranking favour the non-V-Cache CCD; `cache`
  flips it so game threads land on the 96 MB L3. Verify with
  `cat /sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode`.

Both are performance (latency, frame pacing) measures, not stability ones, and
both revert live: `scxctl stop` and `echo frequency` into the same sysfs file.
