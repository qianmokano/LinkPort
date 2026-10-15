# Contributing to LinkPort

Issues, pull requests, and discussion may be in **English or Chinese**. Please follow the [code of conduct](CODE_OF_CONDUCT.md).

## Before making a change

- Search existing issues when a hosted repository is available. For a substantial feature, describe the problem and proposed behavior before implementation.
- Report bugs with the app version, macOS version, CPU architecture, reproduction steps, and expected/actual behavior. Use example URLs and remove private data from screenshots and logs.
- For vulnerabilities, follow [SECURITY.md](SECURITY.md) rather than posting reproduction details publicly.
- The current product focuses on choosing a browser or copying a link. Rules, profiles, sync, extensions, and automatic updates require a separate design discussion.

## Development

Install the tools listed in the [development guide](docs/development.md). Open `Package.swift` in Xcode or use the command line:

```sh
./scripts/test.sh
./scripts/check.sh
```

Use `./scripts/test.sh --filter TestName` for focused Swift tests. The complete check runs all tests, enforces at least 80% line coverage for LinkPortCore, validates resources, and builds the Universal app. Keep generated `.build/` and `dist/` files out of Git.

## Code and tests

- Match surrounding Swift naming, imports, four-space indentation, and small functions. Follow `.editorconfig`; avoid unrelated formatting changes.
- Keep queue, catalog, preference, and state logic in LinkPortCore. Use `BrowserSystem` and `PreferenceStore` to replace external behavior in tests.
- Add meaningful regression tests for behavior changes, including failures and edge cases. Never change the real default browser, clipboard, or installed browsers in automated tests.
- Preserve macOS 26 compatibility. Guard newer API calls with availability checks; compile with Xcode 27 or later.
- Update both localization catalogs together, retaining the same format arguments. Update both READMEs when user-facing behavior changes.
- UI changes should include screenshots made with example links and notes about keyboard navigation, appearance, and accessibility checks.

## Pull requests

Keep changes focused and explain the problem, resulting behavior, and validation. Include commands actually run and note device tests still outstanding. Do not present cross-compilation or Rosetta as Intel hardware testing. Ensure `./scripts/check.sh` passes before requesting review.

Use descriptive commits, for example `Fix picker dismissal after copying a link` or `Document browser registration requirements`. A particular commit prefix, CLA, or DCO sign-off is not required. Do not overwrite unrelated work, rewrite shared history, or include signing credentials.

Contributions are accepted under the project's [MIT License](LICENSE). Only submit material you have the right to license, and preserve any required third-party notices.

## Local preparation status

Hosted issue forms and CI are prepared but have not run remotely yet. Until a public repository and private contact channel exist, coordinate contributions directly with the maintainer through an already established channel. Publication steps are in the [release guide](docs/releasing.md).
