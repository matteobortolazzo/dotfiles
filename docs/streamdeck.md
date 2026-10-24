# Stream Deck as the headless desktop's only screen — proposal

> **Status: decided, not yet implemented.** See [Decisions](#decisions-2026-10-24) at the end.
> The hardware itself is verified on the desktop (2026-10-24, headless boot):
> see [Hardware check](#hardware-check).

The original 15-key Stream Deck plugs **directly into the desktop**. That box
boots headless (`docs/headless.md`): no greetd, no compositor, no monitor
driven. The deck becomes its screen — fifteen 72 px tiles showing load,
memory, GPU, UPS, what owns vt1, which coding agents are running and which one
is waiting — and its only physical buttons: `desktop up niri`, `desktop up
gamescope`, `desktop down`, and a hold-to-confirm power key, for a machine
whose power button is otherwise the only thing you can press.

Nothing crosses the network. The daemon reads `/proc`, `nvidia-smi`, `upsc`,
`systemctl` and cenci's local socket on the same box, and it runs from
`multi-user.target`, so it is up on a headless boot before anyone logs in and
keeps running underneath a niri or gamescope session when one is started.

## What is in the way today

Three things, all small, all on this box.

1. **`desktop` needs an interactive `sudo`.** `dot_local/bin/executable_desktop`
   runs `sudo systemctl start greetd-autologin@…`. The deck daemon is a
   service, not a terminal: no password prompt is possible. Fix: a polkit
   rule scoped to those units, and `desktop` stops needing `sudo` (also over
   SSH, which it was written for).
2. **`uaccess` does nothing on a headless box.** systemd's hwdb already tags
   the deck (`ID_AV_PRODUCTION_CONTROLLER=1` → `TAGS=:uaccess:seat:`), which
   grants it to the *active seat's* user via an ACL. On a `multi-user.target`
   boot there is no seat session, so nobody gets the ACL: `/dev/hidraw4` is
   `root 0600`, the USB node `root 0664`, and opening fails with
   `TransportError: Could not open HID device`. The rule has to set `OWNER=`
   (or a group) explicitly instead.
3. **No user session to host a user service.** A `systemctl --user` unit
   would need `loginctl enable-linger`. Simpler and more honest: a **system**
   unit with `User=<you>`, `WantedBy=multi-user.target`, bound to the device
   unit so it starts when the deck is present and stops if it is unplugged.

Everything else exists: `desktop status` knows what owns vt1, `upsc exa` has
the UPS, `nvidia-smi` works headless because the driver stays loaded
(deliberate, see `docs/headless.md`), Sunshine's prep hook leaves a state file
while a stream is live, and cenci broadcasts agent state on a local socket.

## cenci: what the deck reads, and how

cenci-watch's daemon lives on the tmux server, which on this box is the thing
you attach to over SSH. It broadcasts the full state as **newline-delimited
JSON over a Unix socket** (`~/.local/state/cenci/run/cenci.sock`): connect,
keep the connection, and a new snapshot line arrives on every change. cenci's
own `pkg/watch` is a Go client for that stream, but the protocol is plain
enough that the Python daemon reads it directly — no `widget-json` polling,
no `jq`, push-driven like the tmux frontend itself.

Each snapshot carries `windows[]` (session, window index, `window_name` like
`42-implement`, `task_name`, `agent`, `status`), a `summary` of counts,
`headroom` per agent (budget left, 0–1) and `dispatch` (fleet loop on/off,
last pass). Status precedence for colour follows cenci's own rule: `failed` >
`escalated` > `need_input` > `running` > `done` > `stopped` > `idle`. If the
socket is absent the row reads "no daemon"; the daemon reconnects with
backoff because cenci's daemon is spawned on demand by the first hook and
can come and go.

The socket directory is hardened to the owning user (mode 0700, foreign-owned
dirs rejected). Running the deck daemon **as you**, not root, is what makes
this just work.

## Layout (3 rows × 5 keys)

```
┌─────────┬─────────┬─────────┬─────────┬─────────┐
│ CPU     │ RAM     │ GPU     │ UPS     │ NET     │  row 1: stats
│ 23%     │ 11/64G  │ 4% 41°  │ OL 100% │ ts ✓    │
│ ld 1.2  │ 48°     │ 12 W    │ 38 min  │ ssh 1   │
├─────────┼─────────┼─────────┼─────────┼─────────┤
│ AGENTS  │ #42     │ #78     │ #91     │ ⟳ 5m    │  row 2: cenci
│ ▶2 !1   │ impl    │ refine  │ impl    │ 2/0     │  colour = status
│ cl 62%  │ ! input │ ▶ run   │ ✓ done  │ 14:05   │
├─────────┼─────────┼─────────┼─────────┼─────────┤
│ NIRI    │ GAME    │ GREETER │ DOWN    │ ⏻       │  row 3: actions
│ ● on    │ ○       │ ○       │         │ hold    │  active one lit
└─────────┴─────────┴─────────┴─────────┴─────────┘
```

**Row 1 — stats, every 2 s.**
- `CPU`: utilisation from `/proc/stat`, 1-min load, package temp from
  `k10temp` via `/sys/class/hwmon` (no `lm_sensors`).
- `RAM`: used/total from `/proc/meminfo`.
- `GPU`: util, temp, power draw from `nvidia-smi --query-gpu=…,--format=csv`.
  The "~12 W idle" figure from `headless.md`, live, and the first thing to
  look at when a session was left running on vt1.
- `UPS`: `ups.status`, `battery.charge`, `battery.runtime` from `upsc exa`.
  Red on `OB`; see the takeover below.
- `NET`: Tailscale online, established SSH session count
  (`ss -tn state established '( sport = :22 )'`), running docker containers,
  root disk free. Which of these shows on the tile cycles on press.

**Row 2 — agents, push-driven.** Aggregate tile (counts + lowest headroom);
three session tiles sorted need-input → failed → running → done → idle, each
with the ticket number or slug, the skill, the status glyph and colour; the
last tile is the fleet **dispatch loop**: `⟳` + interval when enabled, `⚙`
while a pass runs, last `dispatched/skipped` and time, blank when off. More
than three sessions → the third tile becomes `+N` and switches to an agents
page that lists them five per row.

Since there is no screen to jump to, a press on a session tile opens a detail
page (full task name, agent, session:window, how long in this state) rather
than a terminal. A **hold** on a `done` session runs `cenci close <ticket>`
to reap its window; a hold on the dispatch tile toggles
`cenci dispatch loop on|off`. Nothing on a tap mutates agent state.

**Row 3 — actions.**
- `NIRI` / `GAME` / `GREETER` → `desktop up niri`, `desktop up gamescope`,
  `desktop greeter`. The unit that owns vt1 is drawn gold (from the same list
  `desktop status` prints). `GAME` shows a streaming badge while
  `/run/user/<uid>/sunshine-stream-prep.desk-off` exists.
- `DOWN` → `desktop down`.
- `⏻` → hold 1.5 s for a confirm page: **reboot** / **power off** / cancel.
  The library reports key down/up, so the daemon times the hold; nothing
  destructive is a single tap. On a box with no monitor this is the one
  physical control that is otherwise missing.

**UPS takeover.** On `OB` the whole deck switches to a page: charge, runtime,
load, and a countdown of the **five-minute `upssched` timer** that is the real
shutdown policy (`docs/ups.md`): the daemon stamps when `OB` first appeared
and counts down from 300 s. Keys: back to normal view; hold-to-shutdown now.
On `OL` it returns to the previous page. Power to the deck comes from the
same UPS-backed PSU, so it stays lit until killpower.

**Lifecycle on the deck.** `ExecStartPre` paints a "headless · booting" tile
set before the first poll; `ExecStop` paints "shutting down" so the last
thing visible during a `desktop down`/reboot is intentional rather than a
frozen frame. Brightness: full for a minute after a press, then 15 %;
the deck is in a room, not a pocket, so it never blanks fully — a dim
glanceable panel is the point.

Colours are the Glassmorphic Dark tokens from `.claude/CLAUDE.md`: `bg-solid`
tiles, `text-primary` labels, `accent` gold for the active session/unit,
`urgent` for need-input and on-battery, `success` for done/online, `warning`
for low headroom (< 25 %, cenci's own threshold). Inter for labels, JetBrains
Mono Nerd Font for glyphs — both in `arch-desktop.txt`, which the desktop has.

## Architecture

```
desktop, headless boot (multi-user.target)
┌────────────────────────────────────────────────────────────────┐
│ streamdeck.service  (system unit, User=<you>, BindsTo=device)   │
│   deckd.py                                                     │
│   ├─ poll 2 s: /proc, hwmon, nvidia-smi, upsc, systemctl,      │
│   │            ss, docker, tailscale, sunshine state file      │
│   ├─ push:     cenci.sock  (NDJSON stream, reconnect+backoff)  │
│   ├─ render:   Pillow → 15 × 72 px tiles                       │
│   └─ press:    desktop up|down|greeter · systemctl reboot/off  │
│                cenci close / dispatch loop (hold only)         │
│ polkit: <you> may manage greetd*, power-off, reboot            │
│ udev:   0fd9 → OWNER=<you>, SYSTEMD_WANTS=streamdeck.service   │
└────────────────────────────────────────────────────────────────┘
          niri / gamescope session on vt1 may or may not exist;
          the deck does not care and is not part of it.
```

**Why a custom daemon.** The deciding feature is tiles created from data (one
key per agent session, a UPS takeover page). Compared:

| | Tiles from data | Colour by state | Config in chezmoi | Runs with no GUI session | Notes |
|---|---|---|---|---|---|
| **Custom daemon** (`python-elgato-streamdeck` + Pillow) | ✓ | ✓ | ✓ | ✓ | ~400 lines; we own rendering and press logic |
| **deckmaster** (Go, TOML) | ✗ static key map | ✗ | ✓ | ✓ | `command` widget on an interval; zero code, text only |
| **StreamController** (GTK4) | ✗ | plugin-dependent | ✗ | ✗ needs a desktop | best GUI, wrong shape for a headless box |
| **OpenDeck** (Tauri) | ✗ | plugin-dependent | ✗ | ✗ | Elgato-SDK plugins, Windows-app oriented |

Python for the first cut: config and code live together in this repo, no
build step on `chezmoi apply`, and `stream-prep.sh` already leans on
`python3` on this box. If it grows, a Go rewrite would use cenci's `pkg/watch`
for the stream and `muesli/streamdeck` (deckmaster's device layer) for the
hardware, and could be offered back to cenci as a `watch/plugin/streamdeck`
surface — the UPS/`desktop`/GPU tiles stay here either way.

**Device access.** USB HID, vendor `0fd9`; this deck is product `006d`, the
Original V2 (`lsusb`: "Stream Deck original V2", 72×72 JPEG keys). The
`streamdeck` package (0.10.0) has no Python dependencies: it loads
`libhidapi-libusb.so` through ctypes, which on Arch is the `hidapi` package
(0.15.0, already installed). Because the libusb backend opens the raw USB
device, the rule must cover `usb` as well as `hidraw`. The `usb` line is
limited to the device node (`DEVTYPE=usb_device`), not its interfaces, so the
symlink and the systemd tag land on one device unit:

```udev
# system/udev/70-streamdeck.rules — OWNER, not uaccess: no seat on a headless boot
SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0fd9", \
  OWNER="<you>", MODE="0600", SYMLINK+="streamdeck", \
  TAG+="systemd", ENV{SYSTEMD_WANTS}="streamdeck.service"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", OWNER="<you>", MODE="0600"
```

The username is rendered by the install script from `.chezmoi.username`,
never hardcoded in the tracked rule.

**Service.** A system unit mirrored from `system/streamdeck/` the same way
`nut-killpower.service` is, with:

```ini
[Unit]
Description=Stream Deck status panel for a headless box
After=multi-user.target nut-monitor.service docker.service
BindsTo=dev-streamdeck.device          # SYMLINK+="streamdeck" in the udev rule
After=dev-streamdeck.device

[Service]
User=<you>
ExecStartPre=%h/.local/share/streamdeck/venv/bin/python %h/.config/streamdeck/deckd.py splash booting
ExecStart=%h/.local/share/streamdeck/venv/bin/python %h/.config/streamdeck/deckd.py
ExecStop=%h/.local/share/streamdeck/venv/bin/python %h/.config/streamdeck/deckd.py splash shutdown
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

`%h` resolves to that user's home under `User=`. `BindsTo=` the device unit
plus `SYSTEMD_WANTS=` on the rule is what gives start-on-plug and
stop-on-unplug without any polling; on a box where the deck is permanently
attached it simply starts at boot.

**polkit rule.** `system/polkit/49-desktop-units.rules`, installed by
`run_once_after_49-headless-boot.sh.tmpl` next to the autologin units, since
it exists to make `desktop` callable from anything that is not a seat
session (the deck daemon today, your SSH shell already):

```js
polkit.addRule(function (action, subject) {
  if (subject.user !== "<you>") return polkit.Result.NOT_HANDLED;
  if (action.id === "org.freedesktop.systemd1.manage-units") {
    var u = action.lookup("unit") || "";
    if (u === "greetd.service" || u.indexOf("greetd-autologin@") === 0)
      return polkit.Result.YES;
  }
  if (action.id === "org.freedesktop.login1.power-off" ||
      action.id === "org.freedesktop.login1.reboot")
    return polkit.Result.YES;
  return polkit.Result.NOT_HANDLED;
});
```

`desktop` then calls `systemctl` directly and falls back to `sudo` only if
polkit refuses, so it keeps working unchanged on a box without the rule.
Security delta: anyone with your SSH key already has a shell as you on this
box; this adds "start/stop the greeter and power off without a password",
which is what `desktop up` over SSH was built for. `getty@tty1` stops through
`Conflicts=`, so the rule never has to name it. The NUT killpower path runs
as root and is untouched.

## Files

| File | Purpose |
|---|---|
| `dot_config/streamdeck/deckd.py` | the daemon: device, renderer, pollers, cenci stream, press/hold handlers, pages |
| `dot_config/streamdeck/config.toml` | tile layout per page, poll interval, hold time, brightness, UPS name (`exa`) |
| `system/streamdeck/streamdeck.service` | system unit above, mirrored to `/etc/systemd/system/` |
| `system/udev/70-streamdeck.rules` | OWNER + `SYSTEMD_WANTS` + `SYMLINK+="streamdeck"` |
| `system/polkit/49-desktop-units.rules` | manage greetd units / power without a prompt (installed by `49-headless-boot`) |
| `run_once_after_52-streamdeck.sh.tmpl` | mirrors rule + unit with `sudo install`, renders `<you>`, creates `~/.local/share/streamdeck/venv` with `streamdeck pillow` (Arch's Python is PEP 668 externally-managed; the README's rule is toolchains install into `$HOME`), `udevadm trigger`, `systemctl enable --now` |
| `dot_local/bin/executable_desktop` | drop `sudo`, fall back to it |
| `docs/streamdeck.md` | this file, rewritten as the real doc once it lands |

Gate: a new **`deck`** data var, prompted like `ups` ("a Stream Deck is
plugged into this box"). Hardware fact, not a role — `ups` is the precedent
for that shape. Read with `dig "deck" false .`. Per the repo rule the script
suggests `pacman -S hidapi` and does not install it.

## Hardware check

Done on the desktop on a headless boot (`systemd.unit=multi-user.target`),
with `streamdeck` 0.10.0 + Pillow in a throwaway venv and a temporary
`setfacl -m u:<you>:rw` on the USB and hidraw nodes standing in for the udev
rule (the ACL is gone on replug or reboot):

- Enumerates as `StreamDeckOriginalV2`, 15 keys in a 3×5 layout, firmware
  `1.03.000`.
- `reset()`, `set_brightness()` and `set_key_image()` work; tiles rendered
  through `PILHelper` in the palette colours come out the right way up, key 0
  at top-left, numbered row by row.
- All 15 keys report a clean down/up pair, in order, with nothing dropped or
  doubled. A tap is ~0.1 s down-to-up, so timing a 1.5 s hold from the
  callback's events is reliable.
- Without the ACL, `open()` fails with `Could not open HID device` — the
  `uaccess` trap above, reproduced.

## Risks and caveats

- **The `uaccess` trap** above is the one that silently breaks every online
  recipe on this box: the daemon logs "could not open device" and nothing
  else is wrong. `OWNER=` is the fix; worth a comment in the rule.
- **`nvidia-smi` on a GPU that is idle** can take ~100 ms on the first call;
  time-box every probe so one slow tool cannot stall the tick.
- **Two things can start vt1 sessions now:** you over SSH and the deck. Both
  go through the same `Conflicts=` units, so the worst case is the same as
  today — a session started from the deck kills a TTY login left on the
  monitor nobody is looking at.
- **cenci daemon lifetime.** It is spawned on demand by the first agent hook
  and may not exist on a fresh boot; the row reads "no daemon" until the
  first `claude`/`codex` starts, which is correct, not an error.
- **15 keys.** Server page, agents page, UPS takeover, power confirm. That is
  the comfortable maximum; a docker/services page is possible but each page
  costs a key.

## Decisions (2026-10-24)

These supersede the proposal text above wherever the two disagree.

1. **Go, in this repo.** Source in `deckd/` at the repo root (its own Go
   module, listed in `.chezmoiignore` like `docs/` and `system/`). The install
   script builds it with `go build` into `~/.local/bin/deckd`; `go` is already
   in `arch-terminal.txt`. Python, the venv and `config.toml` are dropped:
   layout, poll interval, hold time and UPS name are constants or flags.
2. **New `deck` data var**, prompted like `ups` ("a Stream Deck is plugged
   into this box"), read with `dig "deck" false .`.
3. **Power keys: yes, long press.** Hold 1.5 s for the confirm page, as above.
4. **UPS takeover page: yes**, as above.
5. **`GAME` = `desktop up gamescope`.**
6. **Press on a session tile opens the detail page.**
7. **Laptop surface: out of scope.**

Consequences of choosing Go, also decided:

- **Device layer: pure Go on `/dev/hidraw`, no cgo, no hidapi.** The
  Original V2 protocol is small, ported from `python-elgato-streamdeck`'s
  `StreamDeckOriginalV2`: images are 1024-byte output reports (`02 07 key
  last len_lo len_hi page_lo page_hi` + 1016 bytes of a 72×72 JPEG, flipped
  on both axes); key states are input reports, 15 bytes from offset 4;
  `reset` is feature `03 02`, brightness feature `03 08 <percent>`, serial
  feature report `06`, firmware `05` (32 bytes each, via
  `HIDIOCSFEATURE`/`HIDIOCGFEATURE`). Reading hidraw instead of libusb also
  means the kernel's `usbhid` driver is never detached.
- **The udev rule is hidraw-only**, since nothing opens the USB node:

  ```udev
  # OWNER, not uaccess: no seat on a headless boot
  SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", \
    OWNER="<you>", MODE="0600", SYMLINK+="streamdeck", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}="streamdeck.service"
  ```
- **The unit uses absolute paths.** `%h` in a *system* unit is the service
  manager's home (`/root`), not `User=`'s, so the script renders the unit
  with the real home: `ExecStart=/home/<you>/.local/bin/deckd`,
  `ExecStartPre=… splash booting`, `ExecStop=… splash shutdown`.
- **Rendering:** `image/jpeg` plus `golang.org/x/image/font/opentype` with
  the system's JetBrains Mono Nerd Font (`/usr/share/fonts/TTF/`).
- **cenci:** the live snapshot on `cenci.sock` (checked 2026-10-24) has
  `windows[]` (`session`, `window_index`, `window_name`, `task_name`,
  `status`, `agent`), `summary` and `dispatch` (`enabled`, `daemon_running`,
  `pass_running`, `last_dispatched`, `last_skipped`) — **no `headroom`**. The
  aggregate tile shows counts only. Hold actions call
  `cenci close <window-name>` and `cenci dispatch loop on|off`.
- **Hidapi is not needed**, so the script has nothing to suggest installing
  beyond `go`.
