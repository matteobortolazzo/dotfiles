#!/usr/bin/env python3
"""Run bootstrap scripts with temporary homes and no network or host changes."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from check_config import render


FAKE_CURL = r'''
import json
import os
from pathlib import Path
import sys

url = sys.argv[-1]
with open(os.environ["BOOTSTRAP_CALLS"], "a") as log:
    log.write(json.dumps(url) + "\n")
if os.environ.get("FAIL_DOWNLOAD") == url:
    sys.exit(22)
binary = {
    "https://herdr.dev/install.sh": "herdr",
    "https://releases.herdr.dev/core/install.sh": "herdr-core",
    "https://releases.herdr.dev/app/install.sh": "herdr-app",
}[url]
print('mkdir -p "$HOME/.local/bin"')
print("printf '#!/bin/sh\\nexit 0\\n' > \"$HOME/.local/bin/" + binary + '"')
print('chmod +x "$HOME/.local/bin/' + binary + '"')
'''

FAKE_TAILSCALE = r'''
import json
import os
from pathlib import Path
import sys

state = Path(os.environ["SSH_TEST_STATE"])
if sys.argv[1:] != ["debug", "prefs"]:
    sys.exit("unexpected tailscale command")
if os.environ.get("FAIL_PREFS"):
    sys.exit(1)
print(json.dumps({"RunSSH": state.exists()}))
'''

FAKE_SUDO = r'''
import os
from pathlib import Path
import sys

if sys.argv[1:] != ["tailscale", "set", "--ssh"]:
    sys.exit("unexpected privileged command")
Path(os.environ["SSH_TEST_STATE"]).touch()
'''


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "tools"
        self.bin.mkdir()
        # Avoid picking up the real installed herdr or sudo from the test host.
        for name in ("sh", "mkdir", "chmod", "jq"):
            (self.bin / name).symlink_to(shutil.which(name))
        self.env = {**os.environ, "HOME": str(self.root), "PATH": str(self.bin),
                    "BOOTSTRAP_CALLS": str(self.root / "calls"),
                    "SSH_TEST_STATE": str(self.root / "ssh-enabled")}

    def fake(self, name, source):
        path = self.bin / name
        path.write_text(f"#!{sys.executable}\n" + source)
        path.chmod(0o755)

    def run_script(self, name, profile="main", **roles):
        return subprocess.run([shutil.which("bash")],
                              input=render(name, profile, **roles),
                              text=True, capture_output=True, env=self.env)

    def test_herdr_installs_core_without_gui_on_headless_and_wsl(self):
        self.fake("curl", FAKE_CURL)
        for profile, roles, gui in (
            ("main", {"headless": True}, False), ("wsl", {}, False),
            ("main", {}, True), ("mac", {"macMode": "minimal"}, True),
            ("mac", {"macMode": "full-dev"}, True),
        ):
            with self.subTest(profile=profile, roles=roles):
                installed = self.root / ".local/bin"
                if installed.exists():
                    shutil.rmtree(installed)
                result = self.run_script("run_onchange_after_43-herdr.sh.tmpl", profile, **roles)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue((installed / "herdr").is_file())
                self.assertTrue((installed / "herdr-core").is_file())
                self.assertEqual((installed / "herdr-app").exists(), gui)
                calls = (self.root / "calls").read_text()
                result = self.run_script("run_onchange_after_43-herdr.sh.tmpl", profile, **roles)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((self.root / "calls").read_text(), calls)

    def test_failed_core_download_is_retryable(self):
        self.fake("curl", FAKE_CURL)
        self.env["FAIL_DOWNLOAD"] = "https://releases.herdr.dev/core/install.sh"
        result = self.run_script("run_onchange_after_43-herdr.sh.tmpl", headless=True)
        self.assertNotEqual(result.returncode, 0)
        del self.env["FAIL_DOWNLOAD"]
        result = self.run_script("run_onchange_after_43-herdr.sh.tmpl", headless=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / ".local/bin/herdr-core").exists())

    def test_tailscale_ssh_is_native_linux_baseline_and_idempotent(self):
        self.fake("tailscale", FAKE_TAILSCALE)
        self.fake("sudo", FAKE_SUDO)
        state = Path(self.env["SSH_TEST_STATE"])
        for profile in ("mac", "wsl", "main"):
            result = self.run_script("run_onchange_after_24-tailscale-ssh.sh.tmpl", profile)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(state.exists(), profile == "main")
        # A host that already enables SSH must not need sudo on later applies.
        (self.bin / "sudo").unlink()
        result = self.run_script("run_onchange_after_24-tailscale-ssh.sh.tmpl")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_unreadable_tailscale_state_does_not_attempt_privileged_change(self):
        self.fake("tailscale", FAKE_TAILSCALE)
        self.fake("sudo", FAKE_SUDO)
        self.env["FAIL_PREFS"] = "1"
        result = self.run_script("run_onchange_after_24-tailscale-ssh.sh.tmpl")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(Path(self.env["SSH_TEST_STATE"]).exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
