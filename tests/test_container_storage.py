import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from check_config import render

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("storage", ROOT / "system/docker/storage.py")
storage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(storage)


class StorageTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.paths = [Path(tmp.name) / name for name in ("docker", "containerd")]
        self.root = dict(target="/", uuid="disk", fsroot="/@", fstype="btrfs")
        self.mounts = {p: self.root.copy() for p in self.paths}
        self.entries = []
        mock = patch.object(storage, "live", side_effect=self.mounts.__getitem__)
        mock.start()
        self.addCleanup(mock.stop)

    def plan(self):
        return storage.plan(self.paths, self.root, self.entries)

    def dedicated(self, path):
        subvol = "/@" + path.name + "-20261121"
        self.mounts[path].update(target=str(path), fsroot=subvol)
        self.entries.append(dict(source="UUID=disk", target=str(path), options="rw,subvol=" + subvol))

    def test_fresh_dirs(self):
        self.paths[0].mkdir()
        self.assertEqual(self.plan(), self.paths)

    def test_populated_store_aborts_before_provisioning(self):
        self.paths[1].mkdir()
        (self.paths[1] / ".data").touch()
        with self.assertRaisesRegex(RuntimeError, "maintenance"):
            self.plan()
        self.assertFalse(self.paths[0].exists())

    def test_migrated_mounts_and_mixed_layout(self):
        self.dedicated(self.paths[0])
        self.assertEqual(self.plan(), self.paths[1:])
        self.dedicated(self.paths[1])
        self.assertEqual(self.plan(), [])

    def test_wrong_or_unmounted_fstab_aborts(self):
        path = self.paths[0]
        self.dedicated(path)
        for mount in (dict(self.mounts[path], fsroot="/@other"), self.root):
            self.mounts[path] = mount
            with self.assertRaises(RuntimeError):
                self.plan()

    def test_fresh_provisioning_installs_verified_table_and_mounts_both_stores(self):
        base = self.paths[0].parent
        fstab = base / "fstab"
        fstab.write_text("# existing entries\n")
        stage = base / "top"
        stage.mkdir()
        mounted = []
        def command(argv, check):
            if argv[:3] == ["btrfs", "subvolume", "create"]:
                argv[3].mkdir()
            elif argv[:1] == ["umount"]:
                # Model unmounting: the backing directories are no longer visible.
                stage.rename(base / "disk")
                stage.mkdir()
            elif argv[:2] == ["findmnt", "--verify"]:
                self.assertIn("# existing entries", Path(argv[-1]).read_text())
            elif argv[0] == "mount" and len(argv) == 2:
                path = argv[1]
                self.assertIn(f"UUID=disk {path} btrfs subvol=/@{path.name},", fstab.read_text())
                self.assertTrue((base / "disk" / ("@" + path.name)).is_dir())
                mounted.append(path)
        with patch.object(storage, "FSTAB", fstab), patch.object(storage, "output", return_value="inactive"), \
             patch.object(storage.tempfile, "mkdtemp", return_value=stage), patch.object(storage.subprocess, "run", side_effect=command):
            storage.provision(self.plan(), self.root)
        self.assertEqual(mounted, self.paths)

    def test_profile_and_daemon_defaults(self):
        template = "run_once_after_23-container-storage.sh.tmpl"
        self.assertIn("NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=3", render(template))
        for profile in ("mac", "wsl"):
            self.assertNotIn("sudo", render(template, profile))
        cfg = json.loads((ROOT / "system/docker/daemon.json").read_text())
        self.assertEqual(cfg["builder"]["gc"], {"enabled": True, "defaultKeepStorage": "20GB"})
        self.assertEqual(cfg["ip"], "127.0.0.1")
        self.assertEqual(cfg["runtimes"]["sysbox-runc"]["path"], "/usr/bin/sysbox-runc")
