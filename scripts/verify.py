#!/usr/bin/env python3
"""Repository checks using Python's standard library and the selected Xcode."""

import argparse
from collections import Counter
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit
import zipfile


def validate_metadata(info):
    if info.get("CFBundleIdentifier") != "com.linkport.app":
        raise ValueError("Bundle identifier must remain com.linkport.app")
    if info.get("LSMinimumSystemVersion") != "26.0":
        raise ValueError("Minimum macOS version must remain 26.0")
    if not re.fullmatch(r"\d+\.\d+\.\d+", info.get("CFBundleShortVersionString", "")):
        raise ValueError("App version must have major.minor.patch format")
    if not re.fullmatch(r"[1-9]\d*", info.get("CFBundleVersion", "")):
        raise ValueError("Build number must be a positive integer")
    schemes = {scheme for item in info.get("CFBundleURLTypes", []) for scheme in item.get("CFBundleURLSchemes", [])}
    types = {kind for item in info.get("CFBundleDocumentTypes", [])
             if item.get("CFBundleTypeRole") in ("Viewer", "Editor") for kind in item.get("LSItemContentTypes", [])}
    if not {"http", "https"} <= schemes or not {"public.html", "public.xhtml"} <= types:
        raise ValueError("Browser registration must include HTTP/HTTPS and HTML/XHTML")
    if set(info.get("CFBundleLocalizations", [])) != {"en", "zh-Hans"}:
        raise ValueError("App metadata must declare both supported localizations")


def validate_localizations(catalogs):
    reference = catalogs["en"]
    if not reference:
        raise ValueError("Localization catalogs must not be empty")
    for language, catalog in catalogs.items():
        if catalog.keys() != reference.keys():
            raise ValueError(f"Localization keys differ: {language}")
        for key, value in catalog.items():
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"Empty or invalid translation: {language}/{key}")
            # Current catalogs use sequential %@ and %d arguments. Ignore literal %%.
            tokens = lambda text: re.findall(r"%(?:@|d)", text.replace("%%", ""))
            if tokens(value) != tokens(reference[key]):
                raise ValueError(f"Format arguments differ: {language}/{key}")


def summarize_coverage(coverage, root):
    expected = {path.resolve() for path in (root / "Sources/LinkPortCore").rglob("*.swift")}
    files = {}
    for unit in coverage.get("data", []):
        for item in unit.get("files", []):
            path = Path(item["filename"]).resolve()
            if path in expected:
                if path in files:
                    raise ValueError("Duplicate core coverage entry")
                lines = item["summary"]["lines"]
                count, covered = lines["count"], lines["covered"]
                if not isinstance(count, int) or not isinstance(covered, int) or not 0 <= covered <= count:
                    raise ValueError("Invalid core coverage counts")
                files[path] = {"count": count, "covered": covered}
    if not expected or files.keys() != expected:
        raise ValueError("Coverage report must include every LinkPortCore source file")
    count = sum(item["count"] for item in files.values())
    covered = sum(item["covered"] for item in files.values())
    if count == 0:
        raise ValueError("Core coverage report contains no executable lines")
    return {"target": "LinkPortCore", "lines": count, "covered": covered,
            "percent": covered * 100 / count, "minimum_percent": 80,
            "files": {str(path.relative_to(root)): value for path, value in sorted(files.items())}}


def check_links(root):
    paths = list(root.glob("*.md")) + list((root / "docs").rglob("*.md")) + list((root / ".github").rglob("*.md"))
    for path in paths:
        for target in re.findall(r"\[[^\]]*\]\(([^\s)]+)\)", path.read_text()):
            url = urlsplit(target)
            if url.scheme or url.netloc or not url.path:
                continue
            destination = (path.parent / unquote(url.path)).resolve()
            if not destination.is_relative_to(root) or not destination.exists():
                raise ValueError(f"Broken local link in {path.relative_to(root)}: {target}")


