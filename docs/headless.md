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

## Applying dotfiles over SSH

`chezmoi apply` completes over SSH, but it does **not** refresh
`~/.config/environment`. The secrets template reads every value through
`onepasswordRead`, and `.chezmoi.toml.tmpl` pins `[onepassword] mode = "account"`,
which authenticates against an unlocked 1Password **desktop app** in the caller's
session. There is no such app on the other end of an SSH connection, so `op` sits
on an authorization prompt nobody can answer and fails after 60s.

`.chezmoiignore` probes that path (`op vault list`, bounded by `timeout 5`, the
same client-init the template uses) and ignores the target when it fails, so the
existing file is left untouched and everything after it — including the
`run_once_after_*` scripts — still runs. A warning says so on stderr. Naming the
file explicitly (`chezmoi apply ~/.config/environment`) reports `not managed`,
which is the same answer.

Secrets refresh on the next `chezmoi apply` from a local session at the desk. A
service account (`OP_SERVICE_ACCOUNT_TOKEN` with `[onepassword] mode = "service"`)
would make them resolve headlessly too, at the cost of a long-lived vault token
sitting on the box; that trade was deliberately declined.

## Kernel updates

The entry is written by a `limine-entry-tool` post hook,
`system/limine/85-headless-entry`, installed to
`/etc/boot/hooks/post.d/85-headless-entry`. It runs after every kernel update,
`limine-update` and `mkinitcpio` run, and idempotently from `chezmoi apply`.

The hook exists because a one-shot write does not survive. Global options must
precede every entry in `limine.conf`, so a hand-written entry has nowhere to go
except immediately above the `comment: machine-id=…` marker — and that is
exactly where `limine-entry-tool` looks for the OS entry it owns. On the next
regeneration it adopts `/CachyOS (headless)` as its own name line, drops its
`/+CachyOS` line as redundant, and the generated `//linux-cachyos` entries
reparent under ours.

That failure is silent and nasty: the headless entry becomes a *directory* whose
first child is the normal graphical entry. The menu still shows
`CachyOS (headless)`, the `cmdline:` in the file still reads
`systemd.unit=multi-user.target`, and selecting it boots the graphical cmdline
with greetd and all. `cat /proc/cmdline` is the only thing that tells you:

```bash
cat /proc/cmdline   # headless boot must contain systemd.unit=multi-user.target
```

So the hook re-asserts both the entry and the `/+…` OS entry name line after
every regeneration. It only ever *adds* that line back, never rewrites an
existing one, since a file may carry several `/+…` entries and none of them are
ours — `FIND_BOOTLOADERS=yes` alone contributes `/+Other systems and
bootloaders`. For the same reason the name is derived, not copied from whatever
`/+…` line happens to come first: it follows `limine-entry-tool`'s own
precedence (`TARGET_OS_NAME`, else `PRETTY_NAME`, else `NAME`), so the tool
adopts the line rather than creating a second OS entry.

If two identical `/+…` lines survive, the hook says so on every run and leaves
them alone. That means an earlier regeneration stranded an old OS entry further
down the file — typically with stale BLAKE2 hashes that fail verification if
booted. Deleting it is a manual call: nothing in the hook can tell a stranded
block apart from a deliberate second entry, and guessing wrong costs a boot
option.

It sorts before `90-limine-enroll-config` so that, on a machine with
`ENABLE_ENROLL_LIMINE_CONFIG=yes`, the enrolled config hash covers the repaired
file rather than the broken one.

The kernel paths (`boot():/<machine-id>/linux-cachyos/{vmlinuz,initramfs}`) are
version-independent, so the entry itself survives kernel bumps. The BLAKE2
`#<hash>` suffix is deliberately stripped: it changes with every rebuild, and a
stale hash is a boot failure. Verification still covers the generated entries.

After a kernel update or a `limine-update`, confirm the structure is still sane:

```bash
sudo grep -n -A3 'headless boot entry' /boot/limine.conf
sudo grep -n '^/+' /boot/limine.conf     # must be exactly one, under the marker
```

If the entry or that `/+…` line is gone, run the hook by hand:

```bash
sudo /etc/boot/hooks/post.d/85-headless-entry
```

If the hook itself is missing, re-run the installer (`run_once` will not fire
again on its own, same idiom as the greetd script):

```bash
chezmoi execute-template < "$(chezmoi source-path)/run_once_after_49-headless-boot.sh.tmpl" | bash
```

The previous `/boot/limine.conf` is kept as `limine.conf.chezmoi.bak` on every
write, alongside limine's own `limine.conf.old`.

## Recovery

- **Headless entry does not boot** — pick `CachyOS` at the menu (5 s timeout) and
  you are back to exactly the old behaviour.
- **Headless entry boots straight into the greeter** — it has been reparented
  into a directory. Check `cat /proc/cmdline` for `systemd.unit=multi-user.target`
  and `sudo grep '^/+' /boot/limine.conf` for the missing OS entry line, then run
  `sudo /etc/boot/hooks/post.d/85-headless-entry`.
- **Graphical entry does not boot** — pick `CachyOS (headless)`, SSH in, and
  debug with `journalctl -b -u greetd`. This is the case the two-entry split buys
  you, and the reason greetd is never masked.
- **Session starts and dies immediately** — `journalctl -u greetd-autologin@niri`.
  The unit is `Restart=no` on purpose: a respawn loop on a headless box floods
  the journal and holds vt1 away from getty.
- **Locked out entirely** — the greetd recovery in the README still applies:
  `Ctrl+Alt+F2` for a TTY, since `getty@tty1` is not masked.
