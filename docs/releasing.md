# Release and publication guide

[Development](development.md) · [Testing](testing.md) · [Changelog](../CHANGELOG.md) · [Security policy](../SECURITY.md)

This is an operator guide for [qianmokano/LinkPort](https://github.com/qianmokano/LinkPort). Version **1.0.0, build 2** is currently unreleased. Publishing the source does not publish a version tag, release, or download package.

## Repository administration

1. Keep [Issues](https://github.com/qianmokano/LinkPort/issues), [Actions](https://github.com/qianmokano/LinkPort/actions/workflows/ci.yml), and [private vulnerability reporting](https://github.com/qianmokano/LinkPort/security/advisories/new) enabled. Use the published contact in the [code of conduct](../CODE_OF_CONDUCT.md) for conduct reports.
2. Protect `main` with the actual CI check, prohibit force pushes and deletion, and retain the default administrator bypass. Additional approving reviews are not required. Repository settings are managed on GitHub, separately from workflow files.
3. Review tracked files and `main` history for credentials, local paths, private data, and author metadata before publishing further history. The existing non-noreply author address is intentionally preserved with the original commits; do not rewrite shared history silently. Internal refs, temporary clones, and build directories are excluded from the published branch.
4. Preserve the MIT notices for the project code, documentation, and original branch artwork. Browser icons shown in screenshots belong to their respective owners.
5. Keep both READMEs and the [verification record](testing.md) accurate. Link downloads only after a release exists; add CI badges only after a successful hosted run.

## Versioning and preparation

- Use Semantic Versioning (`MAJOR.MINOR.PATCH`) in `CFBundleShortVersionString`; use a positive, increasing integer for `CFBundleVersion`. Keep `com.linkport.app` and compatible preference keys stable.
- Keep changes under Unreleased until the release is actually prepared. For the first release, move the 1.0.0 notes into a dated release section. Later versions get a new Unreleased section.
- Release tags use `vMAJOR.MINOR.PATCH` and must match the app version. Review the changelog, both READMEs, test matrix, and known limitations before tagging.

From a clean checkout of the intended commit, run:

```sh
./scripts/check.sh
```

The output app and ZIP retain ad-hoc signing, with no Developer ID signature or Apple notarization. CI uploads are temporary development artifacts, not published releases. Preserve the reports with the release review and complete the relevant device tests in the [manual checklist](testing.md).

## Community distribution with ad-hoc signing

This is the community distribution path: retain the build script's ad-hoc signature and package the resulting app without Developer ID signing or Apple notarization. Describe it explicitly as **ad-hoc signed and not notarized**. Do not remove its existing signature or imply that Apple has verified the developer.

Gatekeeper may block the downloaded app. Include the graphical first-launch steps and quarantine-removal option from the [README](../README.md#if-macos-blocks-the-app-gatekeeper), along with system requirements and any outstanding device tests. Test the exact downloaded archive while its quarantine attribute is still present before recording first-launch behavior. No 1.0.0 community package is published as part of making this source repository public.

After successful checks, continue to **Review and publish** below. The Developer ID path is optional and requires its own signing and notarization steps.

## Developer ID signing and notarization

For a Developer ID signed and notarized distribution, use a **Developer ID Application** certificate and Apple notarization. The maintainer must supply an appropriate Apple Developer account and certificate; the project contains neither credentials nor an automated release workflow. Consult Apple's [notarization overview](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [custom workflow guide](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

Perform the following on the trusted release machine after successful checks. Set `LINKPORT_SIGNING_IDENTITY` locally to your actual certificate identity. Use an interactive Keychain profile for notarization credentials; never put passwords, private keys, certificates, or tokens in tracked files or command output.

```sh
# Run once to create an interactive credential profile in Keychain.
xcrun notarytool store-credentials LinkPort-notary

# Run from the repository root after ./scripts/check.sh.
# LINKPORT_SIGNING_IDENTITY must identify your Developer ID Application certificate.
codesign --force --options runtime --timestamp \
  --sign "$LINKPORT_SIGNING_IDENTITY" dist/LinkPort.app
codesign --verify --strict --verbose=2 dist/LinkPort.app

ditto -c -k --sequesterRsrc --keepParent \
  dist/LinkPort.app .build/LinkPort-notarization.zip
xcrun notarytool submit .build/LinkPort-notarization.zip \
  --keychain-profile LinkPort-notary --wait
```

Proceed only when the notarization submission is **Accepted**. If it fails, inspect the submission log, fix the problem, and repeat the signing/submission steps. The app currently has one executable and no embedded third-party frameworks; if that changes, sign nested code from the inside out rather than using `--deep` as a signing shortcut. Any necessary entitlements need a separate review.

```sh
xcrun stapler staple dist/LinkPort.app
xcrun stapler validate dist/LinkPort.app
codesign --verify --strict --verbose=2 dist/LinkPort.app
spctl --assess --type execute --verbose=4 dist/LinkPort.app

# Recreate the ZIP after stapling; the earlier archive lacks the ticket.
ditto -c -k --sequesterRsrc --keepParent dist/LinkPort.app dist/LinkPort.zip
python3 scripts/verify.py bundle
cd dist
shasum -a 256 LinkPort.zip > SHA256SUMS
shasum -a 256 -c SHA256SUMS
```

Do not rerun the build or full check after signing: it replaces the output with a fresh ad-hoc build. Any code or resource change requires a fresh build, tests, signing, notarization, stapling, and archive/checksum generation.

## Review and publish

Extract the final archive to a separate location. Verify both architectures and the macOS 26 deployment targets, MIT license, English/Chinese catalogs, and the signature appropriate to the selected path. For Developer ID distribution, also verify the stapled notarization ticket and successful Gatekeeper assessment. For community distribution, record the ad-hoc signature and actual Gatekeeper first-launch behavior without claiming notarization. Test that exact extracted app on the supported devices available; record missing devices explicitly. Do not make it the default merely to inspect it.

When a version release is separately authorized, create the matching Git tag and a draft GitHub Release from that reviewed commit. Attach the final `LinkPort.zip` and `SHA256SUMS`, and include installation steps, system requirements, signing/notarization status, known limitations, and the changelog. Review the draft and publish it as a separate maintainer action. A community archive must be labeled ad-hoc signed and not notarized; a Developer ID release must use the final stapled archive. Never describe a CI artifact as a Developer ID signed or notarized release.

Keep the original source commit/tag available with the distributed binary, preserve MIT notices in redistributions, and update download links only after the release is accessible.
