# Stream Deck as a monitor + remote for the headless desktop — proposal

> **Status: proposal, nothing implemented.** This is the design to react to
> before any file lands. Open questions are at the end.

The original 15-key Stream Deck sits in the laptop's dock. The laptop is the
machine you type on; the desktop is the box that does the work and boots
headless (`docs/headless.md`). The deck becomes the one glanceable surface for
that box: load, memory, GPU, UPS, what owns vt1, which coding agents are
running and which one is waiting for you — plus the handful of buttons you
otherwise type over SSH (`desktop up niri`, `desktop up gamescope`,
`desktop down`).

The deck only exists while docked, which is a feature: it is the "at my desk,
desktop-dev mode" control panel, and it vanishes when the laptop leaves.

## What is in the way today

One real blocker and one latency problem, both on the desktop side.

1. **`desktop` needs an interactive `sudo`.** `dot_local/bin/executable_desktop`
   runs `sudo systemctl start greetd-autologin@…`. From a deck button that
   runs `ssh <devHost> desktop up niri` there is no TTY to type a password
   into, so the call fails. There is no sudoers or polkit rule in the repo
   today (checked). Fix below (polkit, scoped to those units).
2. **Every poll is a fresh SSH handshake.** The `Host <devHost>` block in
   `private_dot_ssh/config.tmpl` has `ForwardAgent yes` and nothing else. A
   2-second poll loop over Tailscale would pay a full key exchange plus
   agent round trip each tick. Fix below (`ControlMaster`), and it speeds up
   every `ssh <devHost> …` you type as a side effect.

Everything else needed already exists: `desktop status` knows what owns vt1,
`upsc exa` has the UPS, `nvidia-smi` works on a headless boot because the
driver stays loaded (deliberate, see `docs/headless.md`), Sunshine's prep hook
leaves a state file while a stream is live, and cenci publishes agent state in
one machine-readable line.

## cenci: what the deck can read

cenci-watch's daemon runs on whichever host the tmux server runs on (the
desktop, when you work there over SSH). Every desktop widget it ships (DMS,
Waybar, GNOME, Plasma, SwiftBar) polls the same thing:

```bash
cenci widget-json
# {"text":"▶ 2  ! 1","tooltip":"a-work:3 - 42-implement (claude) (running)\n…",
#  "class":"need-input","alt":"active","headroom":{"claude":0.62},"dispatch":{…}}
```

- `class` is the highest-priority state (`failed` > `escalated` > `need-input`
  > `running` > `done` > `stopped` > `idle`) — the tile colour.
- `tooltip` is one line per session, `session:index - name (agent) (status)`.
  The README states the status token is pinned to the last position because
  plugins parse it with an end-anchored regex, so parsing it is sanctioned,
  not a hack. Those lines are what give the deck **one key per agent session**.
- `headroom` is the per-agent usage budget left (0–1). Worth a small gauge:
  it is the number that decides whether dispatch will keep going tonight.
- `dispatch` says whether the fleet loop is on and when it last ran.
- Exit 1 / no output means the daemon is down → tile reads "no daemon".

cenci documents the remote case as "forward the Unix socket over SSH and run
`widget-json -socket` locally". For the deck we do not need that: the deck's
collector already SSHes in every tick, so it just runs `cenci widget-json` on
the desktop and ships the line back inside the same JSON as the CPU numbers.
One round trip, no second tunnel. (The forwarded socket stays the right answer
if we ever want push instead of poll — `pkg/watch` is a public Go client for
exactly that.)

The laptop runs cenci too (the DMS plugin is enabled in
`dot_config/DankMaterialShell/plugin_settings.json`). The agent row should
merge **both** hosts, with a one-glyph host tag, so a session on the laptop
and one on the desktop sit side by side.

**Press on a session tile = jump into it.** The tile knows `session:index`, so
it opens (or focuses, via `focus-or-spawn.sh`) a Ghostty running
`ssh -t <devHost> tmux attach -t <session> \; select-window -t <session>:<index>`.
That is the missing piece every bar widget lacks: they show that an agent
needs input, the deck takes you to it in one press.

## Layout (3 rows × 5 keys, 72 px tiles)

Default page while the desktop is reachable:

```
┌─────────┬─────────┬─────────┬─────────┬─────────┐
│ CPU     │ RAM     │ GPU     │ UPS     │ NET     │  row 1: stats, 2 s
│ 23%     │ 11/64G  │ 4% 41°  │ OL 100% │ ts ✓    │
│ ld 1.2  │         │ 12 W    │ 38 min  │ 3 ctr   │
├─────────┼─────────┼─────────┼─────────┼─────────┤
│ AGENTS  │ #42     │ #78     │ #91     │ +2      │  row 2: cenci
│ ▶2 !1   │ impl    │ refine  │ impl    │ more    │  colour = status
│ cl 62%  │ ! input │ ▶ run   │ ✓ done  │         │  press = jump
├─────────┼─────────┼─────────┼─────────┼─────────┤
│ NIRI    │ GAME    │ GREETER │ DOWN    │ ⇆       │  row 3: actions
│ ● on    │ ○       │ ○       │         │ laptop  │  active one lit
└─────────┴─────────┴─────────┴─────────┴─────────┘
```

