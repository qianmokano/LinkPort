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

Local verification on 2026-10-15: macOS 27.0.1, Apple Silicon, Xcode 27.0, Swift 6.4. `./scripts/check.sh` passed in the working checkout and in a fresh local clone of commit `0078d0c`, without copying build artifacts or ignored files. All **37 Swift tests and 11 tooling tests passed**. LinkPortCore line coverage was **99.35% (306/308)**.

Both release architectures compiled from scratch with a macOS 26 deployment target. The app's browser registration, icon resources, English/Chinese catalogs, MIT license, signature, ZIP contents, and SHA-256 manifest passed validation. The Swift Testing XML contains 37 test cases. Shell syntax checks, YAML parsing, local documentation links, and actionlint 1.7.12 also passed; the actionlint configuration explicitly permits GitHub's documented Xcode 27 preview label. The app sources, public APIs, package manifest, preferences, and application metadata are unchanged by this preparation.

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

## Publication hygiene review

The 2026-10-15 review covered 50 tracked text files (52 tracked files including two screenshots) and a pattern scan of 137 reachable historical text blobs at baseline `09285e5`. No common GitHub/AWS credential patterns, private-key headers, or personal home-directory paths were found. Email-like strings in test content use `example.com`. Git author metadata contains one non-noreply address; it was preserved, not promoted to a contact address. The [publication guide](releasing.md) records the required author-metadata review before making history public.

Both screenshots were visually checked: they show the app's example URL or General settings, and contain no PNG text-metadata chunks. The original app language and settings page were restored after capture. These targeted checks are preparation evidence, not a guarantee that every possible secret format has been detected.

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
