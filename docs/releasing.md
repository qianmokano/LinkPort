# Release and publication guide

[Development](development.md) · [Testing](testing.md) · [Changelog](../CHANGELOG.md) · [Security policy](../SECURITY.md)

This is an operator guide. Version **1.0.0, build 2** is currently unreleased. The repository preparation does not create a remote, push a tag, publish a release, or perform Apple signing/notarization.

## Before making the repository public

1. Choose the actual repository owner and name; add only verified repository URLs to documentation. Run hosted CI and confirm its results before adding a status badge.
2. Review tracked files and Git history for credentials, local paths, private data, and author metadata. Existing history includes a non-noreply author email. Preserving history also preserves that address; decide explicitly whether it is suitable for publication. Do not silently rewrite history. Revoke any exposed credential before considering history cleanup.
3. Confirm rights to source and assets. The project code, docs, and original branch artwork use MIT; browser icons shown in screenshots belong to their respective owners.
4. Enable GitHub private vulnerability reporting and verify the report action. Establish a private conduct-reporting channel, then replace the pending notices in the security policy and code of conduct. Do not infer a contact address from Git commits.
5. Enable Issues and Actions, inspect the issue forms, and run CI on the actual public repository. Configure branch protection to require its check after the first successful run. Repository settings are not applied by the local workflow files.
6. Remove the temporary local-preparation wording from the READMEs and contribution guide once those statements are no longer true. Downloads should link to a real release only after one exists.

## Versioning and preparation

- Use Semantic Versioning (`MAJOR.MINOR.PATCH`) in `CFBundleShortVersionString`; use a positive, increasing integer for `CFBundleVersion`. Keep `com.linkport.app` and compatible preference keys stable.
- Keep changes under Unreleased until the release is actually prepared. For the first release, move the 1.0.0 notes into a dated release section. Later versions get a new Unreleased section.
- Release tags use `vMAJOR.MINOR.PATCH` and must match the app version. Review the changelog, both READMEs, test matrix, and known limitations before tagging.

From a clean checkout of the intended commit, run:

```sh
./scripts/check.sh
```

The output app and ZIP are ad-hoc signed development artifacts. CI artifacts have the same status and are not notarized consumer downloads. Preserve the reports with the release review and complete the relevant device tests in the [manual checklist](testing.md).

## Developer ID signing and notarization

Public distribution outside the Mac App Store uses a **Developer ID Application** certificate and Apple notarization. The maintainer must supply an appropriate Apple Developer account and certificate; the project contains neither credentials nor an automated release workflow. Consult Apple's [notarization overview](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [custom workflow guide](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

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

Extract the final archive to a separate location. Verify both architectures and the macOS 26 deployment targets, MIT license, English/Chinese catalogs, signature, notarization ticket, and Gatekeeper assessment. Test that exact extracted app on the supported devices available; record missing devices explicitly. Do not make it the default merely to inspect it.

After review, create the matching Git tag and a draft GitHub Release from that commit. Attach the final `LinkPort.zip` and `SHA256SUMS`, and include installation steps, system requirements, signing/notarization status, known limitations, and the changelog. Review the draft and publish it as a separate maintainer action. Never attach the pre-notarization or ad-hoc CI artifact as the signed release.

Keep the original source commit/tag available with the distributed binary, preserve MIT notices in redistributions, and update download links only after the release is accessible.
