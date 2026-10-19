#!/usr/bin/env python3
"""Exercise the artifact verifier with real signed Mach-O dependency graphs."""
from pathlib import Path
import contextlib
import io
import runpy
import plistlib
import platform
import shutil
import subprocess
import sys
import tempfile
import unittest


VERIFIER = Path(__file__).resolve().parents[1] / "scripts/verify-bundled-cli.py"


class BundledCLIArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="bmux-cli-artifact-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.app = self.root / "Original bmux.app"
        self.cli = self.app / "Contents/Resources/bin/bmux"
        self.cli.parent.mkdir(parents=True)
        self.frameworks = self.app / "Contents/Frameworks"
        self.frameworks.mkdir()
        self.build = self.root / "Original DerivedData"
        self.build.mkdir()
        (self.app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleName": "bmux"}))

    def command(self, *args):
        return subprocess.run(args, check=True, capture_output=True, text=True)

    def compile(self, source, output, *args):
        source_path = self.root / (output.name + ".c")
        source_path.write_text(source)
        self.command("/usr/bin/xcrun", "clang", str(source_path), "-o", str(output), *args)
        self.command("/usr/bin/codesign", "--force", "--sign", "-", str(output))

    def framework(self, name, source, *args):
        bundle = self.frameworks / f"{name}.framework"
        binary = bundle / "Versions/A" / name
        binary.parent.mkdir(parents=True)
        (bundle / "Versions/Current").symlink_to("A")
        (bundle / name).symlink_to(f"Versions/Current/{name}")
        resources = binary.parent / "Resources"
        resources.mkdir()
        (resources / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleExecutable": name, "CFBundleIdentifier": f"test.bmux.{name}",
            "CFBundlePackageType": "FMWK", "CFBundleVersion": "1",
        }))
        (bundle / "Resources").symlink_to("Versions/Current/Resources")
        self.compile(source, binary, "-dynamiclib", "-install_name",
                     f"@rpath/{name}.framework/Versions/A/{name}", *args)
        self.command("/usr/bin/codesign", "--force", "--sign", "-", str(bundle))
        return binary

    def dynamic_cli(self):
        leaf = self.framework("Leaf", "int leaf(void) { return 42; }")
        outer = self.framework("Outer", "extern int leaf(void); int answer(void) { return leaf(); }", str(leaf))
        self.compile('#include <stdio.h>\nextern int answer(void); int main(void) { printf("bmux %d\\n", answer()); }',
                     self.cli, str(outer), "-Wl,-rpath," + str(self.build),
                     "-Wl,-rpath,@executable_path/../../Frameworks")
        shutil.copytree(self.frameworks, self.build, dirs_exist_ok=True, symlinks=True)
        return leaf, outer

    def verify(self, succeeds=True, *args):
        result = subprocess.run([sys.executable, str(VERIFIER), str(self.app), *args],
                                capture_output=True, text=True, timeout=45)
        self.assertEqual(result.returncode == 0, succeeds, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def test_static_cli_runs_after_relocation(self):
        self.compile('#include <stdio.h>\nint main(void) { puts("bmux fixture"); }', self.cli)
        self.assertIn("Relocated CLI: bmux fixture", self.verify())

    def test_signed_dynamic_transitive_closure_runs_and_archives_unchanged_bytes(self):
        leaf, outer = self.dynamic_cli()
        archive = self.root / "artifact.tar.gz"
        self.verify(True, "--archive", str(archive))
        unpacked = self.root / "download"
        unpacked.mkdir()
        self.command("/usr/bin/tar", "-xzf", str(archive), "-C", str(unpacked))
        for binary in (self.cli, leaf, outer):
            self.assertEqual(binary.read_bytes(), (unpacked / "bmux.app" / binary.relative_to(self.app)).read_bytes())
        shutil.rmtree(self.build)
        self.app = unpacked / "bmux.app"
        self.assertIn("Relocated CLI: bmux 42", self.verify(True, "--require-absent-external-rpaths"))

    def test_missing_transitive_framework_fails_even_when_original_build_can_supply_it(self):
        self.dynamic_cli()
        shutil.rmtree(self.frameworks / "Leaf.framework")
        # Prove the original executable can still accidentally succeed via DD.
        self.assertEqual(self.command(str(self.cli), "--version").stdout, "bmux 42\n")
        self.assertIn("unbundled dependency", self.verify(False))

    def test_missing_direct_framework_fails(self):
        self.dynamic_cli()
        shutil.rmtree(self.frameworks / "Outer.framework")
        self.assertIn("unbundled dependency", self.verify(False))

    def test_fresh_runner_gate_rejects_existing_external_rpath(self):
        self.dynamic_cli()
        self.assertIn("original external search paths still exist", self.verify(False, "--require-absent-external-rpaths"))

    def test_dependency_missing_required_architecture_fails(self):
        leaf, _ = self.dynamic_cli()
        host = self.command("/usr/bin/lipo", "-archs", str(self.cli)).stdout.strip()
        other = "x86_64" if host == "arm64" else "arm64"
        self.compile("int leaf(void) { return 42; }", leaf, "-dynamiclib", "-target",
                     f"{other}-apple-macos13", "-install_name",
                     "@rpath/Leaf.framework/Versions/A/Leaf")
        self.assertIn("lipo", self.verify(False))

    def test_invalid_existing_signature_fails_before_launch(self):
        leaf, _ = self.dynamic_cli()
        data = leaf.read_bytes()
        leaf.write_bytes(data.replace(b"leaf", b"leak", 1))
        self.assertIn("codesign", self.verify(False))

    def test_unsigned_presign_artifact_is_reported_without_requiring_release_signature(self):
        self.compile('int main(void) { return 0; }', self.cli)
        self.command("/usr/bin/codesign", "--remove-signature", str(self.cli))
        verifier = runpy.run_path(str(VERIFIER))
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            verifier["audit"](self.app)
        self.assertIn("unsigned 1", output.getvalue())

    def nonhost_slice(self, binary):
        host = platform.machine()
        self.assertIn(host, ("arm64", "x86_64"))
        other = "x86_64" if host == "arm64" else "arm64"
        self.assertEqual(set(self.command("/usr/bin/lipo", "-archs", str(binary)).stdout.split()),
                         {host, other})
        thin = self.root / (binary.name + "-nonhost")
        self.command("/usr/bin/lipo", str(binary), "-thin", other, "-output", str(thin))
        return host, other, thin

    def replace_slice(self, binary, architecture, thin):
        merged = self.root / (binary.name + "-reassembled")
        self.command("/usr/bin/lipo", str(binary), "-replace", architecture, str(thin),
                     "-output", str(merged))
        merged.replace(binary)

    def corrupt_nonhost_signature(self, binary, target):
        host, other, thin = self.nonhost_slice(binary)
        for architecture in (host, other):
            self.command("/usr/bin/codesign", "--verify", "--strict", "--architecture",
                         architecture, str(target))
        data = thin.read_bytes()
        self.assertEqual(data.count(b"artifact-signature-marker"), 1)
        thin.write_bytes(data.replace(b"artifact-signature-marker", b"artifact-signature-marKer"))
        self.replace_slice(binary, other, thin)
        self.command("/usr/bin/codesign", "--verify", "--strict", "--architecture", host, str(target))
        invalid = subprocess.run(["/usr/bin/codesign", "--verify", "--strict", "--architecture",
                                  other, str(target)], capture_output=True, text=True)
        self.assertNotEqual(invalid.returncode, 0, invalid.stdout + invalid.stderr)

    def assert_mixed_slices_archive_unchanged(self, binaries, unsigned_targets):
        for binary, target in unsigned_targets:
            host, other, thin = self.nonhost_slice(binary)
            self.command("/usr/bin/codesign", "--remove-signature", str(thin))
            self.replace_slice(binary, other, thin)
            self.command("/usr/bin/codesign", "--verify", "--strict", "--architecture", host, str(target))
            unsigned = subprocess.run(["/usr/bin/codesign", "-d", "--architecture", other, str(target)],
                                      capture_output=True, text=True)
            self.assertNotEqual(unsigned.returncode, 0)
            self.assertIn("code object is not signed at all", unsigned.stderr)
        before = {binary.relative_to(self.app): binary.read_bytes() for binary in binaries}
        links = {path.relative_to(self.app): path.readlink()
                 for path in self.frameworks.rglob("*") if path.is_symlink()}
        archive = self.root / "mixed-artifact.tar.gz"
        self.assertIn("Relocated CLI: bmux 42", self.verify(True, "--archive", str(archive)))
        unpacked = self.root / "download"
        unpacked.mkdir()
        self.command("/usr/bin/tar", "-xzf", str(archive), "-C", str(unpacked))
        self.app = unpacked / "bmux.app"
        for relative, data in before.items():
            self.assertEqual((self.app / relative).read_bytes(), data)
        for relative, target in links.items():
            self.assertTrue((self.app / relative).is_symlink())
            self.assertEqual((self.app / relative).readlink(), target)
        self.assertIn("Relocated CLI: bmux 42", self.verify(True, "--require-absent-external-rpaths"))

    def test_mixed_signed_unsigned_cli_slices_run_and_archive_unchanged(self):
        self.compile('#include <stdio.h>\nint main(void) { puts("bmux 42"); }',
                     self.cli, "-arch", "arm64", "-arch", "x86_64")
        self.assert_mixed_slices_archive_unchanged((self.cli,), ((self.cli, self.cli),))

    def test_mixed_signed_unsigned_framework_slices_run_and_archive_unchanged(self):
        leaf = self.framework("Leaf", "int leaf(void) { return 42; }",
                              "-arch", "arm64", "-arch", "x86_64")
        self.compile('#include <stdio.h>\nextern int leaf(void); int main(void) { printf("bmux %d\\n", leaf()); }',
                     self.cli, str(leaf), "-arch", "arm64", "-arch", "x86_64",
                     "-Wl,-rpath,@executable_path/../../Frameworks")
        self.assertTrue(any(path.is_symlink() for path in self.frameworks.rglob("*")))
        self.assert_mixed_slices_archive_unchanged(
            (self.cli, leaf), ((leaf, self.frameworks / "Leaf.framework"),))

    def test_corrupt_nonhost_cli_signature_is_rejected_before_execution(self):
        self.compile('#include <stdio.h>\nint main(void) { puts("bmux artifact-signature-marker"); }',
                     self.cli, "-arch", "arm64", "-arch", "x86_64")
        self.corrupt_nonhost_signature(self.cli, self.cli)
        output = self.verify(False)
        self.assertIn("codesign", output)
        self.assertNotIn("Relocated CLI:", output)

    def test_corrupt_extra_framework_slice_is_rejected_before_execution(self):
        leaf = self.framework("Leaf", 'const char *marker(void) { return "artifact-signature-marker"; } '
                              'int leaf(void) { return 42; }', "-arch", "arm64", "-arch", "x86_64")
        self.compile('#include <stdio.h>\nextern int leaf(void); int main(void) { printf("bmux %d\\n", leaf()); }',
                     self.cli, str(leaf), "-Wl,-rpath,@executable_path/../../Frameworks")
        self.assertEqual(self.command("/usr/bin/lipo", "-archs", str(self.cli)).stdout.strip(), platform.machine())
        self.corrupt_nonhost_signature(leaf, self.frameworks / "Leaf.framework")
        output = self.verify(False)
        self.assertIn("codesign", output)
        self.assertNotIn("Relocated CLI:", output)

    def test_native_cli_failure_is_not_accepted(self):
        self.compile('int main(void) { return 42; }', self.cli)
        self.assertIn("relocated CLI exited 42", self.verify(False))

    def test_missing_cli_fails(self):
        self.assertIn("missing executable", self.verify(False))


if __name__ == "__main__":
    unittest.main()
