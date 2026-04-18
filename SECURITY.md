# Security Policy

## Supported Platforms

- Linux (actively tested in CI)
- Release artifacts are validated on Debian stable/sid, Ubuntu 24.04/devel, and Fedora stable/rawhide.

## Reporting a Vulnerability

Please report vulnerabilities privately through GitHub Security Advisories for this repository:
https://github.com/omkhar/resetusb/security/advisories/new

If private reporting is not available, open an issue with minimal details and request a private follow-up.

Response targets:

- Initial acknowledgment: within 3 business days
- Status update: within 7 business days
- Coordinated disclosure: after a fix is available or mitigation is documented

Please include:

- Affected semver release tag (for example `vMAJOR.MINOR.PATCH`) or commit SHA
- Reproduction steps
- Impact scope
- Any logs or proof-of-concept details

## Security Posture

- `resetusb` requires root by design.
- The runtime refuses mismatched real/effective UID execution contexts.
- CI covers static analysis, shell linting, unit tests, sanitizers, package validation, fuzzing, and secret scanning.
- The release-adjacent CI toolchain is snapshot-pinned so build and analysis jobs do not drift independently from the trusted builder.
- The default branch requires pull-request review plus code-owner review for
  contributed changes, while the single repository owner retains pull-request
  bypass rights for self-maintained changes.
- The Debian snapshot bootstrap path uses Debian archive signing, the pinned base image digest, and a pinned snapshot `InRelease` digest for integrity. The initial snapshot fetch remains plain HTTP because CA roots are not available until the first package install.
- Releases are published only after `release-preflight` succeeds.
- Public releases are built in GitHub Actions from signed annotated semver tags. The trusted builder workflow runs from the selected signed tag, verifies that workflow revision before building, uses the snapshot-pinned inputs recorded in `docker/release-builder.lock`, and the published release manifest records the commit digest and reproducible builder inputs that were built.
- Release artifacts include generic tarballs, distro-specific packages, the `resetusb(8)` manual page, SHA256 checksums, SPDX JSON SBOMs, Sigstore keyless bundles (`.sigstore.json`), and GitHub provenance plus SBOM attestations.

## Out of Scope

- Security of downstream systems where `resetusb` is executed with elevated privileges.
- Hardware/firmware bugs in third-party USB devices.
