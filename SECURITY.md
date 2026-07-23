# Security Policy

This document uses ASD-STE100 Simplified Technical English.

## Supported Platforms

- Linux (actively tested in CI)
- CI validates release artifacts on Debian stable and sid, Ubuntu 24.04 and devel, and Fedora stable and rawhide.

## Reporting a Vulnerability

Report vulnerabilities privately through GitHub Security Advisories for this repository:
https://github.com/omkhar/resetusb/security/advisories/new

If private reporting is not available, open an issue with minimal details.
Request a private follow-up.

Response targets:

- Initial acknowledgment: within 3 business days
- Status update: within 7 business days
- Coordinated disclosure: after maintainers provide a fix or document a mitigation

Please include:

- Affected semver release tag (for example `vMAJOR.MINOR.PATCH`) or commit SHA
- Reproduction steps
- Impact scope
- Any logs or proof-of-concept details

## Security Posture

- `resetusb` requires root by design.
- The runtime refuses mismatched real/effective UID execution contexts.
- CI covers static analysis, shell linting, unit tests, sanitizers, package validation, fuzzing, and secret scanning.
- The release CI toolchain uses snapshot-pinned inputs.
- Build and analysis jobs use the same inputs as the trusted builder.
- Branch rules require two approvals, code-owner review, approval after the last push, and resolved conversations.
- The rules require signed commits and all required checks.
- The rules also apply to repository administrators.
- The Debian snapshot setup uses Debian archive signing, a pinned base image digest, and a pinned snapshot `InRelease` digest.
- The initial snapshot fetch uses plain HTTP because the base image initially has no CA roots.
- `release-preflight` must succeed before publication.
- GitHub Actions builds public releases from signed annotated semver tags.
- The trusted builder workflow runs from the selected signed tag.
- It verifies the workflow revision before the build.
- It uses the snapshot-pinned inputs in `docker/release-builder.lock`.
- The release manifest records the commit digest and reproducible builder inputs.
- Release artifacts include generic tarballs, distribution packages, the `resetusb(8)` manual page, and SHA256 checksums.
- They include SPDX JSON SBOMs, Sigstore keyless bundles, GitHub provenance, and SBOM attestations.

## Out of Scope

- Security controls in downstream systems that run `resetusb` with root privileges.
- Hardware/firmware bugs in third-party USB devices.
