# Changelog

User-visible changes are recorded here. Versions follow Semantic Versioning; repository tags use `vMAJOR.MINOR.PATCH`.

## 1.0.0 — 2026-10-15

### Added

- Native macOS menu bar browser chooser for HTTP/HTTPS links and local HTML/XHTML files.
- Complete URL copying, ordered link queues, keyboard navigation, and multi-display positioning.
- Browser visibility and grouped reordering with drag, arrow controls, and edge scrolling.
- English and Simplified Chinese localization with an immediate language preference.
- Native glass picker, settings tabs, and a layered Icon Composer app icon.
- Universal arm64/x86_64 packaging, MIT licensing, contribution documentation, and local/CI checks.

### Fixed

- Declare HTML/XHTML document types so LinkPort appears in macOS's default-browser selector.
- Refresh the menu before tracking and defer Settings presentation until the menu action completes.
- Hide the default-browser status section when LinkPort is already the default.
- Keep cancelled asynchronous browser operations from consuming newly received links.
- Preserve browser groups and persist drag reordering reliably.

### Validation limits

- Intel hardware, macOS 26 devices, full VoiceOver coverage, and some display/drag scenarios remain unverified. See the [test matrix](docs/testing.md).
- This community release retains ad-hoc signing, without Developer ID signing or Apple notarization. Gatekeeper may require the first-launch steps in the README.
