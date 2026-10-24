# Stream Deck as the headless desktop's only screen

> **Status: implemented.** `deckd` (Go, `deckd/`), its udev rule and system
> unit (`system/streamdeck/`, installed by `run_onchange_after_52-streamdeck.sh.tmpl`)
> and the polkit rule behind `desktop` (`system/polkit/`, installed by
> `run_once_after_49-headless-boot.sh.tmpl`). Gated on the `deck` data var.
> Hardware verified on the desktop on a headless boot: see
> [Hardware check](#hardware-check).

The original 15-key Stream Deck plugs **directly into the desktop**. That box
boots headless (`docs/headless.md`): no greetd, no compositor, no monitor
driven. The deck is its screen — fifteen 72 px tiles showing load, memory,
GPU, UPS, what owns vt1, which coding agents are running and which one is
waiting — and its only physical buttons: `desktop up niri`, `desktop up
gamescope`, `desktop greeter`, `desktop down`, and a hold-to-confirm power
key, for a machine whose power button is otherwise the only thing you can
press.

Nothing crosses the network. `deckd` reads `/proc`, `nvidia-smi`, `upsc`,
`systemctl` and cenci's local socket on the same box, and it runs from
`multi-user.target`, so it is up on a headless boot before anyone logs in and
keeps running underneath a niri or gamescope session when one is started.

## Enabling it on a machine

1. Set `deck = true`. Either re-run `chezmoi init` (it keeps every existing
   answer and only asks the new question), or add `deck = true` under `[data]`
   in `~/.config/chezmoi/chezmoi.toml` by hand.
2. `chezmoi apply`. `52-streamdeck` builds `deckd` into `~/.local/bin/deckd`,
   renders and installs the udev rule and the unit, re-triggers the deck's
   hidraw node, and starts `streamdeck.service` if the deck is
   attached.
3. **Only on a machine where `49-headless-boot` already ran:** it installs the
   polkit rule `desktop` needs to run without a password. The edit that added
   the rule changes the script, so the next `apply` runs it once more on its
   own; after any later edit to `system/polkit/49-desktop-units.rules.in`
   alone, re-run it by hand:

   ```bash
   chezmoi execute-template < "$(chezmoi source-path)/run_once_after_49-headless-boot.sh.tmpl" | bash
   ```

   Without the rule the deck still shows everything, but its `NIRI`/`GAME`/
   `GREETER`/`DOWN`/power keys fail: `desktop` falls back to `sudo`, which a
   service cannot answer.

`go` must be installed (`packages/arch-terminal.txt`); the script skips the
build with a hint if it is not and never installs it. Nothing else is needed —
no hidapi, no Python, no venv.

```bash
journalctl -u streamdeck -f          # what deckd is doing
systemctl status streamdeck          # running? bound to dev-streamdeck.device?
ls -l /dev/streamdeck                # -> hidrawN, owned by you, 0600
```

## What was in the way, and the fix for each

1. **`desktop` needed an interactive `sudo`.** The deck daemon is a service,
   not a terminal: no password prompt is possible. Fix: a polkit rule scoped to
   the greetd units and to reboot/power-off, and `desktop` calls
   `systemctl --no-ask-password` first, falling back to `sudo` only when
   polkit refuses — so it keeps working unchanged on a box without the rule,
   and stops prompting over SSH on a box with it.
2. **`uaccess` does nothing on a headless box.** systemd's hwdb already tags
   the deck (`ID_AV_PRODUCTION_CONTROLLER=1` → `TAGS=:uaccess:seat:`), which
   grants it to the *active seat's* user via an ACL. On a `multi-user.target`
   boot there is no seat session, so nobody gets the ACL: the hidraw node is
   `root 0600` and opening it fails. Fix: the udev rule sets `OWNER=`
   explicitly.
3. **No user session to host a user service.** A `systemctl --user` unit
   would need `loginctl enable-linger`. Fix: a **system** unit with
   `User=<you>`, started by the udev rule and bound to the device unit, so it
   starts when the deck is present (at boot or on plug-in) and stops if it is
   unplugged.

Everything else already existed: `desktop status` knows what owns vt1,
`upsc exa` has the UPS, `nvidia-smi` works headless because the driver stays
loaded (deliberate, see `docs/headless.md`), Sunshine's prep hook leaves a
state file while a stream is live, and cenci broadcasts agent state on a local
socket.

## Device access

USB HID, vendor `0fd9`, product `006d`: the Original V2 (`lsusb`: "Stream
Deck original V2", 72×72 JPEG keys). `deckd` drives it in **pure Go on
`/dev/hidraw`, no cgo, no hidapi**, with the protocol ported from
`python-elgato-streamdeck`'s `StreamDeckOriginalV2`:

- images are 1024-byte output reports: `02 07 key last len_lo len_hi page_lo
  page_hi` + 1016 bytes of a 72×72 JPEG, flipped on both axes;
- key states are input reports, 15 bytes from offset 4;
- `reset` is feature `03 02`, brightness feature `03 08 <percent>`, serial
  feature report `06`, firmware `05` (32 bytes each, via
  `HIDIOCSFEATURE`/`HIDIOCGFEATURE`).

Reading hidraw rather than libusb also means the kernel's `usbhid` driver is
never detached, and the raw USB node is never opened — so the udev rule only
needs to cover `hidraw`:

```udev
# system/streamdeck/70-streamdeck.rules.in -> /etc/udev/rules.d/70-streamdeck.rules
# OWNER, not uaccess: no seat on a headless boot
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", \
  OWNER="@USER@", MODE="0600", SYMLINK+="streamdeck", \
  TAG+="systemd", ENV{SYSTEMD_WANTS}="streamdeck.service"
```

`@USER@` is rendered by the install script from `id -un`, never hardcoded in
the tracked file. `SYMLINK+="streamdeck"` plus `TAG+="systemd"` is what makes
`dev-streamdeck.device` exist for the unit to bind to; `deckd` opens
`/dev/streamdeck` by default.

Rendering is `image/jpeg` plus `golang.org/x/image/font/opentype` with the
system's JetBrains Mono Nerd Font (`/usr/share/fonts/TTF/`).

## Service

`system/streamdeck/streamdeck.service.in` → `/etc/systemd/system/streamdeck.service`:

```ini
[Unit]
BindsTo=dev-streamdeck.device
After=dev-streamdeck.device
After=nut-monitor.service docker.service

[Service]
User=@USER@
Environment=PATH=@HOME@/.local/bin:/usr/local/bin:/usr/bin
ExecStartPre=-@HOME@/.local/bin/deckd splash booting
ExecStart=@HOME@/.local/bin/deckd
Restart=on-failure
```

- **Absolute paths, rendered.** `%h` in a *system* unit is the service
  manager's home (`/root`), not `User=`'s, so the script substitutes the real
  `$HOME` for `@HOME@`. `PATH` is set because `deckd` shells out to `desktop`
  and `cenci`, both in `~/.local/bin`.
- **`BindsTo=` the device unit** plus `SYSTEMD_WANTS=` on the rule gives
  start-on-plug and stop-on-unplug without any polling. There is no
  `[Install]`: udev's coldplug at boot fires `SYSTEMD_WANTS` for a deck that
  is already attached, so a permanently attached deck starts at boot anyway,
  and a boot without the deck logs nothing.
- **Ordering after NUT and docker, without `Wants=`**: the UPS and docker
  tiles read them, so the first poll shows real values.
- **Splashes.** `ExecStartPre` paints "booting" before the first poll;
  `deckd` paints "shutting down" itself on `SIGTERM`, so the last frame
  during `desktop down`, a reboot or a power-off is intentional rather than
  frozen. Not an `ExecStop=`: that runs while `deckd` still holds the device.
  `ExecStartPre` is `-`-prefixed: a failed splash must not fail the unit.
- **Runs as you**, not root. That is what makes cenci's socket just work (see
  below), and it is all the access the panel needs: the device node is yours,
  and everything privileged goes through polkit.

## polkit: `desktop` and power without a password

`system/polkit/49-desktop-units.rules.in` →
`/etc/polkit-1/rules.d/49-desktop-units.rules`, installed by
`run_once_after_49-headless-boot.sh.tmpl` next to the autologin units, since it
exists to make `desktop` callable from anything that is not a seat session
(the deck daemon, and your SSH shell):

```js
polkit.addRule(function (action, subject) {
  if (subject.user !== "@USER@") return polkit.Result.NOT_HANDLED;
  if (action.id === "org.freedesktop.systemd1.manage-units") {
    var unit = action.lookup("unit") || "";
    if (unit === "greetd.service" || unit.indexOf("greetd-autologin@") === 0)
      return polkit.Result.YES;
  }
  switch (action.id) {
    case "org.freedesktop.login1.power-off":
    case "org.freedesktop.login1.power-off-multiple-sessions":
    case "org.freedesktop.login1.reboot":
    case "org.freedesktop.login1.reboot-multiple-sessions":
      return polkit.Result.YES;
  }
  return polkit.Result.NOT_HANDLED;
});
```

The `-multiple-sessions` variants are needed because an SSH login or a running
niri session counts as "another session"; `-ignore-inhibit` is deliberately
left out, so an inhibitor lock still wins. `getty@tty1` stops through the
greetd units' `Conflicts=`, so the rule never has to name it.

Security delta: anyone with your SSH key already has a shell as you on this
box; this adds "start/stop the greeter and reboot/power off without a
password", which is what `desktop up` over SSH was built for. The NUT
killpower path runs as root and is untouched.

## cenci: what the deck reads, and how

cenci-watch's daemon lives on the tmux server, which on this box is the thing
you attach to over SSH. It broadcasts the full state as **newline-delimited
JSON over a Unix socket** (`~/.local/state/cenci/run/cenci.sock`): connect,
keep the connection, and a new snapshot line arrives on every change. `deckd`
reads that stream directly — no `widget-json` polling, no `jq`, push-driven
like the tmux frontend itself.

Each snapshot (checked 2026-10-24) carries `windows[]` (`session`,
`window_index`, `window_name` like `42-implement`, `task_name`, `status`,
`agent`), a `summary` of counts, and `dispatch` (`enabled`, `daemon_running`,
`pass_running`, `last_dispatched`, `last_skipped`). There is **no
`headroom`**, so the aggregate tile shows counts only. Status precedence for
colour follows cenci's own rule: `failed` > `escalated` > `need_input` >
`running` > `done` > `stopped` > `idle`. If the socket is absent the row reads
"no daemon"; `deckd` reconnects with backoff because cenci's daemon is spawned
on demand by the first hook and can come and go.

The socket directory is hardened to the owning user (mode 0700, foreign-owned
dirs rejected). Running `deckd` **as you**, not root, is what makes this work.

## Layout (3 rows × 5 keys)

```
┌─────────┬─────────┬─────────┬─────────┬─────────┐
│ CPU     │ RAM     │ GPU     │ UPS     │ NET     │  row 1: stats
│ 23%     │ 11/64G  │ 4% 41°  │ OL 100% │ ts ✓    │
│ ld 1.2  │ 48°     │ 12 W    │ 38 min  │ ssh 1   │
├─────────┼─────────┼─────────┼─────────┼─────────┤
│ ▶ 3     │ ! 1     │ ✗ 0     │ ✓ 2     │ ~ 1     │  row 2: cenci
│ RUNNING │ INPUT   │ FAILED  │ DONE    │ IDLE    │  count per state
│         │         │         │         │         │  tinted when > 0
├─────────┼─────────┼─────────┼─────────┼─────────┤
│ NIRI    │ GAME    │ GREETER │ DOWN    │ ⏻       │  row 3: actions
│ ● on    │ hold    │ hold    │ hold    │ hold    │  all hold-only
└─────────┴─────────┴─────────┴─────────┴─────────┘
```

The layout, poll interval, hold time and UPS name are constants or flags in
`deckd/` — there is no config file. The code there is authoritative for the
details below.

**Row 1 — stats, every 2 s.**
- `CPU`: utilisation from `/proc/stat`, 1-min load, package temp from
  `k10temp` via `/sys/class/hwmon` (no `lm_sensors`).
- `RAM`: used/total from `/proc/meminfo`.
- `GPU`: util, temp, power draw from `nvidia-smi --query-gpu=…,--format=csv`.
  The "~12 W idle" figure from `headless.md`, live, and the first thing to
  look at when a session was left running on vt1.
- `UPS`: `ups.status`, `battery.charge`, `battery.runtime` from `upsc exa`.
  Red on `OB`; see the takeover below.
- `NET`: active/total GitHub Actions runner units
  (`systemctl list-units --all 'actions.runner.*'`), established SSH session count
  (`ss -tn state established '( sport = :22 )'`), running docker containers,
  root disk free. Which of these shows on the tile cycles on press.

**Row 2 — agents, push-driven.** One count per state, from the snapshot's
`summary`: `RUNNING`, `INPUT` (`need_input` + `escalated`), `FAILED`, `DONE`,
`IDLE` (`idle` + `stopped`). Each carries cenci-watch's tmux symbol and colour
(`watch/internal/config/config.go`), so the deck reads like the status line:
`▶` blue, `!` red, `✗` red, `✓` green, `~` dim grey. A count above zero tints
its key; zero stays dark. Per-session tiles were tried first and
were too condensed to read at 72 px.

A tap on any count opens the **agents page**, which lists the sessions five
per row; a press on one there opens its **detail page** (full task name,
agent, session:window, how long in this state), and a **hold** on a `done`
session runs `cenci close <window-name>` to reap its window. Nothing on a tap
mutates agent state.

**Row 3 — actions.**
- `NIRI` / `GAME` / `GREETER` → `desktop up niri`, `desktop up gamescope`,
  `desktop greeter`. The unit that owns vt1 is drawn gold (from the same list
  `desktop status` prints). `GAME` shows a streaming badge while
  `/run/user/<uid>/sunshine-stream-prep.desk-off` exists.
- `DOWN` → `desktop down`.
- All four are **hold 1.5 s**, not tap: each one ends whatever owns vt1, so a
  stray brush of the deck must not kill a game or a niri session. The hold
  fires while the key is still down, and the key shows `…` for 5 s after.
- `⏻` → **hold 1.5 s** for a confirm page: **reboot** / **power off** /
  cancel (`systemctl reboot|poweroff`, allowed by the polkit rule). `deckd`
  times the hold from key down/up; nothing destructive is a single tap. On a
  box with no monitor this is the one physical control that is otherwise
  missing.

**UPS takeover.** On `OB` the whole deck switches to a page: charge, runtime,
load, and a countdown of the **five-minute `upssched` timer** that is the real
shutdown policy (`docs/ups.md`): `deckd` stamps when `OB` first appeared and
counts down from 300 s. Keys: back to normal view; hold-to-shutdown now. On
`OL` it returns to the previous page. Power to the deck comes from the same
UPS-backed PSU, so it stays lit until killpower.

**Brightness:** always 100 %, the hardware maximum. The V2's LCD is dim even
at full, so idle dimming was dropped (15 % read as off, 50 % as murky).
Perceived brightness comes mostly from the tiles themselves: keys are filled
with their state colour at nearly full strength, not a dark shade of it.

Colours are the Glassmorphic Dark tokens from `.claude/CLAUDE.md`, used as
**tile backgrounds**, not just text: grey-on-`bg-solid` was unreadable on the
deck's panel. Each key is filled with its state colour (78 % over `bg-solid`), white text
and a light-tint label: `success`/`warning`/`urgent` by load for CPU, RAM and GPU
(plus a gauge bar along the bottom, also for UPS charge), the status colour for
each agent session, `info`/magenta/cyan for NIRI/GAME/GREETER, `urgent` for
power, and a solid `accent` gold key with dark text and a white border for
whatever owns vt1 (text colour flips by the fill's lightness). Text is drawn large and shrinks to fit rather than truncating.

## Architecture

```
desktop, headless boot (multi-user.target)
┌────────────────────────────────────────────────────────────────┐
│ streamdeck.service  (system unit, User=<you>, BindsTo=device)   │
│   ~/.local/bin/deckd  (Go, built from deckd/ by 52-streamdeck) │
│   ├─ poll 2 s: /proc, hwmon, nvidia-smi, upsc, systemctl,      │
│   │            ss, docker, sunshine state file                 │
│   ├─ push:     cenci.sock  (NDJSON stream, reconnect+backoff)  │
│   ├─ render:   image/jpeg + opentype → 15 × 72 px tiles        │
│   ├─ device:   /dev/streamdeck → hidraw, pure Go               │
│   └─ press:    desktop up|down|greeter · systemctl reboot/off  │
│                cenci close (hold only, agents page)            │
│ polkit: <you> may manage greetd*, power-off, reboot            │
│ udev:   0fd9:006d hidraw → OWNER=<you>, SYSTEMD_WANTS=…        │
└────────────────────────────────────────────────────────────────┘
          niri / gamescope session on vt1 may or may not exist;
          the deck does not care and is not part of it.
```

**Why a custom daemon.** The deciding feature is tiles created from data (one
key per agent session, a UPS takeover page). Compared:

| | Tiles from data | Colour by state | Config in chezmoi | Runs with no GUI session | Notes |
|---|---|---|---|---|---|
| **Custom daemon** (`deckd`, Go) | ✓ | ✓ | ✓ | ✓ | we own rendering and press logic |
| **deckmaster** (Go, TOML) | ✗ static key map | ✗ | ✓ | ✓ | `command` widget on an interval; zero code, text only |
| **StreamController** (GTK4) | ✗ | plugin-dependent | ✗ | ✗ needs a desktop | best GUI, wrong shape for a headless box |
| **OpenDeck** (Tauri) | ✗ | plugin-dependent | ✗ | ✗ | Elgato-SDK plugins, Windows-app oriented |

**Why Go, in this repo.** The source lives next to the unit and rule that run
it (`deckd/`, its own module, in `.chezmoiignore` like `docs/` and `system/`),
`go` is already in `arch-terminal.txt`, and a static binary with no cgo has
nothing to break on a Python or hidapi upgrade. The hardware check below was
done with Python, which is where the protocol was ported from.

## Files

| File | Purpose |
|---|---|
| `deckd/` | the daemon: device, renderer, pollers, cenci stream, press/hold handlers, pages |
| `system/streamdeck/70-streamdeck.rules.in` | OWNER + `SYMLINK+="streamdeck"` + `SYSTEMD_WANTS`, hidraw only |
| `system/streamdeck/streamdeck.service.in` | the system unit above |
| `system/polkit/49-desktop-units.rules.in` | greetd units + reboot/power-off without a prompt |
| `run_onchange_after_52-streamdeck.sh.tmpl` | builds `deckd`, renders `@USER@`/`@HOME@`, installs rule + unit, re-triggers the deck, starts the unit |
| `run_once_after_49-headless-boot.sh.tmpl` | also renders and installs the polkit rule |
| `dot_local/bin/executable_desktop` | `systemctl --no-ask-password` first, `sudo` as fallback |

`52-streamdeck` is `run_onchange`, like `51-ups`: it embeds a `sha256sum` of
both `.in` files and of every `deckd/**/*.go`, `go.mod` and `go.sum`, so an
edit to any of them re-runs it on the next apply. The build is reproducible
(`-trimpath`), every install is `cmp`-guarded, and the service is restarted
only when the binary, rule or unit actually changed. If the deck is not
attached, nothing is started; plugging it in starts it.

## Hardware check

Done on the desktop on a headless boot (`systemd.unit=multi-user.target`),
with the Python `streamdeck` 0.10.0 + Pillow in a throwaway venv and a
temporary `setfacl -m u:<you>:rw` on the USB and hidraw nodes standing in for
the udev rule (the ACL is gone on replug or reboot):

- Enumerates as `StreamDeckOriginalV2`, 15 keys in a 3×5 layout, firmware
  `1.03.000`.
- `reset()`, `set_brightness()` and `set_key_image()` work; tiles rendered in
  the palette colours come out the right way up, key 0 at top-left, numbered
  row by row.
- All 15 keys report a clean down/up pair, in order, with nothing dropped or
  doubled. A tap is ~0.1 s down-to-up, so timing a 1.5 s hold from key events
  is reliable.
- Without the ACL, `open()` fails with `Could not open HID device` — the
  `uaccess` trap above, reproduced.

## Risks and caveats

- **The `uaccess` trap** is the one that silently breaks every online recipe
  on this box: the daemon logs "could not open device" and nothing else is
  wrong. `OWNER=` is the fix, commented in the rule.
- **`OWNER=` a regular user is deprecated in udev.** `udevadm verify` warns
  that device-node ownership by non-system accounts "is deprecated and will be
  removed in the future". It works today. If a systemd release drops it, the
  migration is a system group: `GROUP="streamdeck", MODE="0660"` in the rule,
  the group created by a `sysusers.d` drop-in, and `SupplementaryGroups=streamdeck`
  in the unit.
- **`nvidia-smi` on an idle GPU** can take ~100 ms on the first call; every
  probe is time-boxed so one slow tool cannot stall the tick.
- **Two things can start vt1 sessions:** you over SSH and the deck. Both go
  through the same `Conflicts=` units, so the worst case is the same as
  before — a session started from the deck kills a TTY login left on the
  monitor nobody is looking at.
- **cenci daemon lifetime.** It is spawned on demand by the first agent hook
  and may not exist on a fresh boot; the row reads "no daemon" until the
  first `claude`/`codex` starts, which is correct, not an error.
- **15 keys.** Server page, agents page, UPS takeover, power confirm. That is
  the comfortable maximum; a docker/services page is possible but each page
  costs a key.
- **Laptop surface: out of scope.** The deck lives on the desktop.
