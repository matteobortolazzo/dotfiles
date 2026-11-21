"""Provision empty Docker stores on Btrfs before enabling socket activation."""
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

STORES = [Path("/var/lib/docker"), Path("/var/lib/containerd")]
FSTAB = Path("/etc/fstab")


def output(*args):
    return subprocess.check_output(args, text=True).strip()


def table(*args):
    return json.loads(output("findmnt", "--json", "--list", *args))["filesystems"]


def live(path):
    # findmnt -T needs an existing path, including on a pristine install.
    query = path if path.exists() else path.parent
    return table("-T", query, "-o", "TARGET,FSTYPE,UUID,FSROOT")[0]


def plan(paths, root, entries):
    fresh = []
    seen = set()
    for path in paths:
        if path.resolve() != path:
            raise RuntimeError(f"Unexpected symlink at {path}")
        mount = live(path)
        rows = [r for r in entries if r["target"] == str(path)]
        if mount["target"] == str(path):
            identity = mount["uuid"], mount["fsroot"]
            options = rows[0]["options"].split(",") if len(rows) == 1 else []
            if (mount["fstype"] == "btrfs" and mount["uuid"] and
                    identity != (root["uuid"], root["fsroot"]) and identity not in seen and
                    len(rows) == 1 and rows[0]["source"] == "UUID=" + mount["uuid"] and
                    not {"noauto", "nofail", "bind", "ro"}.intersection(options) and
                    "subvol=" + mount["fsroot"] in options):
                seen.add(identity)
                continue
            raise RuntimeError(f"Verify dedicated mount and fstab entry for {path}")
        if (rows or mount != root or
                (path.exists() and (not path.is_dir() or path.stat().st_ino == 256 or any(path.iterdir())))):
            raise RuntimeError(f"{path} needs offline maintenance. See the Docker section of README.md")
        fresh.append(path)
    return fresh


def write_fstab(entries):
    original = FSTAB.read_bytes()
    with tempfile.NamedTemporaryFile(dir=FSTAB.parent, delete=False) as handle:
        candidate = Path(handle.name)
    try:
        shutil.copy2(FSTAB, candidate)
        with candidate.open("ab") as handle:
            handle.write(("\n" + "".join(entries)).encode())
            handle.flush()
            os.fsync(handle.fileno())
        subprocess.run(["findmnt", "--verify", "--tab-file", candidate], check=True)
        if FSTAB.read_bytes() != original:
            raise RuntimeError("fstab changed during provisioning")
        candidate.replace(FSTAB)
    finally:
        candidate.unlink(missing_ok=True)


def provision(paths, root):
    source = "UUID=" + root["uuid"]
    for unit in ("docker.socket", "docker.service", "containerd.service"):
        if output("systemctl", "show", "-p", "ActiveState", "--value", unit) != "inactive":
            raise RuntimeError(f"{unit} must be inactive for fresh storage provisioning")
    entries = []
    stage = Path(tempfile.mkdtemp(dir="/run"))
    try:
        subprocess.run(["mount", "-t", "btrfs", "-o", "subvolid=5", source, stage], check=True)
        try:
            for path in paths:
                if os.path.lexists(stage / ("@" + path.name)):
                    raise RuntimeError(f"Existing @{path.name} needs inspection")
            for path in paths:
                name = "@" + path.name
                path.mkdir(mode=0o700, exist_ok=True)
                dest = stage / name
                subprocess.run(["btrfs", "subvolume", "create", dest], check=True)
                dest.chmod(0o700)
                entries.append(f"{source} {path} btrfs subvol=/{name},noatime 0 0\n")
        finally:
            subprocess.run(["umount", stage], check=True)
    finally:
        if not stage.is_mount():
            stage.rmdir()
    write_fstab(entries)
    subprocess.run(["systemctl", "daemon-reload"], check=True)
    for path in paths:
        if live(path) != root or any(path.iterdir()):
            raise RuntimeError(f"Storage changed during setup at {path}")
        subprocess.run(["mount", path], check=True)


def setup():
    root = live(Path("/"))
    if root["fstype"] != "btrfs":
        return
    if not root["uuid"]:
        raise RuntimeError("Missing root Btrfs UUID")
    def pending():
        entries = table("--fstab", "-o", "SOURCE,TARGET,OPTIONS")
        return plan(STORES, root, entries)
    paths = pending()
    if paths:
        provision(paths, root)
        if pending():
            raise RuntimeError("Container storage mounts incomplete")


if __name__ == "__main__":
    with open("/run/chezmoi-container-storage.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        setup()
