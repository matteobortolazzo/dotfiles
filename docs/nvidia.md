# NVIDIA on the gaming desktop: DLSS, Smooth Motion, Reflex, DLSS 5

A runbook, in the order to do it: ordinary Steam games first, then Assetto
Corsa with Content Manager, then the DLSS 5 experiment. The reasoning and the
hardware facts live in [`gaming.md`](gaming.md) ("NVIDIA features"); this file
is the checklist.

Hardware this is written against: **RTX 4080 (Ada)**, NVIDIA driver 615.x,
Proton-CachyOS 11 from pacman. Verify before starting:

```bash
nvidia-smi --query-gpu=name,driver_version --format=csv
pacman -Q proton-cachyos-slr
nvrun --help
```

## What the card can and cannot do

| Feature | RTX 4080 | How |
| --- | --- | --- |
| DLSS 4 Super Resolution / Ray Reconstruction, transformer model | yes | `nvrun` default |
| DLSS Frame Generation (single) in games that ship it | yes | `nvrun` default |
| DLSS Multi Frame Generation (2x–4x) | **no**, Blackwell only | — |
| Smooth Motion (driver frame generation for any game) | yes | `nvrun --smooth` |
| Reflex | yes | DX11/DX12: nothing; Vulkan: `nvrun --reflex` |
| DLSS 5 neural rendering | **not officially** (RTX 50 only; Ada "later") | community route, Phase 3 |
| RTX HDR / RTX Video / NVIDIA App overrides | no, Windows only | — |

Every feature on Linux is an environment variable. `~/.local/bin/nvrun`
(`dot_local/bin/executable_nvrun`) sets the right ones and runs the game:

```
nvrun [--no-dlss] [--smooth] [--reflex] [--hud] [--csp] [--nr] [--log] %command%
```

| Flag | Sets | Use it when |
| --- | --- | --- |
| (none) | `PROTON_DLSS_UPGRADE=1`, `PROTON_ENABLE_NGX_UPDATER=1`, `PROTON_FORCE_NVAPI=1`, `DXVK_NVAPI_DRS_SETTINGS=…render_preset_latest` | always; harmless on games without DLSS |
| `--no-dlss` | nothing of the above | a game breaks with the override |
| `--smooth` | `NVPRESENT_ENABLE_SMOOTH_MOTION=1` | GPU-bound title, native FG **off** |
| `--reflex` | `DXVK_NVAPI_VKREFLEX=1`, `PROTON_VKD3D_LOWLATENCY=1` | Vulkan-native or DX12 titles |
| `--hud` | `PROTON_DLSS_INDICATOR=1` | verifying; remove afterwards |
| `--csp` | `WINEDLLOVERRIDES=dwrite=n,b` | Assetto Corsa with Custom Shaders Patch |
| `--nr` | `PROTON_FORCE_NVAPI=1`, `WINEDLLOVERRIDES=dxgi=n,b` | the DLSS 5 ReShade route |
| `--log` | `PROTON_LOG=1` → `~/steam-<appid>-<proton>.log` (Proton-CachyOS appends its build, e.g. `steam-805550-cachyos-11.0-20261015-slr.log`) | anything that does not work |

Flags stop at the first argument not starting with `--`, so a game's own
flags after `%command%` pass through. `nvrun env | grep -E 'PROTON|DXVK|NV'`
shows what a flag set exports, without launching anything.

## Phase 1: ordinary games (ACC, AC EVO, AC Rally)

Steam has **no per-game Proton mapping** on this box, so everything has been
running on Steam's default (Proton Experimental is in the library). Valve's
Proton understands the override but not Proton-CachyOS's downloader, so fix the
tool first.

For each title:

1. Steam → right-click the game → Properties → Compatibility → tick "Force the
   use of a specific Steam Play compatibility tool" → **Proton-CachyOS**.
2. Properties → General → Launch options:

   ```
   nvrun --hud --log %command%
   ```

3. Launch. In the game's own video settings enable DLSS (Quality or DLAA) and,
   where offered, Frame Generation. Leave Steam Input **disabled** for sims.
   **ACC:** DLSS only sticks with anti-aliasing on TAA and after Apply; check
   `"dLSSEnable": true` in the prefix's
   `Documents/Assetto Corsa Competizione/Config/menuSettings.json`. ACC has
   no DLSS FG.
