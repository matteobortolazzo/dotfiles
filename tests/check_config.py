#!/usr/bin/env python3
"""Render all supported profiles without installing anything or reading secrets.

Run with python3 tests/check_config.py (requires chezmoi, bash and zsh).
"""
import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]


def render(path, profile="main", init=False, **roles):
    data = {
        "profile": profile, "org": "", "devHost": "", "devUser": "",
        "chezmoi": {"os": "darwin" if profile == "mac" else "linux",
                    "osRelease": {"id": "arch" if profile == "wsl" else "cachyos"}},
        **roles,
    }
    return subprocess.run(
        ["chezmoi", "--source", str(ROOT), "--config", "/dev/null",
         "--config-format", "toml", "--override-data", json.dumps(data),
         "--no-tty", "execute-template", *(["--init"] if init else []),
         "--file", str(ROOT / path)],
        check=True, capture_output=True, text=True,
    ).stdout


class ConfigTests(unittest.TestCase):
    def test_profile_target_selection(self):
        with tempfile.TemporaryDirectory() as tmp:
            op = Path(tmp) / "op"
            op.write_text("#!/bin/sh\nexit 1\n")
            op.chmod(0o755)
            env = {**os.environ, "PATH": tmp + os.pathsep + os.environ["PATH"]}
            for profile, gaming in ((p, g) for p in ("main", "mac", "wsl")
                                    for g in (False, True)):
                data = {"profile": profile, "org": "", "devHost": "",
                        "gaming": gaming,
                        "chezmoi": {"os": "darwin" if profile == "mac" else "linux"}}
                result = subprocess.run(
                    ["chezmoi", "--source", str(ROOT), "--config", "/dev/null",
                     "--config-format", "toml", "--override-data", json.dumps(data),
                     "--skip-secrets", "managed"],
                    check=True, capture_output=True, text=True, env=env,
                )
                targets = result.stdout.splitlines()
                self.assertNotIn("tests/check_config.py", targets)
                self.assertNotIn(".config/environment", targets)
                self.assertEqual(".config/dms/settings.json" in targets, profile == "main")
                self.assertEqual(".config/ghostty/config" in targets, profile != "wsl")
                self.assertEqual(".config/niri/config.kdl" in targets, profile == "main")
                self.assertEqual(".config/sunshine" in targets, profile == "main" and gaming)

    def test_scripts_render_and_parse_for_all_profiles(self):
        for profile, roles in [
            ("main", {}), ("main", {"tuxedo": True}),
            ("main", dict(gaming=True, headless=True, ups=True, deck=True)),
            ("mac", {}), ("mac", {"macMode": "minimal"}),
            ("mac", {"macMode": "full-dev"}), ("wsl", {}),
        ]:
            for path in sorted(ROOT.glob("run_*.tmpl")):
                with self.subTest(profile=profile, roles=roles, script=path.name):
                    script = render(path.name, profile, **roles)
                    subprocess.run(["bash", "-n"], input=script, text=True, check=True)
                    if profile == "mac":
                        self.assertNotIn("sudo pacman", script)
                        self.assertNotIn("sudo systemctl", script)
            subprocess.run(["zsh", "-n"], input=render("dot_zshrc.tmpl", profile, **roles),
                           text=True, check=True)

    def test_init_retires_dev_and_limits_hardware_prompts(self):
        native_roles = dict(gaming=True, headless=True, ups=True, deck=True, tuxedo=True)
        for profile in ("main", "mac", "wsl"):
            # Missing answers on Mac/WSL must not prompt for Linux hardware.
            roles = native_roles if profile == "main" else ({"macMode": "minimal"} if profile == "mac" else {})
            for legacy in ({}, {"dev": False}, {"dev": True}):
                with self.subTest(profile=profile, legacy=legacy):
                    config = tomllib.loads(render(".chezmoi.toml.tmpl", profile,
                                                  init=True, **roles, **legacy))
                    self.assertNotIn("dev", config["data"])
                    for role in native_roles:
                        self.assertEqual(config["data"][role], profile == "main")
                    self.assertIn("devHost", config["data"])
                    self.assertIn("devUser", config["data"])

    def test_minimal_mac_keeps_node_but_skips_general_toolchains(self):
        for name in ("33-rustup", "34-dotnet", "40-aspire", "44-lazyboards"):
            path = "run_onchange_after_" + name + ".sh.tmpl"
            minimal = render(path, "mac", macMode="minimal")
            executable = [line for line in minimal.splitlines()
                          if line.strip() and not line.startswith("#")]
            self.assertEqual(executable, [])
            self.assertEqual(render(path, "mac"), render(path, "mac", macMode="full-dev"))
            self.assertIn("set -euo pipefail", render(path, "main", macMode="minimal"))
        minimal = render("run_onchange_after_35-npm-globals.sh.tmpl", "mac", macMode="minimal")
        self.assertIn("fnm install --lts", minimal)
        self.assertNotIn("npm install -g", minimal)
        shell = render("dot_zshrc.tmpl", "mac", macMode="minimal")
        self.assertIn("export EDITOR=vi", shell)
        self.assertNotIn("ANDROID_HOME", shell)
        self.assertNotIn("DOTNET_ROOT", shell)
        self.assertIn("fnm env", shell)

    def test_mac_mode_init_and_installer(self):
        for mode in ("minimal", "full-dev"):
            config = tomllib.loads(render(".chezmoi.toml.tmpl", "mac", init=True, macMode=mode))
            self.assertEqual(config["data"]["macMode"], mode)
            script = render("run_onchange_before_05-homebrew.sh.tmpl", "mac", macMode=mode)
            self.assertIn('export HOMEBREW_CHEZMOI_MAC_MODE="' + mode + '"', script)
            self.assertNotIn("uninstall", script.split("brewfile=")[-1])

    @unittest.skipUnless(shutil.which("brew"), "Homebrew is not installed")
    def test_homebrew_reads_selected_mode(self):
        selected = {}
        for mode in ("minimal", "full-dev"):
            selected[mode] = set(subprocess.check_output(
                ["brew", "bundle", "list", "--all", "--file=" + str(ROOT / "packages/Brewfile")],
                text=True, env={**os.environ, "HOMEBREW_NO_AUTO_UPDATE": "1",
                                "HOMEBREW_CHEZMOI_MAC_MODE": mode},
            ).splitlines())
        self.assertTrue({"fnm", "zen", "libimobiledevice", "chezmoi"} <= selected["minimal"])
        self.assertTrue({"docker-desktop", "temurin@21", "go", "neovim"} <=
                        selected["full-dev"] - selected["minimal"])
        self.assertTrue(selected["minimal"] < selected["full-dev"])

    def test_ssh_and_firewall_are_native_baseline(self):
        for path, required in (("run_once_after_27-sshd.sh.tmpl", "enable --now sshd.service"),
                               ("run_once_after_28-firewall.sh.tmpl", "sudo ufw allow")):
            for profile in ("main", "mac", "wsl"):
                baseline = render(path, profile)
                self.assertEqual(baseline, render(path, profile, dev=False))
                self.assertEqual(baseline, render(path, profile, dev=True))
                self.assertEqual(required in baseline, profile == "main")
        self.assertIn("-setremotelogin on", render("run_once_after_27-sshd.sh.tmpl", "mac"))
        self.assertNotIn("sunshine control", render("run_once_after_28-firewall.sh.tmpl"))
        self.assertIn("sunshine control", render("run_once_after_28-firewall.sh.tmpl", gaming=True))

    def test_stale_wsl_roles_do_not_install_native_hardware(self):
        for path, shared in (("run_onchange_before_10-pacman.sh.tmpl", "arch-terminal.txt"),
                             ("run_onchange_before_21-aur.sh.tmpl", "arch-aur-terminal.txt")):
            script = render(path, "wsl", gaming=True, ups=True, tuxedo=True, deck=True)
            self.assertIn(shared, script)
            for manifest in ("arch-gaming.txt", "arch-aur-gaming.txt", "arch-ups.txt",
                             "arch-aur-tuxedo.txt", "arch-dev.txt"):
                self.assertNotIn(manifest, script)

    def test_tuxedo_is_opt_in_and_headers_precede_aur(self):
        self.assertNotIn("sudo", render("run_onchange_after_24-tuxedo.sh.tmpl"))
        self.assertIn("tccd.service", render("run_onchange_after_24-tuxedo.sh.tmpl", tuxedo=True))
        self.assertIn("${kernel}-headers", render("run_onchange_before_10-pacman.sh.tmpl", tuxedo=True))
        self.assertNotIn("enable_unit power-profiles-daemon.service",
                         render("run_once_after_24-services.sh.tmpl", tuxedo=True))

    def test_dms_migration_preserves_user_data(self):
        script = render("run_once_before_04-dms-paths.sh.tmpl")
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            for key in ("XDG_CONFIG_HOME", "XDG_STATE_HOME", "XDG_DATA_HOME"):
                base = Path(tmp) / key
                (base / "DankMaterialShell").mkdir(parents=True)
                (base / "DankMaterialShell/settings.json").write_text('{"custom": true}')
                env[key] = str(base)
            subprocess.run(["bash"], input=script, text=True, env=env, check=True)
            for key in ("XDG_CONFIG_HOME", "XDG_STATE_HOME", "XDG_DATA_HOME"):
                base = Path(env[key])
                self.assertEqual((base / "dms/settings.json").read_text(), '{"custom": true}')
                if key == "XDG_CONFIG_HOME":
                    backups = list(base.glob("DankMaterialShell.backup.*/DankMaterialShell/settings.json"))
                    self.assertEqual(len(backups), 1)
                    self.assertEqual(backups[0].read_text(), '{"custom": true}')
                else:
                    self.assertTrue((base / "DankMaterialShell/settings.json").is_file())
                (base / "dms/settings.json").write_text('{"newer": true}')
            subprocess.run(["bash"], input=script, text=True, env=env, check=True)
            self.assertEqual((Path(env["XDG_CONFIG_HOME"]) / "dms/settings.json").read_text(),
                             '{"newer": true}')

    def test_structured_configs(self):
        for path in ROOT.glob("dot_config/**/*.json"):
            with self.subTest(path=path):
                json.loads(path.read_text())
        for path in ROOT.glob("dot_config/**/*.toml"):
            with self.subTest(path=path):
                tomllib.loads(path.read_text())

    @unittest.skipUnless(shutil.which("niri"), "niri is not installed")
    def test_niri_config(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "config.kdl"
            config.write_text((ROOT / "dot_config/niri/config.kdl").read_text())
            (Path(tmp) / "dms").mkdir()
            (Path(tmp) / "dms/outputs.kdl").write_text(
                (ROOT / "dot_config/niri/dms/create_outputs.kdl").read_text())
            subprocess.run(["niri", "validate", "--config", str(config)],
                           check=True, capture_output=True, text=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
