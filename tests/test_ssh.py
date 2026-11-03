#!/usr/bin/env python3
"""Check Remote Login setup without invoking sudo or changing host services."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from check_config import render


FAKE_SUDO = r'''
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
state = Path(os.environ["SSH_TEST_STATE"])
with open(os.environ["SSH_TEST_CALLS"], "a") as log:
    log.write(json.dumps(args) + "\n")
if args == ["/usr/sbin/systemsetup", "-getremotelogin"]:
    print("Remote Login: " + ("On" if state.exists() else "Off"))
elif args == ["/usr/sbin/systemsetup", "-setremotelogin", "on"]:
    mode = os.environ["SSH_TEST_MODE"]
    if mode == "success":
        state.touch()
    else:
        print("Turning Remote Login on or off requires Full Disk Access privileges.", file=sys.stderr)
        sys.exit(1 if mode == "error" else 0)
else:
    raise RuntimeError("Unexpected system command: " + repr(args))
'''


class RemoteLoginTests(unittest.TestCase):
    def run_setup(self, mode="success", enabled=False):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sudo = root / "sudo"
            sudo.write_text(f"#!{sys.executable}\n" + FAKE_SUDO)
            sudo.chmod(0o755)
            state = root / "enabled"
            if enabled:
                state.touch()
            calls = root / "calls.jsonl"
            env = {**os.environ, "PATH": tmp + os.pathsep + os.environ["PATH"],
                   "SSH_TEST_STATE": str(state), "SSH_TEST_CALLS": str(calls),
                   "SSH_TEST_MODE": mode}
            result = subprocess.run(["bash"], input=render("run_once_after_27-sshd.sh.tmpl", "mac"),
                                    text=True, capture_output=True, env=env, cwd=tmp)
            return result, state.exists(), [json.loads(line) for line in calls.read_text().splitlines()]

    def test_already_enabled_does_not_toggle_service(self):
        result, enabled, calls = self.run_setup(enabled=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(enabled)
        self.assertEqual(calls, [["/usr/sbin/systemsetup", "-getremotelogin"]])

    def test_enable_is_verified(self):
        result, enabled, calls = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(enabled)
        self.assertEqual(calls, [["/usr/sbin/systemsetup", "-getremotelogin"],
                                 ["/usr/sbin/systemsetup", "-setremotelogin", "on"],
                                 ["/usr/sbin/systemsetup", "-getremotelogin"]])

    def test_permission_failure_requires_retry_even_if_command_returns_zero(self):
        for mode in ("error", "silent-noop"):
            with self.subTest(mode=mode):
                result, enabled, _ = self.run_setup(mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(enabled)
                self.assertIn("System Settings > General > Sharing", result.stderr)
                self.assertIn("rerun chezmoi apply", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
