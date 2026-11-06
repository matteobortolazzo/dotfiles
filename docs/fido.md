# Security-key unlock (FIDO2 + pam_u2f)

Unlock the DMS lock screen with a touch (and a fingerprint or a short PIN)
instead of typing the account password every time. The laptop has no
fingerprint reader, so the "something you are" factor comes from a FIDO2 key
that lives in the dock. Installed by `packages/arch-desktop.txt` (`pam-u2f`,
`libfido2`), wired by `run_onchange_after_53-fido.sh.tmpl`, which installs
`system/pam/dankshell-u2f` to `/etc/pam.d/`. Enrollment is manual: it is per
key and per user, so nothing of it is a dotfile.

## How DMS authenticates

The shell never checks a password itself. The lock screen runs two PAM
conversations side by side: the password one through `/etc/pam.d/dankshell`
(which includes the system stack, `system-auth` on Arch), and, when the
**Security key** toggle is on, a second one through `/etc/pam.d/dankshell-u2f`.
Whichever succeeds first unlocks ("Alternative" mode; "Second factor" mode
instead requires the password *and then* the key).

DMS writes `dankshell-u2f` itself, with a marker block, when the toggle is
flipped. A file **without** its `BEGIN DMS LOCKSCREEN U2F AUTH` marker is left
alone ("Custom /etc/pam.d/dankshell-u2f found (no DMS block). Leaving it
untouched."), which is how the repo's version takes over. The shell still
validates it: it must contain a `pam_u2f.so` auth directive.

## Why not the stock DMS line

DMS's own line is `auth required pam_u2f.so cue nouserok timeout=10`. Two
things are wrong with it for a key that stays plugged in:

- **`nouserok`** makes the module *succeed* when the user has no
  `~/.config/Yubico/u2f_keys`. On a standalone service that is an unlock
  with no key at all. The repo's file drops it: no enrollment, no unlock on
  this path, and the password path next to it is unaffected.
- **No user verification.** Touch alone is "something you have", and a key
  left in the dock is had by whoever sits at the desk. The repo's file asks
  the key to verify the user: line 1 uses the key's built-in verification (a
  fingerprint sensor), line 2 falls back to the key's PIN. The PIN is checked
  *by the key*, rate-limited in hardware and bricked after 8 misses, which is
  what makes a 4 to 6 digit secret acceptable. A software PIN
  (`pam_pwdfile`) cannot offer that.

Threat model after this: a thief who takes the laptop leaves the key in the
dock and `lockBeforeSuspend` has already locked the session, so they need the
password. Someone at the desk needs your finger or your key PIN.

## Which key

Any FIDO2 key with a PIN works for touch + PIN. For touch + fingerprint it
needs a built-in sensor. Buy the **USB-A** version: it lives in the dock, and
docks have spare USB-A ports. NFC is useless here.

| Key | Verification | Price seen (EU, Nov 2026) |
|---|---|---|
| Token2 PIN+ Bio3 FIDO2 | fingerprint, PIN fallback | about 37 EUR, Swiss shop, ships to the EU, has a Linux `pam_u2f` guide. Closed firmware. |
| YubiKey Bio (FIDO Edition) | fingerprint, PIN fallback | about 90 EUR |
| Yubico Security Key C NFC | PIN only | about 29 to 35 EUR |
| Token2 PIN+ (plain) | PIN only | about 15 to 22 EUR |

Skip the YubiKey 5 series unless you also want PIV/OpenPGP; the lock screen
and passkeys do not need them. The same key doubles as a passkey for GitHub,
Google and 1Password, and as `ssh-keygen -t ed25519-sk` for SSH.

Standalone USB fingerprint *readers* were considered and rejected: libfprint
support is spotty and most cheap ones do not work. If you ever go that way,
check the [libfprint supported devices](https://fprint.freedesktop.org/supported-devices.html)
list before buying; DMS has a separate **Fingerprint** toggle (`pam_fprintd`)
for that path.

## Setup, once the key is here

```bash
# 1. key PIN (required for the PIN fallback and for enrolling fingerprints)
fido2-token -L                        # find the /dev/hidrawN
fido2-token -S /dev/hidrawN           # set the PIN
fido2-token -S -e /dev/hidrawN        # Bio keys only: enroll a fingerprint (repeat per finger)
fido2-token -I /dev/hidrawN | grep -E 'options|uv'   # uv/bioEnroll should be true on a Bio key

# 2. enroll the key for pam_u2f (touch when it blinks)
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys          # first key
pamu2fcfg -n >> ~/.config/Yubico/u2f_keys      # a second / spare key

# 3. check the service by hand before trusting the lock screen with it
pamtester dankshell-u2f "$USER" authenticate   # pamtester is in the AUR
```

Then **Settings → Lock screen**: enable **Security key**, mode
**Alternative**. The shell reads `/etc/pam.d/dankshell-u2f`, sees no DMS
block and keeps it. `chezmoi apply` installs the file whenever
`system/pam/dankshell-u2f` changes; the script prints the enrollment
reminder above as long as `u2f_keys` is missing.

`pamu2fcfg` and the module both default the origin and app id to
`pam://<hostname>`. Rename the machine and every enrollment stops matching:
re-run `pamu2fcfg`, or pin them with `-o pam://name -i pam://name` and
`origin=`/`appid=` on the module line.

## What is deliberately not done

- **`u2f_keys` is not tracked.** It is a credential handle plus public key,
  not a secret, but it is per key, per user and per origin. Keep it where
  `pam_u2f` looks by default, in `$XDG_CONFIG_HOME/Yubico/`.
- **The greeter is left on the password.** DMS has a matching greeter toggle
  that edits `/etc/pam.d/greetd`; it is a separate decision and the greeter
  is hit once per boot, not thirty times a day. The lock screen is the
  friction.
- **No `fido` machine flag.** `pam-u2f` is a 100 KB module and the PAM service
  is referenced by nothing until the DMS toggle is on, so every `main`
  machine gets both and nothing changes until a key is enrolled.

## Troubleshooting

```bash
journalctl -b -g pam_u2f                      # the module logs why it refused
fido2-token -I /dev/hidrawN                   # clientPin / uv / bioEnroll flags
ls -l /dev/hidraw*                            # key must be readable: plugdev/uaccess rule from libfido2
```

If `pamtester` passes but the lock screen does not offer the key, the DMS
toggle is off or the shell could not validate the file; `dms doctor` has a
PAM check and names the service it resolved.
