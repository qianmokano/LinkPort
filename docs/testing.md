# Testing and compatibility

[Development](development.md) · [Release guide](releasing.md) · [Historical notes, Chinese](validation-history.zh-CN.md)

## Automated checks

Run from a clean checkout with the documented toolchain:

```sh
./scripts/check.sh
```

The command tests the repository tooling, parses app metadata and both localization catalogs, checks local Markdown links, runs all Swift tests, enforces core coverage, builds both architectures, verifies app resources and deployment targets, compares the ZIP with the app, and checks the signature and ZIP checksum.

The baseline Swift suite has **37 tests**, including parameterized cases. It covers URL validation and preservation, local web files, FIFO/deduplication, browser discovery and grouped order, preferences, language, geometry, default-handler refusal, opening/copy failures, and cancellation races. Four AppKit flow tests use mock window presentation; the registration test reads the actual app metadata. The test suite does not change real browser defaults, launch browsers, or write to the system clipboard.

The additional Python suite checks coverage calculations and threshold failures, incomplete/corrupt inputs, metadata drift, localization arguments and duplicate keys, relative links, packaged resources/ZIP consistency, and early toolchain failure. It uses temporary fixtures and mocked external commands.

Reports are under `.build/reports/`. The coverage gate is **80% line coverage of LinkPortCore**, with all core source files required. It does not measure SwiftUI/AppKit UI or the native browser adapter. See the JSON report for exact counts; avoid treating old validation percentages as current results.

## Current verification record

Local baseline, 2026-10-15: macOS 27.0.1, Apple Silicon, Xcode 27.0, Swift 6.4. Before the open-source preparation, all 37 Swift tests passed and core line coverage was 99.35% (306/308). The preparation adds 11 tooling tests and retains the same app behavior. Final preparation checks and clean-checkout results are recorded below after execution.

Hosted CI has not run: no remote repository is configured. Signing is ad-hoc; no notarization or public release is claimed.

| Scenario | Evidence / status |
| --- | --- |
| macOS 27, Apple Silicon | Previously exercised locally: launch, picker, settings, links, copying, language, and menu interaction |
| Universal binary | Automated arm64/x86_64 build, architecture and macOS 26 deployment-target validation |
| Intel via Rosetta | Previously launched; not equivalent to an Intel hardware test |
| Intel hardware | Pending |
| macOS 26 hardware | Pending; availability fallback has been compiled, not device-verified |
| Default-browser candidate | HTML/XHTML registration fix previously confirmed in System Settings; mock status/refusal tests remain automated |
| Settings focus | Previously checked locally; repeated status clicks, Spaces, and fullscreen transitions still need broader use |
| Drag reordering | User previously confirmed persisted order; full native gap animation and long held edge-drag paths need manual validation |
| Displays | Geometry tests include corners and negative coordinates; physical multi-display boundary testing pending |
| Appearance and accessibility | Light-mode screenshots checked; full dark-mode and VoiceOver workflows pending |

Historical notes record exploratory work, superseded approaches, and earlier test counts. They provide context, not additional claims of current coverage.

## Manual release checklist

Record app version/commit, macOS version, CPU, native/Rosetta mode, and pass/fail for each exercised item. Use synthetic links only. Default-browser changes require the tester's explicit action.

- [ ] Install one app copy in Applications; launch, reopen, and close Settings; confirm menu-bar lifetime.
- [ ] Preview the picker, cancel with Escape and by clicking outside, then reopen it.
- [ ] Choose LinkPort as the default via macOS confirmation; check HTTP and HTTPS, candidate visibility, and menu status. Restore the prior browser after testing if desired.
- [ ] Accept and reject a default-browser change in separate runs; inspect actual handler status rather than just success messages.
- [ ] Send an encoded example URL, multiple links, and local HTML/XHTML; verify browser handoff and clipboard contents, including query and fragment.
- [ ] Navigate with arrows, Return, `⌘1`–`⌘9`, and `⌘C`; try enough browsers to require scrolling and an all-hidden list.
- [ ] Reorder within enabled/hidden groups, toggle across boundaries, hold a drag near both edges, and check persistence after restart.
- [ ] Switch languages, light/dark appearance, and use VoiceOver through settings and the picker.
- [ ] Exercise multiple physical displays, screen corners, Spaces, and fullscreen apps.
- [ ] Test on macOS 26 and Intel hardware; record these separately from cross-builds and Rosetta.
- [ ] Verify the final signed, stapled distribution archive as described in the release guide.

## Updating this record

Run the complete check after changing scripts, resources, or behavior. Record the actual command, environment, core coverage from the generated JSON, and outstanding manual checks. Keep hosted-CI status separate from local checks. New UI screenshots should use the app's example preview and never include private links.
