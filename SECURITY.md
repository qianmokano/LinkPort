# Security policy

## Supported versions

LinkPort 1.0.0 is currently unreleased. Security fixes are made on the current `main` branch. There are no supported published release lines yet; this policy will be updated when releases begin.

## Reporting a vulnerability

**The private vulnerability reporting channel is pending setup.** No public repository or designated security email has been configured. Existing Git author email addresses are not security contacts.

Before publishing, the maintainer must enable GitHub private vulnerability reporting, verify that **Security → Report a vulnerability** is available, and update this policy with the verified repository link. Until then, use an already established private channel with the maintainer, if you have one. Do not publish exploit details or private URLs in issues; wait for a private channel if one is unavailable.

A private report should include the affected version/commit, macOS version and architecture, impact, and minimal reproduction using synthetic URLs or files. Remove credentials, tokens, private browsing information, and unrelated personal data. There is no promised response-time service level at this stage.

Coordinate disclosure with the maintainer while a fix is investigated. Ordinary bugs and feature requests belong in the issue tracker once it exists.

## Security boundaries

LinkPort receives URLs through macOS and passes a chosen URL to an installed browser or the system clipboard. It does not load web content itself, make network requests, or persist URL history. The selected browser and macOS clipboard have their own data handling behavior.

Browser order, visibility, language, and the welcome preference are stored locally. Automated tests use replacement services and isolated preferences. Default-browser changes and system consent remain explicit user actions.

Development packages use ad-hoc signing. Public distribution requires a separate signing and notarization process described in the [release guide](docs/releasing.md). Never commit certificates, signing keys, notarization credentials, or private reports to this repository.