4. Read the indicator at the bottom of the screen. It only draws while DLSS
   is actually rendering — no indicator with the DLL loaded means the game
   has DLSS off. Pass:
   - DLL version **310.x or newer** (the game's bundled one is older);
   - preset **not** a CNN letter the game shipped (the override reports the
     latest transformer preset).
   Frame Generation's indicator is at the top of the screen.
5. Check the log:

   ```bash
   grep -a -E 'Build v|Loaded from path|DlssAvailable|DLSSEnable' ~/steam-<appid>-*.log
   ```

   You want `Build v310.x`, `Loaded from path "c:\windows\system32\umu/nvngx_dlss.dll"`
   (Proton-CachyOS's download, not the game's bundled copy) and
   `DlssAvailable = 1`. Unreal titles also log `DLSSEnable set to: 0/1` —
   `0` means the in-game toggle did not stick.
   Steam app IDs: ACC `805550`, AC EVO `3058630`, AC `244210`.
6. Once it passes, trim the launch options to `nvrun %command%`.

### Smooth Motion test

Only on a title that is GPU-bound at 5120x1440; AC on this card is not.

1. In the game, turn native DLSS Frame Generation **off**. Stacking both
   halves the gain and smears.
2. Launch options: `MANGOHUD=1 nvrun --smooth %command%` (`mangohud` is not
   installed; `sudo pacman -S mangohud`, or skip it and judge by eye).
3. VRR is `on-demand` in niri, so the generated frames land on the panel
   directly. Judge it with the wheel in hand: the FPS number doubles but input
   latency stays that of the base frame rate. Artefacts show around the HUD
   and the car. If it does not feel better, drop the flag.
4. It also works in the `gamescope-session` couch mode, same launch options.

### If something fails

- Game crashes at start with the override: `nvrun --no-dlss %command%`, then
  report with the log.
- Indicator never appears: NVAPI is off. Confirm Proton-CachyOS is selected
  (GE-Proton needs the force the wrapper already sets; Valve's needs
  `PROTON_ENABLE_NVAPI`, also set).
- DLL still old: Proton-CachyOS downloads on first launch and needs network;
  check `~/.local/share/Steam/steamapps/compatdata/<appid>/pfx/drive_c/windows/system32/umu/`.

## Phase 2: Assetto Corsa with Content Manager + CSP

AC is stock today: vanilla launcher, no CSP, no launch options. The Linux
setup repos (`crmne/assetto-corsa-setup`, `sihawido/assettocorsa-linux-setup`)
all: swap `AssettoCorsa.exe` for Content Manager (original kept as
`AssettoCorsa_original.exe`), pin a GE-Proton they download into
`~/.local/share/Steam/compatibilitytools.d/`, install CSP 0.2.x, fonts and
.NET via protontricks.

1. Close Steam. Run the repo's script. First launch afterwards shows nothing
   for several minutes while the prefix builds; wait.
2. Do **not** create a Start Menu shortcut for Content Manager when it asks:
   it crashes CM on startup under Wine.
3. Check Properties → Launch options. If the script wrote its own, keep them
   and prepend the wrapper; otherwise:

   ```
   nvrun --csp %command%
   ```

   `%command%` is now Content Manager, which spawns `acs.exe`. Environment is
   inherited, so the wrapper reaches the renderer. `--csp` adds CSP's
   `dwrite.dll` override; if the script's protonfix already sets it, the
   duplicate is harmless.
4. Leave AC on the GE-Proton the script chose. If it refuses to start, switch
   to Proton-CachyOS and retry: both read every variable the wrapper sets.
5. Verify: CM opens, Settings → Custom Shaders Patch shows a version, a
   session starts with the CSP overlay visible, and the wheel still has force
   feedback (`fftest` if in doubt, see `gaming.md`). Steam Input must stay
   disabled.
6. If CM crashes opening the Live tab, that is a known CM-under-Wine bug; the
   repos document deleting CM's config folder inside the prefix.

Optional and the real way to get DLSS in AC: **CSP 0.3.0 preview** (Patreon
only) adds DLSS Super Resolution; the `ac-dlssg` mod adds DLSS Frame
Generation on top. Neither is verified under Proton. With Phase 1's override
active, that DLSS would get the transformer model too.

## Phase 3: DLSS 5 on Assetto Corsa

Read before starting:

- DLSS 5 is 3D-guided neural rendering (relighting and materials), not an
  upscaler. NVIDIA ships it for RTX 50 only; Ada support is announced, not
  released. No Linux driver carries `nvngx_dlssnr.dll`.
- The community route uses a **leaked NVIDIA binary**, in a **patched,
  unsigned** build (ShortFuse `310.8.SF-v2`) that bypasses the Ada hardware
  check. NVIDIA supports none of it. Expect roughly 40% of the frame rate
  gone. These dotfiles do not download it; this phase is manual on purpose.
- AC has no DLSS, so the model gets no engine depth or motion vectors. The
  ReShade "feeder" fakes them from ReShade's depth buffer and a motion shader.
  Text softens, foliage smears. It is a demo of the model, not an upgrade.
- Verified by the route's author on an RTX 4080, driver 610.57, GE-Proton
  11-3, on other DX11 titles without DLSS. Not on AC. AC is the experiment.

Prerequisites: Phase 2 done and working; `7zip`, `unzip`, `curl` present
(they are).

1. Clone into a scratch directory, not into the dotfiles:

   ```bash
   mkdir -p ~/src && cd ~/src
   git clone https://github.com/24high/DLSS5-Reshade-Linux-Steam
   cd DLSS5-Reshade-Linux-Steam
   ```

2. Install against **`acs.exe`**, the renderer. Not `AssettoCorsa.exe`, which
   is Content Manager now:

   ```bash
   ./dlss5-install.sh --model rtx40 --mode nr \
     ~/.local/share/Steam/steamapps/common/assettocorsa/acs.exe
   ```

   It drops ReShade's `dxgi.dll` and add-ons next to `acs.exe`, a real
   `d3dcompiler_47.dll`, and a fake `DriverStore` with the NGX core files into
   the prefix. It backs up what it replaces; `--uninstall` restores.
3. Launch options:

   ```
   nvrun --csp --nr %command%
   ```

   `--nr` forces NVAPI and loads the game-folder `dxgi.dll`; without that
   override ReShade never runs. CSP's `dwrite.dll` and ReShade's `dxgi.dll`
   are different hooks and coexist, as on Windows.
4. Start a session. Press **Home** for the ReShade overlay → Home tab →
   enable **`vort_MotionEffects`** (the motion-vector shader `nr` mode needs).
   Add-ons tab: the neural-rendering toggle is off by default; turn it on.
5. Quit and verify from the log:

   ```bash
   ./check-dlss5.sh ~/.local/share/Steam/steamapps/common/assettocorsa/acs.exe
   ```

   It reports dispatch counts and which `nvngx_dlssnr` hash loaded.
6. Judge it with the car stationary first (lighting and materials), then
   moving (smearing). Compare `--mode dlaa` (super resolution at native res,
   the more mature pipeline) if `nr` dies on the `E5017 … fastopt` shader
   error.

Maintenance and exits:

- **After every NVIDIA driver update** re-run the installer: the fake
  DriverStore holds NGX files from the old driver.
- `--smooth` can be stacked on `--nr` (Smooth Motion is a present-time layer).
- To remove: `./dlss5-install.sh --uninstall …/acs.exe` and drop `--nr`.
- When NVIDIA ships Ada support in the Linux driver, the same tooling prefers
  the driver's own `nvngx_dlssnr.dll`: rerun with `--model auto`.

## Sources

- NVIDIA, Linux driver guide: DLSS / Smooth Motion / Reflex —
  <https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/gaming.html>
- Proton-CachyOS README (`PROTON_DLSS_UPGRADE`, `PROTON_DLSS_INDICATOR`,
  OptiScaler) — <https://github.com/CachyOS/proton-cachyos>
- NVIDIA, DLSS 5 announcement —
  <https://nvidianews.nvidia.com/news/nvidia-dlss-5-delivers-ai-powered-breakthrough-in-visual-fidelity-for-games>
- DLSS 5 on Linux, ReShade route — <https://github.com/24high/DLSS5-Reshade-Linux-Steam>
- DLSS 5 on Linux, route picker/verifier — <https://github.com/pantsoftime/dlss5-linux>
- AC on Linux setup — <https://github.com/crmne/assetto-corsa-setup>,
  <https://github.com/sihawido/assettocorsa-linux-setup>
- `ac-dlssg` (DLSS FG for CSP) —
  <https://www.overtake.gg/downloads/ac-dlssg-dlss-frame-generation-for-assetto-corsa-csp.87821/>
