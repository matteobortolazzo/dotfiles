# Assetto Corsa: working Linux installation

Validated on the desktop on 2026-11-10. The user confirmed the game works
properly after the final CSP DLL replacement. This records the local working
combination; it is not a claim that these versions are required on every host.

## Working components

| Component | Version / selection |
| --- | --- |
| Steam game | Assetto Corsa, app ID `244210` |
| Compatibility tool | `GE-Proton9-2` (confirmed in Steam configuration) |
| Launcher | Content Manager as `AssettoCorsa.exe`; original retained as `AssettoCorsa_original.exe` |
| Custom Shaders Patch | `0.3.2-preview2`, build `4305` |
| Weather package | Pure `3.59 Highres` |
| Weather FX style | Pure LCS |
| Current weather controller | `pureCtrl static` (Pure static weather) |
| Post-processing | Enabled, filter `pure` |

Before the Pure/CSP upgrade, the user reported a stable approximately 116 FPS
cap. The final setup was confirmed working visually; no fresh FPS benchmark was
recorded after the upgrade. Keep the existing performance configuration when
repairing fonts or installing weather packages.

## Local paths

All paths below are relative to the user's home directory:

| Purpose | Path |
| --- | --- |
| Game root | `.local/share/Steam/steamapps/common/assettocorsa` |
| Proton prefix | `.local/share/Steam/steamapps/compatdata/244210/pfx` |
| Game settings | Prefix + `/drive_c/users/steamuser/Documents/Assetto Corsa/cfg` |
| CSP log | Prefix + `/drive_c/users/steamuser/Documents/Assetto Corsa/logs/custom_shaders_patch.log` |
| Custom Proton builds | `.local/share/Steam/compatibilitytools.d` |
| CSP download | `Downloads/lights-patch-v0.3.2-preview2-full.zip` |
| Pure download | `Downloads/Pure 3.59 Highres.zip` |

Downloads are local artifacts and may later be removed. Paid packages and game
binaries are not stored in this repository.

## Initial launch failure and Proton fix

With `GE-Proton11-7`, CSP 0.2.11 failed to initialize. The dialog said
“Failed to patch Assetto Corsa”, listed missing symbols such as
`CarLabel::render` and `INIReader::cache`, and requested AC 1.16.3/1.16.4 64-bit.
The CSP log ended with Wine detection and failure to initialize.

Installing and selecting GE-Proton9-2 resolved that launch failure. This was
observed with the installed package combination; the exact underlying Wine
regression was not isolated.

To install that Proton build again:

```bash
mkdir -p ~/.local/share/Steam/compatibilitytools.d
curl -fL --retry 3 \
  https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton9-2/GE-Proton9-2.tar.gz \
  -o /tmp/GE-Proton9-2.tar.gz
tar -xzf /tmp/GE-Proton9-2.tar.gz \
  -C ~/.local/share/Steam/compatibilitytools.d/
```

Fully exit and restart Steam, then select **Assetto Corsa → Properties →
Compatibility → GE-Proton9-2**. Steam only lists locally installed GE builds.

## CSP preview: complete installation and verification

Close Content Manager and the game before replacing CSP files. The downloaded
preview ZIP has `dwrite.dll` and `extension/` at its root; extract those directly
into the game root, allowing replacement after backing up existing files:

```bash
unzip -o ~/Downloads/lights-patch-v0.3.2-preview2-full.zip \
  -d ~/.local/share/Steam/steamapps/common/assettocorsa/
```

The important failure in this session was a **partial CSP update**: metadata
reported 0.3.2-preview2 and 754 package files matched, but `dwrite.dll` was still
old. The displayed version alone did not prove installation succeeded. Replacing
that DLL fixed the final problem; SHA-256 comparison then confirmed **all 755
non-directory archive entries matched the installed files**.

Check package contents against disk after future upgrades:

```bash
python3 - <<'PY'
from pathlib import Path
import hashlib
import zipfile

root = Path.home() / '.local/share/Steam/steamapps/common/assettocorsa'
archive = Path.home() / 'Downloads/lights-patch-v0.3.2-preview2-full.zip'
with zipfile.ZipFile(archive) as z:
    mismatches = []
    checked = 0
    for info in z.infolist():
        if info.is_dir():
            continue
        checked += 1
        target = root / info.filename
        if not target.is_file() or hashlib.sha256(target.read_bytes()).digest() != hashlib.sha256(z.read(info)).digest():
            mismatches.append(info.filename)
    print(f'Checked {checked} files; mismatches: {len(mismatches)}')
    print('\n'.join(mismatches))
PY
```

