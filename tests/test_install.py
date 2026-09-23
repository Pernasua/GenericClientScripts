"""Exercise the real Bash or PowerShell installer in temporary directories only."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
OPTIONS = None


def native_path(path):
    if OPTIONS.powershell and Path(OPTIONS.powershell).suffix.lower() == ".exe" and str(path).startswith("/"):
        return subprocess.check_output(["wslpath", "-w", str(path)], text=True).strip()
    return str(path)


class InstallerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="script installer ", dir=OPTIONS.temp_root)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "artifacts"
        self.destination = self.root / "profile" / "scripts"
        shutil.copytree(ROOT / "build" / "libs", self.source)
        self.destination.mkdir(parents=True)
        self.custom = self.destination / "custom-user-script.jar"
        self.custom.write_bytes(b"unrelated user artifact; preserve unchanged")
        self.snape = "snape-grass-collector.jar"

    def run_installer(self, source=None, success=True):
        if OPTIONS.powershell:
            command = [OPTIONS.powershell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                       native_path(ROOT / "install.ps1"), "-Source", native_path(source or self.source),
                       "-ScriptsDirectory", native_path(self.destination)]
        else:
            command = ["bash", str(ROOT / "install.sh"), str(source or self.source), str(self.destination)]
        result = subprocess.run(command, capture_output=True, text=True, timeout=45)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        self.assertEqual(self.custom.read_bytes(), b"unrelated user artifact; preserve unchanged")

    def test_full_migration_preserves_old_catalog_and_custom_scripts(self):
        legacy = self.destination / "GenericClientScripts.jar"
        legacy.write_bytes(b"legacy backup")
        self.run_installer()
        self.assertFalse(legacy.exists())
        backups = list((self.destination.parent / "backups").glob("*/GenericClientScripts.jar"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), b"legacy backup")
        for jar in self.source.glob("*.jar"):
            self.assertEqual(jar.read_bytes(), (self.destination / jar.name).read_bytes())

    def test_single_file_installs_only_that_script(self):
        self.run_installer(self.source / self.snape)
        self.assertEqual({p.name for p in self.destination.glob("*.jar")}, {self.snape, self.custom.name})

    def test_single_update_backs_up_previous_bytes(self):
        old = self.destination / self.snape
        old.write_bytes(b"previous version")
        self.run_installer(self.source / self.snape)
        self.assertEqual(old.read_bytes(), (self.source / self.snape).read_bytes())
        backups = list((self.destination.parent / "backups").glob("*/" + self.snape))
        self.assertEqual(backups[0].read_bytes(), b"previous version")

    def test_partial_migration_does_not_remove_other_legacy_scripts(self):
        old = self.destination / "GenericClientScripts.jar"
        old.write_bytes(b"legacy backup")
        self.run_installer(self.source / self.snape, success=False)
        self.assertEqual(old.read_bytes(), b"legacy backup")
        self.assertFalse((self.destination / self.snape).exists())

    def test_missing_indexed_artifact_is_rejected_before_changes(self):
        (self.source / self.snape).unlink()
        self.run_installer(success=False)
        self.assertEqual(list(self.destination.iterdir()), [self.custom])

    def test_corrupt_hash_is_rejected_before_changes(self):
        with (self.source / self.snape).open("ab") as file:
            file.write(b"changed")
        self.run_installer(success=False)
        self.assertEqual(list(self.destination.iterdir()), [self.custom])

    def test_unlisted_jars_are_not_silently_installed(self):
        (self.source / "extra.jar").write_bytes(b"unlisted")
        self.run_installer(success=False)
        self.assertEqual(list(self.destination.iterdir()), [self.custom])

    def test_mismatched_manifest_identity_is_rejected(self):
        wrong = self.root / "wrong-name.jar"
        shutil.copyfile(self.source / self.snape, wrong)
        self.run_installer(wrong, success=False)
        self.assertEqual(list(self.destination.iterdir()), [self.custom])

    def test_directory_collision_is_rejected_before_changes(self):
        collision = self.destination / self.snape
        collision.mkdir()
        (collision / "preserve.txt").write_bytes(b"preserve")
        self.run_installer(success=False)
        self.assertEqual((collision / "preserve.txt").read_bytes(), b"preserve")

    def test_duplicate_index_entries_are_rejected(self):
        index = self.source / "scripts.sha256"
        index.write_text(index.read_text() + index.read_text().splitlines()[0] + "\n")
        self.run_installer(success=False)
        self.assertEqual(list(self.destination.iterdir()), [self.custom])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--powershell", help="pwsh or the Windows PowerShell executable under WSL")
    parser.add_argument("--temp-root", help="Windows-mounted temp directory for WSL-to-PowerShell tests")
    OPTIONS, rest = parser.parse_known_args()
    unittest.main(argv=[__file__, *rest])
