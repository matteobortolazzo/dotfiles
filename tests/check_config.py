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


def render(path, profile="main", **roles):
    data = {
        "profile": profile, "org": "", "devHost": "", "devUser": "",
        "chezmoi": {"os": "darwin" if profile == "mac" else "linux",
                    "osRelease": {"id": "arch" if profile == "wsl" else "cachyos"}},
        **roles,
    }
    return subprocess.run(
        ["chezmoi", "--source", str(ROOT), "--config", "/dev/null",
         "--config-format", "toml", "--override-data", json.dumps(data),
         "execute-template", "--file", str(ROOT / path)],
        check=True, capture_output=True, text=True,
    ).stdout


class ConfigTests(unittest.TestCase):
    def test_profile_target_selection(self):
        with tempfile.TemporaryDirectory() as tmp:
            op = Path(tmp) / "op"
            op.write_text("#!/bin/sh\nexit 1\n")
            op.chmod(0o755)
            env = {**os.environ, "PATH": tmp + os.pathsep + os.environ["PATH"]}
            for profile in ("main", "mac", "wsl"):
                data = {"profile": profile, "org": "", "devHost": "",
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

    def test_scripts_render_and_parse_for_all_profiles(self):
        for profile, roles in [
            ("main", {}), ("main", {"tuxedo": True}),
            ("main", dict(gaming=True, dev=True, headless=True, ups=True, deck=True)),
            ("mac", {}), ("wsl", {}),
        ]:
            for path in sorted(ROOT.glob("run_*.tmpl")):
                with self.subTest(profile=profile, roles=roles, script=path.name):
                    script = render(path.name, profile, **roles)
                    subprocess.run(["bash", "-n"], input=script, text=True, check=True)
                    if profile == "mac":
                        self.assertNotIn("sudo pacman", script)
                        self.assertNotIn("sudo systemctl", script)
            subprocess.run(["zsh", "-n"], input=render("dot_zshrc.tmpl", profile),
                           text=True, check=True)

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