Tiles, by row:

**Row 1 — stats.** CPU % + 1-min load; RAM used/total; GPU util, temp and
power draw from `nvidia-smi --query-gpu=…` (the "12 W idle" number from
`headless.md`, live); UPS `ups.status` + `battery.charge` + `battery.runtime`
from `upsc exa` (tile goes `urgent` red on `OB`, this is the one you most want
to glance at during a storm); network/health tile: Tailscale up, running
docker container count, root disk free. CPU temp comes from `k10temp` via
`/sys/class/hwmon`, no `lm_sensors` needed.

**Row 2 — agents.** Aggregate tile (cenci `text` + headroom %), then up to
three session tiles sorted need-input → failed → running → done → idle, then a
"+N" overflow tile that opens `cenci status` in a terminal. Session tile shows
the ticket number / slug, the skill, the status glyph, and a host tag when it
is the laptop's own daemon rather than the desktop's. Press = jump (above).

**Row 3 — actions.** `NIRI` / `GAME` / `GREETER` map to `desktop up niri`,
`desktop up gamescope`, `desktop greeter`; the one whose unit is active is
drawn lit (gold) from `desktop status`. `GAME` additionally shows a streaming
badge while Sunshine's `stream-prep` state file exists. `DOWN` is
`desktop down`. `⇆` switches to the laptop page. Power actions (reboot,
poweroff) live on a hold: hold `DOWN` 1.5 s for a confirm tile. The original
deck has no hardware long-press, but the library reports key down/up so the
daemon can time it; nothing destructive on a single tap.

**Laptop page.** Local `dms ipc` calls that are awkward mid-call: mic mute
(state read back via `wpctl`), DND, lock, audio sink cycle (the one thing a
niri bind cannot express because it needs a sink id), wallpaper next,
screenshot, back to the server page. Also the laptop's own cenci sessions if
you prefer them here instead of merged.

**Offline page.** Shown automatically when the desktop does not answer: grey
"offline" tiles, a Wake-on-LAN key (LAN only — a magic packet is an L2
broadcast and does not cross Tailscale; from elsewhere the key is disabled and
says so), Tailscale status, and the laptop-page switch.

Colours are the Glassmorphic Dark tokens from `.claude/CLAUDE.md`: `bg-solid`
tiles, `text-primary` labels, `accent` gold for the active session/unit,
`urgent` for need-input and on-battery, `success` for done/online, `warning`
for low headroom. Labels in Inter, glyphs from JetBrains Mono Nerd Font (both
already in `arch-desktop.txt`). The deck becomes one more place the palette is
applied, next to niri, DMS, Ghostty and regreet.

## Architecture

```
laptop (deck in dock)                       desktop (headless, Tailscale)
┌──────────────────────────┐   ssh, mux'd   ┌─────────────────────────────┐
│ deckd (user service)     │ ─────────────▶ │ deck-stats  → one JSON line │
│  · renders 15 tiles      │   every 2 s    │   /proc, nvidia-smi, upsc,  │
│  · runs press actions    │                │   desktop status, sunshine, │
│  · local: dms/niri/wpctl │ ◀───────────── │   docker, tailscale,        │
│  · remote: ssh devHost … │                │   cenci widget-json         │
│  · cenci (local socket)  │                │ polkit: start/stop greetd*  │
└──────────────────────────┘                └─────────────────────────────┘
       ▲ udev: deck plugged → start; unplugged → stop
```

**Why one collector script, not N commands.** Fifteen tiles polling
individually would be fifteen SSH execs per tick. `deck-stats` on the desktop
gathers everything into one JSON object; the laptop runs it once per tick.
It is a tracked script (`dot_local/bin/executable_deck-stats`, gated on
`dev`), so what the deck can show is versioned with the box that produces it.
It also runs fine by hand: `ssh <devHost> deck-stats | jq`.

**Why a small custom daemon, not a GUI app.** Compared on what this design
actually needs:

| | Dynamic tiles (one key per agent session) | Colour by state | Config in chezmoi | Runs with no GUI | Notes |
|---|---|---|---|---|---|
| **Custom daemon** (`python-elgato-streamdeck` + Pillow) | ✓ | ✓ | ✓ plain file | ✓ | ~400 lines; we own rendering and press logic |
| **deckmaster** (Go, TOML) | ✗ static key map | ✗ fixed colours | ✓ | ✓ | has a `command` widget on an interval; zero code, but no per-session keys |
| **StreamController** (GTK4, Flathub) | ✗ | plugin-dependent | ✗ lives in `~/.var/app` | ✗ | best GUI; icons and pages; could not confirm a "command output on key" plugin |
| **OpenDeck** (Tauri) | ✗ | plugin-dependent | ✗ | ✗ | runs Elgato-SDK plugins, mostly Windows-app oriented |

