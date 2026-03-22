# Security Policy

## Supported Platform

- Linux (actively tested in CI)
- Release artifacts are validated on Debian stable/sid, Ubuntu 24.04/devel, and Fedora stable/rawhide.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately through GitHub Security Advisories for this repository:
https://github.com/omkhar/resetusb/security/advisories/new

If private reporting is not available, open an issue with minimal details and request a private follow-up channel.

Maintainer response target:

- Initial acknowledgment: within 3 business days
- Status update: within 7 business days
- Coordinated disclosure: after a fix is available or mitigation is documented

Include:

- Affected version or commit SHA
- Reproduction steps
- Impact scope
- Any logs or proof-of-concept details

## Security Posture

- Root-only execution is required by design.
- The runtime refuses mismatched real/effective UID execution contexts.
- CI enforces static analysis (`cppcheck`, `scan-build`), shell script linting (`shellcheck`), dual-compiler unit tests (`gcc`, `clang`), and sanitizer coverage.
- CI validates release packages and generic tarballs with a reduced stable smoke matrix on packaging-related pull requests, then re-runs the full stable/unstable distro matrix before release publication.
- ClusterFuzzLite provides presubmit and scheduled fuzzing coverage for input sanitization paths.
- CI secret scanning uses diff-based `gitleaks` on pull requests and pushes, with full-history scanning in weekly deep validation and release preflight.
- Release publication is gated by a full `release-preflight` pass before artifacts are uploaded.
- Public releases are generated in GitHub Actions from signed annotated tags that are verified against the pinned maintainer release key.
- Release artifacts include generic tarballs, distro-specific packages, SHA256 checksums, SPDX JSON SBOMs, Sigstore keyless bundles (`.sigstore.json`), and per-asset GitHub provenance plus SBOM attestations.

## Out of Scope

- Security of downstream systems where `resetusb` is executed with elevated privileges.
- Hardware/firmware bugs in third-party USB devices.
