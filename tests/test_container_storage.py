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
        self.entries.append(dict(source="UUID=disk", target=str(path), fstype="btrfs", options="rw,subvol=" + subvol))

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

    def test_migrated_mount_with_wrong_persistent_type_aborts(self):
        self.dedicated(self.paths[0])
        self.entries[0]["fstype"] = "ext4"
        with self.assertRaisesRegex(RuntimeError, "fstab"):
            self.plan()

    def test_relative_subvolume_path_reuses_migrated_mount(self):
        self.dedicated(self.paths[0])
        self.entries[0]["options"] = "rw,subvol=@docker-20261121"
        self.assertEqual(self.plan(), self.paths[1:])

    def simulate_provision(self, failure=None):
        base = self.paths[0].parent
        fstab = base / "fstab"
        fstab.write_text("# existing entries\n")
        stage = base / "top"
        stage.mkdir()
        mounted = []
        units = base / "systemd"
        units.mkdir()
        (units / "docker.socket").symlink_to("/dev/null")
        def state(*args):
            if "LoadState" in args:
                if failure == "ineffective mask" and args[-1] == "docker.service":
                    return "loaded"
                return "masked" if (units / args[-1]).is_symlink() else "loaded"
            if failure == "active unit" and args[-1] == "containerd.service":
                return "active"
            return "inactive"

        def command(argv, check):
            if argv[:3] == ["btrfs", "subvolume", "create"]:
                argv[3].mkdir()
            elif argv == ["umount", stage]:
                # Model unmounting: the backing directories are no longer visible.
                stage.rename(base / "disk")
                stage.mkdir()
            elif argv[:2] == ["findmnt", "--verify"]:
                self.assertIn("# existing entries", Path(argv[-1]).read_text())
            elif argv[0] == "mount" and argv[-1] in self.paths:
                path = argv[-1]
                self.assertTrue(all((units / name).is_symlink() for name in
                                    ("docker.socket", "docker.service", "containerd.service")))
                self.assertEqual(fstab.read_text(), "# existing entries\n")
                self.assertTrue((base / "disk" / ("@" + path.name)).is_dir())
                mounted.append(path)
                self.mounts[path].update(target=str(path), fsroot="/@" + path.name)
                if path == self.paths[0] and failure == "new data":
                    (self.paths[1] / "inventory").touch()
                if failure == "wrong mount":
                    self.mounts[path]["fsroot"] = "/@unexpected"
            elif argv[0] == "umount":
                mounted.remove(argv[1])
        with patch.object(storage, "UNIT_DIR", units), patch.object(storage, "FSTAB", fstab), patch.object(storage, "output", side_effect=state), \
             patch.object(storage.tempfile, "mkdtemp", return_value=stage), patch.object(storage.subprocess, "run", side_effect=command):
            if failure:
                with self.assertRaises(RuntimeError):
                    storage.provision(self.plan(), self.root)
            else:
                storage.provision(self.plan(), self.root)
        self.assertEqual(list(units.iterdir()), [units / "docker.socket"])
        return mounted, fstab.read_text()

    def test_fresh_provisioning_installs_verified_table_and_mounts_both_stores(self):
        mounted, table = self.simulate_provision()
        self.assertEqual(mounted, self.paths)
        for path in self.paths:
            self.assertIn(f"UUID=disk {path} btrfs subvol=/@{path.name},", table)

    def test_new_data_in_second_store_aborts_without_boot_entries(self):
        self.assertEqual(self.simulate_provision("new data"), ([], "# existing entries\n"))
        self.assertTrue((self.paths[1] / "inventory").is_file())

    def test_unexpected_live_mount_aborts_without_boot_entries(self):
        self.assertEqual(self.simulate_provision("wrong mount"), ([], "# existing entries\n"))

    def test_active_unit_aborts_before_creating_stores(self):
        self.assertEqual(self.simulate_provision("active unit"), ([], "# existing entries\n"))
        self.assertFalse(any(path.exists() for path in self.paths))

    def test_ineffective_mask_aborts_before_creating_stores(self):
        self.assertEqual(self.simulate_provision("ineffective mask"), ([], "# existing entries\n"))
        self.assertFalse(any(path.exists() for path in self.paths))

    def test_profile_and_daemon_defaults(self):
        template = "run_once_after_23-container-storage.sh.tmpl"
        self.assertIn("NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=3", render(template))
        for profile in ("mac", "wsl"):
            self.assertNotIn("sudo", render(template, profile))
        cfg = json.loads((ROOT / "system/docker/daemon.json").read_text())
        self.assertEqual(cfg["builder"]["gc"], {"enabled": True, "defaultKeepStorage": "20GB"})
        self.assertEqual(cfg["ip"], "127.0.0.1")
        self.assertEqual(cfg["runtimes"]["sysbox-runc"]["path"], "/usr/bin/sysbox-runc")