Run this before editing package configuration files; intentional edits can also
produce mismatches. Restart Content Manager and start a new race after updates.

## Pure installation and graphics selection

The CSP Patreon download is separate from Pure. Sources:

- CSP: <https://acstuff.club/patch/>, preview package from its creator's Patreon.
- Pure: <https://www.patreon.com/peterboese>, including installation guides.
- Older Sol: <https://www.overtake.gg/downloads/sol.24914/>.

No Sol install was needed for this working setup. Initially only base/base-live
weather controllers and the default post-processing filter were installed.
CSP was loading, but the expected Pure lighting and filter were absent.

`Pure 3.59 Highres.zip` contains a wrapper directory named `Pure 3.59/`.
Copy its **contents** into the game root, merging `apps/`, `content/`,
`extension/`, and `system/`. Do not leave the package nested under
`assettocorsa/Pure 3.59/`. Installation copied 798 files, backing up any replaced
files. No uninstall batch scripts were run.

Select **Settings → Custom Shaders Patch → Weather FX → Weather style →
Pure LCS**, and **Settings → Assetto Corsa → Video → Post-processing filter →
pure**, with post-processing enabled.

The per-user settings are `cfg/extension/weather_fx.ini` and `cfg/video.ini`.
The installation initially selected dynamic `pureCtrl`; the final on-disk
configuration selected static weather instead:

```ini
[BASIC]
CONTROLLER='pureCtrl static'
ENABLED=1
IMPLEMENTATION='Pure LCS'
```

Content Manager wrote the quotes shown above. Dynamic Pure Planner is a separate
weather selection; choose it in Content Manager when a changing weather plan is
wanted. Both controllers are included in this package.

```ini
[POST_PROCESS]
ENABLED=1
FILTER=pure
```

Other video settings were preserved. Pure LCS's package manifest declares
linear color space support; no independent HDR configuration was added.

## Content Manager font repair

The prefix's `user.reg` contained these incorrect overrides under
`HKEY_CURRENT_USER\Software\Wine\Fonts\Replacements`:

```text
"Segoe UI"="Times New Roman"
"Verdana"="Times New Roman"
```

With Content Manager and Wine applications closed, back up the registry and
remove **those two values only** in the prefix's Registry Editor
(`protontricks 244210 regedit`). Keep unrelated replacement values.

The repair also copied the existing game font:

```text
assettocorsa/content/fonts/system/segoeui.ttf
    → pfx/drive_c/windows/Fonts/segoeui.ttf
```

Verdana was already installed in the prefix. Font smoothing was already enabled
(`FontSmoothing=2`, `FontSmoothingType=2`) and was left unchanged. The repair
verified the copied Segoe UI bytes and absence of both incorrect mappings.

Do not edit Wine's registry files while its server is running: it can overwrite
the changes. The first repair attempt stopped on that condition without writing;
the repair succeeded after applications were closed.

## Backups and rollback

These backups were created outside the repository:

| Backup | Location |
| --- | --- |
| Fonts: original `user.reg` | `steamapps/compatdata/244210/cm-font-backup-20261110-232739/user.reg` |
| Pure: replaced game files and settings | `steamapps/compatdata/244210/pure-install-backup-20261110-232735/` |
| Previous CSP DLL | `steamapps/common/assettocorsa/dwrite.dll.backup-20261110-233220` |

Here `steamapps` is under `~/.local/share/Steam`. The Pure backup stores replaced
game files under `game/` and user settings under `cfg/`. It is not a full game
snapshot and does not contain newly added files; a complete Pure uninstall needs
the package's uninstall instructions too.

Close the game and Content Manager before restoring anything. Restore only the
specific font values/files or settings needed. Restoring the whole registry
would also roll back unrelated changes since that backup. Restoring only the old
CSP DLL would recreate a mixed-version installation, so roll CSP back as a
complete package if necessary.

A full game reinstall or prefix deletion was **not** needed. The effective fixes
were selecting a working Proton build, correcting fonts, installing Pure and its
filter, and completing the CSP DLL update.
