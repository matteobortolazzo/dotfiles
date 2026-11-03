"""Exercise a real chezmoi apply with a fake op; never access real credentials."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class OnePasswordTests(unittest.TestCase):
    def apply_fixture(self, *, signin=0, vault=0, existing=True):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            source, dest, binaries = (base / name for name in ("source", "home", "bin"))
            for directory in (source / "dot_config", dest / ".config", binaries):
                directory.mkdir(parents=True)
            shutil.copyfile(ROOT / ".chezmoiignore", source / ".chezmoiignore")
            shutil.copyfile(ROOT / "dot_config/private_environment.tmpl",
                            source / "dot_config/private_environment.tmpl")
            # Prove that a failed auth probe still reaches after-scripts.
            (source / "run_after_marker.sh.tmpl").write_text(
                '#!/bin/sh\nprintf done > "{{ .chezmoi.destDir }}/after-marker"\n')
            target = dest / ".config/environment"
            original = "export KEEP_EXISTING='unchanged'\n"
            if existing:
                target.write_text(original)
                target.chmod(0o600)
            op = binaries / "op"
            op.write_text("""#!/bin/sh
if [ "$1" = --session ]; then shift 2; fi
case "$1" in
  --version) printf '2.41.1\\n' ;;
  signin)
    # Print even on failure to check that probe output never leaks.
    printf 'FAKE_SIGNIN_OUTPUT\\n'
    exit "$TEST_SIGNIN_STATUS" ;;
  vault) printf '[]\\n'; exit "$TEST_VAULT_STATUS" ;;
  read) printf '%s' 'fake value with $dollar and "quotes"' ;;
  *) exit 90 ;;
esac
""")
            op.chmod(0o755)
            config = base / "config.json"
            config.write_text(json.dumps({
                "data": {"profile": "main", "org": "test-org"},
                "onepassword": {"mode": "account", "command": str(op), "prompt": True},
            }))
            env = {k: v for k, v in os.environ.items() if not k.startswith("OP_")}
            env.update(PATH=str(binaries) + os.pathsep + env["PATH"],
                       TEST_SIGNIN_STATUS=str(signin), TEST_VAULT_STATUS=str(vault))
            result = subprocess.run([
                "chezmoi", "--source", str(source), "--destination", str(dest),
                "--config", str(config), "--persistent-state", str(base / "state.boltdb"),
                "--cache", str(base / "cache"), "--no-tty", "apply",
            ], capture_output=True, text=True, env=env, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("FAKE_SIGNIN_OUTPUT", result.stdout + result.stderr)
            self.assertEqual((dest / "after-marker").read_text(), "done")
            if signin or vault:
                self.assertIn("leaving ~/.config/environment untouched", result.stderr)
                if existing:
                    self.assertEqual(target.read_text(), original)
                else:
                    self.assertFalse(target.exists())
            else:
                self.assertIn("export AZURE_DEVOPS_EXT_PAT=", target.read_text())
                self.assertEqual(target.stat().st_mode & 0o777, 0o600)
                quoted = subprocess.run(
                    ["sh", "-c", '. "$1"; printf "%s" "$OPENAI_API_KEY"', "sh", str(target)],
                    capture_output=True, text=True, check=True,
                )
                self.assertEqual(quoted.stdout, 'fake value with $dollar and "quotes"')

    def test_vault_list_success_cannot_hide_signin_failure(self):
        self.apply_fixture(signin=1)

    def test_unavailable_app_does_not_create_empty_environment(self):
        self.apply_fixture(signin=1, existing=False)

    def test_signin_success_still_requires_vault_access(self):
        self.apply_fixture(vault=1)

    def test_available_app_updates_private_shell_quoted_environment(self):
        self.apply_fixture()


if __name__ == "__main__":
    unittest.main(verbosity=2)