def read_catalogs(resources):
    catalogs = {}
    for language in ("en", "zh-Hans"):
        path = resources / f"{language}.lproj/Localizable.strings"
        subprocess.run(["plutil", "-lint", str(path)], check=True, capture_output=True)
        # plutil is Apple's parser for the OpenStep .strings format.
        result = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(path)],
                                check=True, capture_output=True, text=True)
        catalogs[language] = json.loads(result.stdout)
        keys = re.findall(r'^\s*"([^"\\]+)"\s*=', path.read_text(), re.MULTILINE)
        if any(count > 1 for count in Counter(keys).values()):
            raise ValueError(f"Duplicate localization key: {language}")
    return catalogs


def check_source(root):
    with (root / "Configuration/Info.plist").open("rb") as source:
        validate_metadata(plistlib.load(source))
    validate_localizations(read_catalogs(root / "Sources/LinkPort/Resources"))
    check_links(root)
    if not (root / "LICENSE").read_text().startswith("MIT License\n"):
        raise ValueError("MIT LICENSE is missing or invalid")
    print("Source metadata, localization keys/arguments, and local documentation links passed")


def check_bundle(root):
    app = root / "dist/LinkPort.app/Contents"
    resources = app / "Resources"
    with (app / "Info.plist").open("rb") as source:
        info = plistlib.load(source)
    validate_metadata(info)
    with (root / "Configuration/Info.plist").open("rb") as source:
        if info != plistlib.load(source):
            raise ValueError("Packaged metadata differs from the repository")
    if (resources / "LICENSE").read_bytes() != (root / "LICENSE").read_bytes():
        raise ValueError("Packaged license differs from the repository")
    validate_localizations(read_catalogs(resources))
    for language in ("en", "zh-Hans"):
        name = f"{language}.lproj/Localizable.strings"
        if (resources / name).read_bytes() != (root / "Sources/LinkPort/Resources" / name).read_bytes():
            raise ValueError(f"Packaged localization differs: {language}")
    for name in ("Assets.car", "LinkPort.icns"):
        if not (resources / name).is_file() or (resources / name).stat().st_size == 0:
            raise ValueError(f"Packaged icon resource is missing: {name}")
    binary = app / "MacOS/LinkPort"
    for arch in ("arm64", "x86_64"):
        subprocess.run(["lipo", str(binary), "-verify_arch", arch], check=True)
        build = subprocess.run(["xcrun", "vtool", "-arch", arch, "-show-build", str(binary)],
                               check=True, capture_output=True, text=True)
        if not re.search(r"\bminos\s+26\.0(?:\.0)?\s", build.stdout):
            raise ValueError(f"Unexpected deployment target for {arch}")
    subprocess.run(["codesign", "--verify", "--strict", str(app.parent)], check=True)
    with zipfile.ZipFile(root / "dist/LinkPort.zip") as archive:
        for path in app.rglob("*"):
            if path.is_file():
                name = str(path.relative_to(app.parent.parent))
                if archive.read(name) != path.read_bytes():
                    raise ValueError(f"ZIP content differs from the app: {name}")
    print("Universal app, deployment targets, resources, MIT license, and signature passed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("check", choices=("source", "coverage", "bundle"))
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--coverage", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        if args.check == "source":
            check_source(root)
        elif args.check == "bundle":
            check_bundle(root)
        else:
            if args.coverage is None or args.report is None:
                parser.error("coverage requires --coverage and --report")
            result = summarize_coverage(json.loads(args.coverage.read_text()), root)
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(result, indent=2) + "\n")
            print(f"LinkPortCore line coverage: {result['percent']:.2f}% (minimum 80%)")
            if result["percent"] < result["minimum_percent"]:
                raise ValueError("Core line coverage is below 80%")
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError,
            plistlib.InvalidFileException, zipfile.BadZipFile) as error:
        print(f"Check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
