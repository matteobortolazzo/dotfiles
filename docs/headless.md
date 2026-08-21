# Headless boot

Applies to a `profile = "main"` machine with `headless = true` — currently the
desktop, which is a remote dev target most of the time and a sim rig / couch
gaming host some of the time. Set up by
`run_once_after_49-headless-boot.sh.tmpl`.

## Two boot entries, not one default target

limine gets a second entry off the same kernel:

| Entry | cmdline | What comes up |
| --- | --- | --- |
| `CachyOS (headless)` | `… systemd.unit=multi-user.target` | TTY login, sshd, Tailscale, docker, ufw. No greetd, no compositor, no GPU session. |
| `CachyOS` | unchanged | Exactly what the laptop boots: greetd → regreet → niri or gamescope. |

Nothing is disabled and nothing is masked. `greetd.service` stays enabled;
`graphical.target` is simply never reached, and the unit that pulls greetd in is
`graphical.target`. That is what makes this reversible at the boot menu rather
than through a shell.

`systemctl set-default multi-user.target` would do the same job with one global
switch, and was rejected for two reasons: the choice belongs where you make it
(at the menu, per boot), and a box whose desktop half is broken is much easier to
recover when the working configuration is still one menu entry away.

`quiet` and `splash` are dropped from the headless cmdline. On a box you reach
over SSH the console exists to tell you why a boot failed, and plymouth is part
of the graphical stack this entry exists to skip.

**Defaults**: the script sets `default_entry: CachyOS (headless)` — by name, not
index, because `limine-snapper-sync` shifts indices every time it adds a snapshot
— and `remember_last_entry: no`. Without that second change the box would
silently stay graphical-by-default after a single gaming session, which is the
opposite of the point. Both are plain lines at the top of `/boot/limine.conf` if
you want the other behaviour.

## Bringing the desktop up

Two paths, because they solve different problems:

```bash
desktop up niri         # autologin into niri            (works over SSH)
desktop up gamescope    # autologin into couch gaming    (works over SSH)
desktop greeter         # regreet on the monitor, type the password at the desk
desktop down            # stop it, hand vt1 back to getty
desktop status          # what owns vt1, plus logind sessions
```

`desktop greeter` is just `systemctl start greetd` — the normal login path,
started late. It cannot help you from an SSH shell, because somebody has to type
a password at the keyboard.

`desktop up` is `greetd-autologin@<session>.service`, which runs greetd against
`/etc/greetd/autologin-<session>.toml`. Those configs differ from
`/etc/greetd/config.toml` in one block:

```toml
[initial_session]
command = "niri-session"
user = "<you>"
```

greetd runs `initial_session` once, on start, with no prompt — so a session
appears on vt1 without anyone touching the keyboard. **This is the one couch
gaming needs**: Sunshine has nothing to capture until somebody is logged in, and
discovering that from the sofa is the classic way streaming fails. When the
session exits, greetd falls back to the regreet `default_session`, so logging out
at the desk still gets you the picker — that is how you reach gamescope from a
session you started as niri.

vt1 has exactly one owner. `getty@tty1`, `greetd`, and every
`greetd-autologin@*` instance declare `Conflicts=` on each other, so starting any
one of them stops the others. Starting a session from SSH will therefore kill a
TTY login you left open on the monitor.

## What this does and does not save

The NVIDIA driver still loads: the headless entry does **not** set
`nvidia_drm.modeset=0` or blacklist the modules, deliberately. Wayland needs KMS,
so a session started with `desktop up` would fail with modeset off, and the
"start the desktop without rebooting" half of this setup is the reason it exists.
What you save is the compositor, DMS, the portals and everything else
`graphical.target` drags in — the desktop idled at ~12 W of GPU draw before this
change. Squeezing out the last few watts means a boot entry with no NVIDIA driver
at all, and that trades away the on-demand desktop.

## Kernel updates

The entry is written **above** the `comment: machine-id=…` line, because that
comment is how `limine-entry-tool` finds the block it owns and rewrites — anything
between the comment and the generated entries is lost on the next kernel update.
The paths it uses (`boot():/<machine-id>/linux-cachyos/{vmlinuz,initramfs}`) are
version-independent, so the entry survives kernel bumps on its own. The BLAKE2
`#<hash>` suffix is deliberately stripped: it changes with every rebuild, and a
stale hash is a boot failure. Verification still covers the generated entries.

After a kernel update or a `limine-update`, confirm the entry is still there:

```bash
sudo grep -A3 'headless boot entry' /boot/limine.conf
```

If it is gone, re-run just this script (`run_once` will not fire again on its
own, same idiom as the greetd script):

```bash
chezmoi execute-template < "$(chezmoi source-path)/run_once_after_49-headless-boot.sh.tmpl" | bash
```

The previous `/boot/limine.conf` is kept as `limine.conf.chezmoi.bak` on every
write, alongside limine's own `limine.conf.old`.

## Recovery

- **Headless entry does not boot** — pick `CachyOS` at the menu (5 s timeout) and
  you are back to exactly the old behaviour.
- **Graphical entry does not boot** — pick `CachyOS (headless)`, SSH in, and
  debug with `journalctl -b -u greetd`. This is the case the two-entry split buys
  you, and the reason greetd is never masked.
- **Session starts and dies immediately** — `journalctl -u greetd-autologin@niri`.
  The unit is `Restart=no` on purpose: a respawn loop on a headless box floods
  the journal and holds vt1 away from getty.
- **Locked out entirely** — the greetd recovery in the README still applies:
  `Ctrl+Alt+F2` for a TTY, since `getty@tty1` is not masked.
