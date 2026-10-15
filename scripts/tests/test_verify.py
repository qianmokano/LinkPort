import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / "verify.py"
ROOT = SCRIPT.parent.parent
SPEC = importlib.util.spec_from_file_location("verify", SCRIPT)
verify = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verify)


class VerificationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()

    def coverage(self, covered=8, count=10):
        folder = self.root / "Sources/LinkPortCore"
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / "Model.swift"
        path.touch()
        return {"data": [{"files": [{"filename": str(path), "summary": {
            "lines": {"count": count, "covered": covered}}}]}]}

    def test_coverage_is_weighted_and_ignores_ui(self):
        report = self.coverage()
        report["data"][0]["files"].append({"filename": str(self.root / "Sources/LinkPort/Picker.swift")})
        second = self.root / "Sources/LinkPortCore/Other.swift"
        second.touch()
        report["data"][0]["files"].append({"filename": str(second), "summary": {
            "lines": {"count": 30, "covered": 30}}})
        result = verify.summarize_coverage(report, self.root)
        self.assertEqual(result["percent"], 95)
        self.assertEqual(result["lines"], 40)

    def test_coverage_rejects_missing_empty_duplicate_and_invalid_reports(self):
        for report in ({}, self.coverage(0, 0), self.coverage(11, 10)):
            with self.subTest(report=report), self.assertRaises(ValueError):
                verify.summarize_coverage(report, self.root)
        report = self.coverage()
        report["data"][0]["files"] *= 2
        with self.assertRaises(ValueError):
            verify.summarize_coverage(report, self.root)
        (self.root / "Sources/LinkPortCore/Missing.swift").touch()
        with self.assertRaises(ValueError):
            verify.summarize_coverage(self.coverage(), self.root)

    def test_coverage_cli_threshold_and_reports(self):
        for covered, expected in ((8, 0), (7, 1)):
            path = self.root / "coverage.json"
            path.write_text(json.dumps(self.coverage(covered)))
            output = self.root / "reports/core.json"
            result = subprocess.run([sys.executable, str(SCRIPT), "coverage", "--root", str(self.root),
                                     "--coverage", str(path), "--report", str(output)], capture_output=True)
            self.assertEqual(result.returncode, expected)
            self.assertEqual(json.loads(output.read_text())["percent"], covered * 10)

    def test_cli_reports_missing_inputs_without_traceback(self):
        for check in ("source", "bundle"):
            result = subprocess.run([sys.executable, str(SCRIPT), check, "--root", str(self.root)], capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn(b"Check failed:", result.stderr)
            self.assertNotIn(b"Traceback", result.stderr)

    def test_metadata_accepts_current_contract_and_rejects_drift(self):
        with (ROOT / "Configuration/Info.plist").open("rb") as source:
            info = plistlib.load(source)
        verify.validate_metadata(info)
        for key, value in (("CFBundleIdentifier", "other.app"), ("LSMinimumSystemVersion", "27.0"),
                           ("CFBundleShortVersionString", "1.0"), ("CFBundleVersion", "0"),
                           ("CFBundleURLTypes", []), ("CFBundleDocumentTypes", []),
                           ("CFBundleLocalizations", ["en"])):
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify.validate_metadata(dict(info, **{key: value}))

    def test_localizations_require_matching_keys_values_and_arguments(self):
        verify.validate_localizations({"en": {"key": "%@ %d %%"}, "zh-Hans": {"key": "%@ %d %%"}})
        with self.assertRaisesRegex(ValueError, "must not be empty"):
            verify.validate_localizations({"en": {}, "zh-Hans": {}})
        for chinese in ({}, {"key": ""}, {"key": "%d %@"}, {"key": "%@"}):
            with self.subTest(chinese=chinese), self.assertRaises(ValueError):
                verify.validate_localizations({"en": {"key": "%@ %d"}, "zh-Hans": chinese})

    def test_catalog_parser_uses_apple_parser_and_rejects_duplicate_keys(self):
        for language in ("en", "zh-Hans"):
            folder = self.root / f"{language}.lproj"
            folder.mkdir()
            (folder / "Localizable.strings").write_text('"key" = "Text";\n')
        fake = subprocess.CompletedProcess([], 0, stdout='{"key":"Text"}')
        with patch.object(verify.subprocess, "run", return_value=fake) as run:
            verify.validate_localizations(verify.read_catalogs(self.root))
            self.assertEqual(run.call_count, 4)
            (self.root / "en.lproj/Localizable.strings").write_text('"key" = "A";\n"key" = "B";\n')
            with self.assertRaises(ValueError):
                verify.read_catalogs(self.root)

    def test_links_accept_relative_images_and_ignore_web_and_anchors(self):
        (self.root / "docs").mkdir()
        (self.root / "docs/screen.png").touch()
        (self.root / "README.md").write_text('[web](https://example.com) [section](#section) ![UI](docs/screen.png)\n')
        verify.check_links(self.root)
        for target in ("missing.md", "../outside.md"):
            (self.root / "README.md").write_text(f'[broken]({target})\n')
            with self.assertRaises(ValueError):
                verify.check_links(self.root)

    def test_source_check_and_bundle_resource_failures(self):
        (self.root / "Configuration").mkdir()
        metadata = (ROOT / "Configuration/Info.plist").read_bytes()
        (self.root / "Configuration/Info.plist").write_bytes(metadata)
        (self.root / "LICENSE").write_text("MIT License\n")
        with patch.object(verify, "read_catalogs", return_value={"en": {"key": "Text"}, "zh-Hans": {"key": "正文"}}):
            verify.check_source(self.root)
            app = self.root / "dist/LinkPort.app/Contents"
            (app / "Resources").mkdir(parents=True)
            (app / "Info.plist").write_bytes(metadata)
            (app / "Resources/LICENSE").write_text("Wrong license\n")
            with self.assertRaisesRegex(ValueError, "license differs"):
                verify.check_bundle(self.root)
        (self.root / "LICENSE").write_text("Wrong license\n")
        with patch.object(verify, "read_catalogs", return_value={"en": {"key": "Text"}, "zh-Hans": {"key": "正文"}}):
            with self.assertRaisesRegex(ValueError, "MIT LICENSE"):
                verify.check_source(self.root)

    def test_bundle_checks_deployment_targets_resources_and_zip(self):
        metadata = (ROOT / "Configuration/Info.plist").read_bytes()
        (self.root / "Configuration").mkdir()
        (self.root / "Configuration/Info.plist").write_bytes(metadata)
        (self.root / "LICENSE").write_text("MIT License\n")
        app = self.root / "dist/LinkPort.app/Contents"
        (app / "MacOS").mkdir(parents=True)
        (app / "MacOS/LinkPort").write_bytes(b"binary fixture")
        (app / "Info.plist").write_bytes(metadata)
        resources = app / "Resources"
        resources.mkdir()
        (resources / "LICENSE").write_bytes((self.root / "LICENSE").read_bytes())
        for name in ("Assets.car", "LinkPort.icns"):
            (resources / name).write_bytes(b"icon fixture")
        for language in ("en", "zh-Hans"):
            name = f"{language}.lproj/Localizable.strings"
            (resources / name).parent.mkdir()
            source = self.root / "Sources/LinkPort/Resources" / name
            source.parent.mkdir(parents=True)
            source.write_text('"key" = "Text";\n')
            (resources / name).write_bytes(source.read_bytes())
        with zipfile.ZipFile(self.root / "dist/LinkPort.zip", "w") as archive:
            for path in app.rglob("*"):
                if path.is_file():
                    archive.write(path, str(path.relative_to(app.parent.parent)))
        catalogs = {"en": {"key": "Text"}, "zh-Hans": {"key": "正文"}}
        fake = subprocess.CompletedProcess([], 0, stdout="minos 26.0\nsdk 27.0\n")
        with patch.object(verify, "read_catalogs", return_value=catalogs), patch.object(verify.subprocess, "run", return_value=fake):
            verify.check_bundle(self.root)
            with patch.object(verify.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, stdout="minos 27.0\n")):
                with self.assertRaisesRegex(ValueError, "deployment target"):
                    verify.check_bundle(self.root)
            (resources / "Assets.car").write_bytes(b"modified icon")
            with self.assertRaisesRegex(ValueError, "ZIP content differs"):
                verify.check_bundle(self.root)
            (resources / "Assets.car").unlink()
            with self.assertRaisesRegex(ValueError, "icon resource is missing"):
                verify.check_bundle(self.root)

    def test_toolchain_failure_stops_build_before_replacing_outputs(self):
        executable = self.root / "xcrun"
        executable.write_text("#!/bin/sh\nexit 1\n")
        executable.chmod(0o755)
        import os
        environment = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}", DEVELOPER_DIR="/invalid/Xcode")
        result = subprocess.run([str(ROOT / "scripts/build-app.sh")], env=environment, capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"requires full Xcode 27", result.stderr)


if __name__ == "__main__":
    unittest.main()