The per-session agent keys are the feature that decides it, and only a custom
daemon can create keys from data. Python rather than Go for the first cut:
the config and the code sit next to each other in this repo, there is no build
step on `chezmoi apply`, and `stream-prep.sh` already leans on `python3` here.
If it grows, the natural Go rewrite would use cenci's `pkg/watch` for push and
`muesli/streamdeck` (deckmaster's device layer) for the hardware — and could
be contributed back to cenci as a `watch/plugin/streamdeck` surface. The
dotfiles-specific tiles (UPS, `desktop`, GPU) would stay here either way.

**Device access.** The deck is USB HID, vendor `0fd9` (original: product
`0060`, the 2019 revision `006d`; check `lsusb`). The library's current docs
want the `hid` Python package backed by libhidapi's **libusb** build, which on
Arch is the single `hidapi` package. One udev rule grants the seated user
access without root:

```udev
# system/udev/70-streamdeck.rules
SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", TAG+="uaccess", TAG+="systemd", \
  ENV{SYSTEMD_USER_WANTS}="streamdeck.service"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
```

`SYSTEMD_USER_WANTS` is what makes hotplug free: the user manager starts
`streamdeck.service` when the device appears and, with `StopWhenUnneeded=yes`
on the service, stops it when the device goes. No polling for the dock, no
daemon idling on battery at a café. The unit is also `PartOf=graphical-session.target`
so it dies with the session and inherits niri's `WAYLAND_DISPLAY` for the
local `dms ipc` / `niri msg` actions — same reasoning as `captive-portal.service`.

**Idle and lock.** Full brightness while in use, dim to ~10 % after a minute
without a press, blank on `org.freedesktop.login1.Session.Lock` and restore on
`Unlock` (DBus, no polling). DMS's lock already emits those.

## Desktop-side changes

1. **polkit rule instead of `sudo`.** `system/polkit/49-desktop-units.rules`,
   installed by `run_once_after_49-headless-boot.sh.tmpl` next to the autologin
   units, allows the dev user to `manage-units` for exactly `greetd.service`
   and `greetd-autologin@*.service` (`getty@tty1` stops through `Conflicts=`,
   nothing needs to touch it directly), plus `login1.power-off` and
   `login1.reboot` so the hold-to-confirm keys work from an SSH session, which
   logind otherwise treats as a non-seat caller and asks for auth:

   ```js
   polkit.addRule(function (action, subject) {
     if (subject.user !== "<user>") return polkit.Result.NOT_HANDLED;
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

   `desktop` then drops `sudo` and calls `systemctl` directly (falling back to
   `sudo` only if polkit says no, so it keeps working at the desk on a box
   without the rule). Security delta: whoever holds your SSH key can already
   do everything as you on that box; this adds "start/stop the greeter and
   power off without a password", which is the documented purpose of
   `desktop up` over SSH anyway. The UPS killpower path is root and unaffected.

2. **`deck-stats`.** `dot_local/bin/executable_deck-stats`, gated on `dev` in
   `.chezmoiignore` the way `.local/bin/desktop` is gated on `main`. Emits one
   JSON object; every field optional so a missing tool (no UPS, no GPU) drops
   the field rather than failing the tick:

   ```json
   {"host":"<devHost>","ts":1760781600,
    "cpu":{"pct":23,"load1":1.2,"temp":48},
    "mem":{"used_mb":11264,"total_mb":65536},
    "gpu":{"util":4,"temp":41,"power_w":12},
    "ups":{"status":"OL","charge":100,"runtime_s":2280},
    "disk":{"root_free_gb":412},
    "docker":{"running":3},
    "tailscale":{"online":true},
    "desktop":{"active":"greetd-autologin@niri.service","streaming":false},
    "cenci":{"text":"▶ 2  ! 1","class":"need-input","tooltip":"…","headroom":{"claude":0.62}}}
   ```

   `desktop.active` comes from the same unit list `desktop status` prints;
   `desktop.streaming` is the existence of `$XDG_RUNTIME_DIR/sunshine-stream-prep.desk-off`.
   `cenci` is `cenci widget-json` passed through verbatim (`null` when it
   exits 1).

3. **SSH multiplexing.** Add to the `Host <devHost>` block in
   `private_dot_ssh/config.tmpl`:

   ```
       ControlMaster auto
       ControlPath ~/.ssh/cm-%r@%h:%p
       ControlPersist 10m
   ```

   First connection pays the handshake; every poll and every button press
   afterwards is a channel on the existing connection (tens of ms). The agent
   forward rides the master, so the 1Password-backed key keeps working.
   `private_dot_ssh/` is already `private_`, so the socket directory is fine.

## Laptop-side files

| File | Purpose |
|---|---|
| `dot_config/streamdeck/deckd.py` (or `dot_local/bin/executable_deckd`) | the daemon: device, renderer, poll loop, press handlers |
| `dot_config/streamdeck/config.toml` | pages → tiles; each tile has a `kind` (`stat`, `cenci`, `unit`, `cmd`, `page`) and its `press` command |
| `dot_config/systemd/user/streamdeck.service` | `StopWhenUnneeded=yes`, `PartOf=graphical-session.target`, `Restart=on-failure` |
| `system/udev/70-streamdeck.rules` | uaccess + `SYSTEMD_USER_WANTS` |
| `run_once_after_52-streamdeck.sh.tmpl` | installs the udev rule (needs root, same mirror idiom as greetd/nut), creates `~/.local/share/streamdeck/venv` with `streamdeck pillow hid` (pip into a venv — Arch's system Python is PEP 668 externally-managed, and the README's rule is toolchains install into `$HOME`) |
| `docs/streamdeck.md` | this file, rewritten as the real doc once it lands |

Gate: a new `deck` data var, prompted like `ups` ("a Stream Deck is on this
box's dock"). It is a hardware fact, not a role, and `ups` is the precedent for
exactly that shape. Read with `dig "deck" false .` everywhere. Suggested
`pacman -S hidapi` (not installed by the scripts, per the repo rule).

## Press actions, concretely

| Tile | Press | Hold 1.5 s |
|---|---|---|
| session `#42` | focus-or-spawn Ghostty → `ssh -t <devHost> tmux attach -t a-work \; select-window -t a-work:3` | — |
| `+N` | Ghostty → `ssh -t <devHost> cenci status` then shell | — |
| `AGENTS` | toggle merged/remote-only view | `ssh <devHost> cenci dispatch loop on\|off` (toggle) |
| `NIRI` / `GAME` / `GREETER` | `ssh <devHost> desktop up niri` / `up gamescope` / `greeter` | — |
| `DOWN` | `ssh <devHost> desktop down` | confirm tile → reboot / poweroff |
| `UPS` | Ghostty → `ssh -t <devHost> upsc exa` | — |
| `GPU` / `CPU` | Ghostty → `ssh -t <devHost> btop` (if present) | — |
| offline `WOL` | magic packet to the desktop's MAC (stored in the deck config, LAN only) | — |

All remote presses are the same commands you type today; nothing on the
desktop learns a new verb except `deck-stats`.

## Risks and caveats

- **Original-deck quirks.** The 2017 unit is the oldest the library supports;
  it needs a `reset()` after hotplug and occasionally misses the first frame.
  The udev-driven restart covers the reconnect path.
- **Dock re-enumeration on resume.** Thunderbolt docks sometimes re-enumerate
  USB late after suspend. Same answer: the device unit reappears, the service
  restarts.
- **Tick cost.** One multiplexed SSH exec per 2 s plus `nvidia-smi` and
  `upsc` on the desktop is negligible, but `nvidia-smi` can take ~100 ms on
  first call after idle; `deck-stats` should time-box each probe.
- **Two cenci hosts, one deck.** Merging local + remote sessions means the
  daemon reads the local socket directly and the remote one via `deck-stats`;
  sort order has to be by status first, host second, or the row shuffles.
- **15 keys.** The server page is full. Anything else (per-project dev page,
  tmux session jumps) is a page, and page-switching on a 15-key deck costs a
  key per page. Two pages plus offline is the comfortable maximum.

## Open questions

1. **Python in dotfiles, or Go in its own repo (possibly as a cenci surface)?**
   Proposal says Python first; a Go rewrite is cheap later because the config
   format and `deck-stats` contract do not change.
2. **New `deck` var** vs. gating on "profile `main` and hostname ≠ `devHost`".
   The var is cleaner and matches `ups`; the hostname rule needs no re-init.
3. **Hold-to-confirm for reboot/poweroff** — wanted at all, or keep power out
   of the deck entirely and leave it to `ssh`?
4. **Merge the laptop's own cenci sessions into the agent row**, or keep them
   on the laptop page?
5. **"Game mode" = `desktop up gamescope`?** Assumed yes (the couch session).
   If you also mean Feral `gamemode`, that is per-process and not something to
   toggle from here.
6. **Wake-on-LAN** — is WoL enabled on the desktop's NIC (`ethtool eno1 | grep
   Wake-on`), and do you want the MAC in a public repo? It could live in the
   machine-local `.chezmoi.toml` data instead.
