#!/usr/bin/env python3
"""Preview or perform the full-dev -> minimal Mac cleanup. No third-party Python deps."""
import argparse
import os
from pathlib import Path
import platform
import shlex
import shutil
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def output(args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="execute the printed cleanup")
    parser.add_argument("--simulators", action="store_true", help="delete ALL simulator devices and runtimes")
    parser.add_argument("--docker-data", action="store_true", help="delete ALL local Docker containers, images and volumes")
    args = parser.parse_args()
    if platform.system() != "Darwin" or os.geteuid() == 0:
        parser.error("run as your normal macOS user, not with sudo")
    if args.apply:
        mode = output(["chezmoi", "execute-template", '{{ .profile }}:{{ dig "macMode" "full-dev" . }}'])
        if mode != "mac:minimal":
            parser.error('set profile = "mac" and macMode = "minimal" in chezmoi.toml first')
        # Do not delete caches underneath active builds, IDEs or containers.
        busy = subprocess.run(
            ["pgrep", "-fl", r"Xcode.app/Contents/MacOS/Xcode|xcodebuild|com.docker.backend|GradleDaemon|rustc|cargo build|dotnet build"],
            capture_output=True, text=True,
        )
        if busy.returncode == 0:
            parser.error("close these apps/builds and retry:\n" + busy.stdout)
        if busy.returncode != 1:
            parser.error("could not check for active builds: " + busy.stderr)

    failures = []

    def run(command):
        print(("RUN " if args.apply else "WOULD RUN ") + shlex.join(map(str, command)), flush=True)
        if args.apply:
            result = subprocess.run(command)
            if result.returncode:
                failures.append(shlex.join(map(str, command)))

    home = Path.home()

    def remove(relative):
        path = home / relative
        if not path.exists() and not path.is_symlink():
            return
        # Never follow a cache/toolchain symlink into another location.
        if path.is_symlink() or any(p.is_symlink() for p in path.parents if p != home):
            print("SKIP symlink: " + str(path), flush=True)
            return
        print(("REMOVE " if args.apply else "WOULD REMOVE ") + str(path), flush=True)
        if args.apply:
            try:
                if path.is_dir():
                    # Go module downloads deliberately use read-only directories.
                    # Make only this disposable cache writable before removing it.
                    if relative == "go/pkg":
                        for directory, _, _ in os.walk(path):
                            current = Path(directory)
                            current.chmod(current.stat().st_mode | stat.S_IWUSR)
                    shutil.rmtree(path)
                else:
                    path.unlink()
            except OSError as exc:
                failures.append(str(exc))

    # Only remove entries owned by the full-dev manifest; preserve manually
    # installed tools. Homebrew checks dependencies rather than forcing removal.
    brewfile = str(ROOT / "packages/Brewfile")
    os.environ["HOMEBREW_NO_AUTO_UPDATE"] = "1"
    os.environ["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
    for kind in ("cask", "formula"):
        sets = {}
        for mode in ("minimal", "full-dev"):
            env = {**os.environ, "HOMEBREW_CHEZMOI_MAC_MODE": mode}
            names = output(["brew", "bundle", "list", "--" + kind, "--file=" + brewfile], env=env)
            sets[mode] = set(names.splitlines())
        installed = set(output(["brew", "list", "--" + kind]).splitlines())
        unwanted = sorted(name for name in sets["full-dev"] - sets["minimal"]
                          if name in installed or name.rsplit("/", 1)[-1] in installed)
        if kind == "cask":
            # One failure (e.g. a sudo prompt) should not prevent other removals.
            for name in unwanted:
                run(["brew", "uninstall", "--cask", name])
        elif unwanted:
            run(["brew", "uninstall", "--formula", *unwanted])

    # Remove these large globals from every fnm version, leaving Node and npm
    # available for local Capacitor/web builds and project-owned dependencies.
    for installation in sorted((home / ".local/share/fnm/node-versions").glob("*/installation")):
        node = installation / "bin/node"
        npm = installation / "lib/node_modules/npm/bin/npm-cli.js"
        if node.exists() and npm.exists():
            run([str(node), str(npm), "--prefix", str(installation), "uninstall", "-g",
                 "playwright", "@mermaid-js/mermaid-cli"])

    # Toolchains and generated caches only. Preserve credentials, source trees,
    # Android signing keys, Xcode archives/dSYMs and real-iPhone support files.
    for relative in (
        ".rustup/toolchains", ".rustup/downloads", ".rustup/tmp", ".cargo/bin",
        ".cargo/registry", ".cargo/git", ".dotnet", ".aspire/bin",
        ".nuget/packages", ".local/share/NuGet", "go/pkg", "go/bin/lazyboards",
        "Library/Android/sdk", ".android/avd", ".gradle/caches", ".gradle/wrapper",
        ".gradle/daemon", ".local/share/nvim/mason", ".local/share/nvim/lazy", ".cache/nvim",
        ".cache/puppeteer", "Library/Caches/ms-playwright", "Library/Caches/go-build",
        "Library/Caches/pip", "Library/Caches/node-gyp", ".npm/_cacache", ".npm/_npx",
        "Library/Developer/Xcode/DerivedData", "Library/Caches/org.swift.swiftpm",
        "Library/Application Support/com.docker.install",
    ):
        remove(relative)

    if args.simulators:
        run(["xcrun", "simctl", "shutdown", "all"])
        run(["xcrun", "simctl", "delete", "all"])
        run(["xcrun", "simctl", "runtime", "delete", "all"])

    if args.docker_data:
        # Keep ~/.docker (remote contexts/credentials); only local Desktop data.
        for relative in (
            "Library/Containers/com.docker.docker/Data",
            "Library/Group Containers/group.com.docker",
            "Library/Application Support/Docker Desktop",
            "Library/Caches/com.docker.docker", "Library/Logs/Docker Desktop",
        ):
            remove(relative)

    run(["brew", "autoremove"])
    run(["brew", "cleanup", "--prune=all", "-s"])
    if failures:
        print("\nIncomplete actions (retry after resolving the errors):", file=sys.stderr)
        print("\n".join(failures), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
