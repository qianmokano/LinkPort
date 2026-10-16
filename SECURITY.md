# Security policy

## Supported versions

The latest release in the **1.0.x** line is supported. Security fixes are developed on `main` and included in a patch release when needed. Use the latest available patch version when reporting a vulnerability.

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/qianmokano/LinkPort/security/advisories/new), also available from **Security → Advisories → Report a vulnerability** in the repository. Reports are private to the reporter and the people involved in investigating them. English and Chinese are both welcome. Do not publish exploit details or private URLs in public issues.

A private report should include the affected version/commit, macOS version and architecture, impact, and minimal reproduction using synthetic URLs or files. Remove credentials, tokens, private browsing information, and unrelated personal data. There is no promised response-time service level at this stage.

Coordinate disclosure with the maintainer while a fix is investigated. Ordinary bugs and feature requests belong in [Issues](https://github.com/qianmokano/LinkPort/issues).

## Security boundaries

LinkPort receives URLs through macOS and passes a chosen URL to an installed browser or the system clipboard. It does not load web content itself, make network requests, or persist URL history. The selected browser and macOS clipboard have their own data handling behavior.

Browser order, visibility, language, and the welcome preference are stored locally. Automated tests use replacement services and isolated preferences. Default-browser changes and system consent remain explicit user actions.

Community packages retain ad-hoc signing and have no Developer ID signature or Apple notarization. Developer ID signing and notarization are a separate distribution path described in the [release guide](docs/releasing.md). Never commit certificates, signing keys, notarization credentials, or private reports to this repository.
