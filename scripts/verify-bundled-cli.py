#!/usr/bin/env python3
"""Audit shipped CLI dependencies and run an unmodified, relocated bundle copy.

No build-directory dependency is accepted, even if dyld could find it locally.
The optional archive contains only the CLI, metadata and its private dependency
closure, preserving executable bytes, framework symlinks and signatures.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile


SYSTEM_ROOTS = ("/usr/lib/", "/System/Library/")
LOAD_COMMANDS = {"LC_LOAD_DYLIB", "LC_LOAD_WEAK_DYLIB", "LC_REEXPORT_DYLIB", "LC_LOAD_UPWARD_DYLIB"}


def run(*args: str) -> str:
    result = subprocess.run(args, capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise RuntimeError(f"{args[0]} exited {result.returncode}: {result.stdout}{result.stderr}")
    return result.stdout


def load_commands(binary: Path, arch: str) -> tuple[list[str], list[str]]:
    output = run("/usr/bin/otool", "-arch", arch, "-l", str(binary))
    dependencies, rpaths = [], []
    command = None
    for line in output.splitlines():
        words = line.strip().split(maxsplit=1)
        if not words:
            continue
        if words[0] == "cmd":
            command = words[1]
        elif words[0] == "name" and command in LOAD_COMMANDS:
            dependencies.append(words[1].rsplit(" (offset ", 1)[0])
        elif words[0] == "path" and command == "LC_RPATH":
            rpaths.append(words[1].rsplit(" (offset ", 1)[0])
    return dependencies, rpaths


def expand(path: str, loader: Path, executable: Path) -> Path:
    return Path(path.replace("@loader_path", str(loader.parent)).replace(
        "@executable_path", str(executable.parent))).resolve()


def is_system(path: str) -> bool:
    return path.startswith(SYSTEM_ROOTS)


def audit(app: Path) -> tuple[set[Path], set[str]]:
    app = app.resolve()
    executable = app / "Contents/Resources/bin/bmux"
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise RuntimeError(f"missing executable: {executable}")
    architectures = run("/usr/bin/lipo", "-archs", str(executable)).split()
    files: set[Path] = set()
    external_rpaths: set[str] = set()
    for arch in architectures:
        pending = [(executable.resolve(), ())]
        visited: set[Path] = set()
        while pending:
            binary, inherited = pending.pop()
            if binary in visited:
                continue
            if not binary.is_relative_to(app):
                raise RuntimeError(f"dependency escapes bundle: {binary}")
            run("/usr/bin/lipo", str(binary), "-verify_arch", arch)
            visited.add(binary)
            files.add(binary)
            dependencies, local_rpaths = load_commands(binary, arch)
            rpaths = tuple(expand(p, binary, executable) for p in local_rpaths) + inherited
            for path in rpaths:
                if not path.is_relative_to(app) and not is_system(str(path)):
                    external_rpaths.add(str(path))
            for dependency in dependencies:
                if is_system(dependency):
                    continue  # OS dyld shared-cache images need not exist on disk.
                if dependency.startswith("@rpath/"):
                    suffix = dependency[len("@rpath/"):]
                    candidates = [(p / suffix).resolve() for p in rpaths]
                    if any(is_system(str(p)) for p in candidates) and suffix.startswith("libswift"):
                        continue
                else:
                    candidates = [expand(dependency, binary, executable)]
                resolved = next((p for p in candidates if p.is_relative_to(app) and p.is_file()), None)
                if resolved is None:
                    raise RuntimeError(f"unbundled dependency ({arch}): {binary.relative_to(app)} -> {dependency}")
                pending.append((resolved, rpaths))
    print(f"Dependency closure: {len(files)} Mach-O images; architectures: {', '.join(architectures)}")
    signed = 0
    verified: set[Path] = set()
    for binary in sorted(files):
        target = binary
        for ancestor in binary.parents:
            if ancestor.suffix == ".framework":
                target = ancestor
                break
            if ancestor == app:
                break
        if target in verified:
            continue
        verified.add(target)
        signature = subprocess.run(["/usr/bin/codesign", "-d", str(target)], capture_output=True, text=True)
        if signature.returncode == 0:
            run("/usr/bin/codesign", "--verify", "--strict", str(target))
            signed += 1
        elif "code object is not signed at all" not in signature.stderr:
            raise RuntimeError(f"cannot inspect signature: {target}: {signature.stderr}")
    print(f"Signatures: verified {signed}; unsigned {len(verified) - signed} (pre-sign artifacts permitted)")
    return files, external_rpaths


def stage(app: Path, destination: Path, files: set[Path]) -> None:
    destinations: set[Path] = set()
    for binary in files:
        source = binary
        for ancestor in binary.parents:
            if ancestor.suffix == ".framework":
                source = ancestor
                break
            if ancestor == app:
                break
        destinations.add(source)
    info = app / "Contents/Info.plist"
    if info.is_file():
        destinations.add(info)
    for source in sorted(destinations):
        target = destination / source.relative_to(app)
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            shutil.copytree(source, target, symlinks=True)
        else:
            shutil.copy2(source, target)


def verify(app: Path, archive: Path | None, require_absent_external_rpaths: bool) -> None:
    app = app.resolve()
    files, external = audit(app)
    if require_absent_external_rpaths:
        present = sorted(p for p in external if Path(p).exists())
        if present:
            raise RuntimeError(f"original external search paths still exist: {present}")
    with tempfile.TemporaryDirectory(prefix="bmux-cli-artifact-") as temporary:
        root = Path(temporary)
        relocated = root / "Relocated bmux.app"
        stage(app, relocated, files)
        audit(relocated)
        env = {"PATH": "/usr/bin:/bin", "HOME": str(root), "CFFIXED_USER_HOME": str(root),
               "TMPDIR": str(root), "BMUX_CLI_SENTRY_DISABLED": "1"}
        result = subprocess.run([str(relocated / "Contents/Resources/bin/bmux"), "--version"],
                                cwd=root, env=env, capture_output=True, text=True, timeout=15)
        if result.returncode or not re.match(r"bmux\s", result.stdout):
            raise RuntimeError(f"relocated CLI exited {result.returncode}: {result.stdout}{result.stderr}")
        print(f"Relocated CLI: {result.stdout.strip()}")
        if external and not require_absent_external_rpaths:
            print("External build search paths recorded; separate-runner verification proves their absence.")
        if archive:
            archive.parent.mkdir(parents=True, exist_ok=True)
            with tarfile.open(archive, "w:gz") as output:
                output.add(relocated, arcname="bmux.app")
            print(f"Artifact: {archive}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--require-absent-external-rpaths", action="store_true")
    args = parser.parse_args()
    try:
        verify(args.app, args.archive, args.require_absent_external_rpaths)
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        print(f"Bundled CLI verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
