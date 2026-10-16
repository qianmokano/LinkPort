# Development

[README](../README.md) · [Contributing](../CONTRIBUTING.md) · [Testing](testing.md) · [Releasing](releasing.md)

## Toolchain

Use macOS with full Xcode 27 or later, its macOS 27 SDK, and Swift 6.4 or later. The app's deployment target remains macOS 26. The package manifest's tools version is a manifest-language floor, not the supported build toolchain.

Full checks also use Python 3.9 or later with only its standard library. Apple command-line tools provide `plutil`, `lipo`, `vtool`, and `codesign`. There are no third-party app or Swift package dependencies.

The scripts honor `DEVELOPER_DIR`. If only Command Line Tools is selected globally, they use `/Applications/Xcode.app` when installed. They never run `xcode-select --switch`. For an alternate Xcode installation:

```sh
export DEVELOPER_DIR=/Applications/Xcode_27.0.app/Contents/Developer
./scripts/check.sh
```

## Commands

| Command | Purpose |
| --- | --- |
| `./scripts/test.sh` | Swift Testing suite with code coverage |
| `./scripts/test.sh --filter TestName` | Focused Swift tests |
| `./scripts/build-app.sh` | Universal app, ZIP, and SHA-256 manifest |
| `./scripts/check.sh` | Tooling tests, source checks, full Swift tests, coverage gate, and package validation |
| `python3 -m unittest discover -s scripts/tests -v` | Check-script regression tests without building the app |

`scripts/check.sh` puts its console log, Swift Testing XML, and a portable core coverage summary in `.build/reports/`. SwiftPM may name the XML `tests-swift-testing.xml` rather than `tests.xml`; both are collected by CI. The coverage gate requires every LinkPortCore source file and at least 80% covered executable lines, weighted by line count. UI and platform adapters are not part of this percentage.

The scripts currently retain SwiftPM's `--build-system native` option used by this project. Swift 6.4 reports a deprecation warning; changing build systems should be validated separately rather than mixed into documentation and CI setup.

## Architecture

| Component | Responsibility |
| --- | --- |
| LinkPortCore | URL validation, FIFO queue, browser catalog/order/groups, preferences, operation state, picker geometry, and drag-edge calculations |
| LinkPort | App lifecycle, status menu, SwiftUI views, picker window, AppKit browser/clipboard services, localization, and native scrolling integration |
| Configuration | Info.plist browser/document registration and the editable Icon Composer icon |
| Tests | Core logic, mocked AppKit Settings/menu flows, and application registration contracts |
| scripts | Process-local tool selection, checks, coverage, and Universal packaging |

macOS delivers links and local web files to `AppDelegate`. `LinkController` validates and queues them, refreshes the browser catalog, and drives picker state. Choosing a browser calls `BrowserSystem.open`; copying calls `BrowserSystem.copy`. A completed action advances the queue. Cancelling invalidates the current operation token so a late completion cannot clear a newer link.

`BrowserSystem` and `PreferenceStore` are the boundaries for external effects. Tests replace them; preferences tests use independent UserDefaults suites. The app stores browser order, hidden IDs, language, and the welcome state under the existing `com.linkport.app` domain. Keep those keys and the Bundle ID compatible with existing installations.

## Native UI and compatibility

The picker uses `NSGlassEffectView` with macOS 27's interactive effect guarded by availability; macOS 26 uses the standard glass view. Four grid columns are shared by layout and keyboard movement. The window is constrained to the visible screen, including displays with negative coordinates.

Settings uses `NSTabViewController` toolbar tabs, SwiftUI grouped forms, and a browser `List` with `.onMove`. Enabled and hidden browser groups retain separate orders. A narrow AppKit adapter requests `.gap` insertion feedback and scrolls the enclosing `NSScrollView` while dragging near an edge; it does not replace SwiftUI's data source or drag gestures.

Status-menu structure is rebuilt in `menuNeedsUpdate`. Settings presentation is scheduled in the main run loop's default mode after menu tracking finishes. When both web schemes point to LinkPort, the status section is omitted. Presenting Settings cancels pending picker work.

Browser eligibility requires both HTTP/HTTPS URL declarations and HTML/XHTML document declarations. Run the full `.app` when checking Launch Services integration; `swift run` lacks the application metadata. Browser discovery may return other URL routers, which users can hide.

## Resources and packaging

Edit English and Simplified Chinese catalogs together. Checks use Apple's parser, reject duplicate/missing keys, and compare the current `%@`/`%d` format arguments. UI text belongs in the catalogs, not the build scripts.

`Configuration/LinkPort.icon` is editable in Icon Composer. Its original branch SVG and dark gradient are independent layers. `actool` compiles the layered `Assets.car` and compatible `LinkPort.icns`; the app references `CFBundleIconName`.

Builds compile arm64 and x86_64 separately for macOS 26, combine them with `lipo`, and assemble in staging before replacing the output. The app contains both language catalogs and the root MIT license. The script ad-hoc signs the bundle, verifies it, creates a ZIP, and writes `SHA256SUMS`. Checks compare every packaged file in the ZIP with the app and verify both deployment targets.

## Hosted CI

The [GitHub Actions workflow](https://github.com/qianmokano/LinkPort/actions/workflows/ci.yml) runs the same check command on PRs, pushes to `main`, and manual requests. It uses the `xcode-27` runner with Xcode 27.0 selected explicitly, a 30-minute timeout, read-only repository permissions, and cancellation of superseded runs. Actions are pinned to full commits; Dependabot checks them monthly.

The Xcode 27 runner is an arm64 public-preview image; its availability may change. See the [official runner announcement](https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/). CI cross-compiles Intel rather than claiming Intel hardware coverage. Reports are retained for 14 days and successful development ZIPs for 7 days. No signing credentials or release publishing permissions are required. Current verification results and outstanding device tests are recorded in the [test matrix](testing.md).
