# UPS — Tecnoware EXA Plus 1500 on NUT

Gated on `ups = true`. Installs [Network UPS Tools](https://networkupstools.org/),
mirrors `system/nut/` into `/etc/nut/`, and turns a power cut into a clean
shutdown instead of a hard stop.

Nothing vendor-supplied is needed or wanted. Tecnoware's own Windows tool talks
the same Megatec/Q\* serial protocol NUT has spoken for twenty years, and NUT is
the only one of the two that runs headless, logs to the journal, and can be
asked what it thinks the battery is doing.

## What's installed

| Piece | Where | Job |
|---|---|---|
| `nut` | `packages/arch-ups.txt` | Driver, server, monitor, CLI |
| `ups.conf`, `upsd.conf`, `nut.conf` | `/etc/nut/` | Which UPS, who listens, what mode |
| `upsd.users`, `upsmon.conf` | `/etc/nut/` | The monitor account and shutdown policy |
| `upssched.conf`, `upssched-cmd` | `/etc/nut/` | The five-minute battery timer |
| `nut-extra.conf` | `/etc/tmpfiles.d/` | `/run/nut` for upssched, stale-flag cleanup |
| `nut-killpower.service` | `/etc/systemd/system/` | Cuts UPS output at the end of shutdown |

`run_onchange_after_51-ups.sh.tmpl` owns all of it. It is `run_onchange`, not
`run_once`: it embeds a `sha256sum` of every file in `system/nut/`, so editing
one of them re-triggers the mirror on the next `chezmoi apply` — no re-running
it by hand the way `45-greetd` needs.

## The driver

```
[exa]
  driver    = nutdrv_qx
  port      = auto
  vendorid  = 0665
  productid = 5161
```

The EXA Plus is the Era Plus in a different shell: a Megatec/Q\* unit behind a
Cypress USB-to-serial bridge, USB ID `0665:5161`.

**The vendor/product ids are not optional.** `port = auto` implies a bus scan,
but `nutdrv_qx` will not pick a subdriver for this VID/PID on its own — it scans,
finds the device, and exits with *no supported devices found*
([nut#3410](https://github.com/networkupstools/nut/issues/3410)). Pinned, it
autodetects the Voltronic-QS protocol and comes up clean.

`blazer_usb` also drives this family and is what the older HCL entries name. It
is the deprecated predecessor of `nutdrv_qx`; there is no reason to prefer it.

## When it shuts down

Two triggers, whichever fires first:

1. **Low battery** — the UPS raises `LB`, `upsmon` runs `systemctl poweroff`.
2. **Five minutes on battery** — `upssched` arms a timer on `ONBATT` and cancels
   it on `ONLINE`; if it expires it calls `upsmon -c fsd`.

The timer is the one that matters. A Q\* protocol UPS derives `LB` from a
battery voltage curve with no calibration behind it, so on a unit whose battery
has aged the signal arrives far too late — or never, because the inverter simply
drops the output first. Trusting `battery.charge` on hardware in this price
class is how you get a hard stop with the monitor still reporting 60%.

Flickers and brownouts cost nothing: the timer is cancelled the moment mains
returns.

To change the window, edit `AT ONBATT` in `system/nut/upssched.conf` and apply.

## Killing the power (and coming back)

`nut-killpower.service` runs at `final.target`, after the filesystems are gone,
and only if `/etc/killpower` exists — the flag `upsmon` drops just before it
triggers the shutdown. It runs `upsdrvctl shutdown`, which tells the UPS to cut
its output shortly after.

That is what makes an unattended box survive a long outage. Without it the UPS
keeps inverting into a machine that already halted, flattens the battery, and
when mains comes back it has nothing left to boot anything with. With it, the
UPS drops to zero, then restores output when mains returns.

**This only completes the loop if the BIOS is set to power on after AC loss.**
On the ASUS board: *Advanced → APM Configuration → Restore AC Power Loss →
Power On*. Left at *Power Off*, the machine shuts down safely and then stays
down until someone presses the button — which on a headless box means a trip to
the desk.

The flag is cleared on the next boot by the `r!` line in the tmpfiles fragment.
Left behind, it would make the *next* ordinary `poweroff` cut the mains too.

## Scope

Standalone: `upsd` binds `127.0.0.1:3493` only, and the sole client is the
`upsmon` on this box. Nothing for `28-firewall` to open, nothing reachable over
the tailnet.

If a second machine ever moves onto the same UPS, three edits — `MODE=netserver`
in `nut.conf`, a `LISTEN` line on the LAN or `tailscale0` in `upsd.conf`, and a
ufw rule for `3493/tcp` scoped the way `28-firewall` scopes everything else. The
secondary then runs `upsmon` with `secondary` instead of `primary`, and this box
stays the one that owns killpower.

## Secrets

`upsd.users` and `upsmon.conf` share a password, so they are tracked as `.in`
files with an `@UPSPASS@` placeholder. The install script generates 32 random
characters on the machine, substitutes them into both, and installs the result
`root:nut 0640`. Nothing secret reaches the source tree — **this repo is
public** — and re-runs reuse the password already on disk rather than rotating
it, because a rotation that lands in only one of the two files locks `upsmon`
out of `upsd`.

## Checks

```bash
upsc exa                      # every variable the UPS reports
upsc exa ups.status           # OL / OB / OB LB / OL CHRG
systemctl status nut-driver@exa nut-server nut-monitor
journalctl -u nut-monitor -f  # watch events live
```

Pull the mains lead and watch: status goes `OL` → `OB`, `wall` announces it, and
`journalctl -t upssched-cmd` shows the timer if you leave it out for five
minutes. Plug it back in and the timer is cancelled.

Test the shutdown path without waiting for a real outage:

```bash
sudo upsmon -c fsd            # forced shutdown, for real — it will power off
```

## Gotchas

- **Data cable, not just the mains.** The USB lead is easy to forget; without it
  every unit still starts and protects nothing. The install script checks the bus
  for `0665:*` and says so. `upsc exa` is the honest test.
- **`/etc/nut` is pacman-owned.** Our files overwrite the package's, so upgrades
  land as `.pacnew`. Check for them after a `nut` update.
- **Battery runtime is an estimate.** `battery.runtime` on a Q\* unit is derived,
  not measured. `nutdrv_qx` accepts a `runtimecal` in `ups.conf` if you want to
  calibrate it against a real load test; until then treat the number as a hint
  and let the five-minute timer be the policy.
- **Replace the battery every 3–4 years.** `upsc exa ups.status` showing `RB`
  means now. On a sealed-lead-acid unit of this size the failure mode is a
  battery that reads full and collapses under load in seconds.
