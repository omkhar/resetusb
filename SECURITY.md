# Security Policy

## Supported Platform

- Linux (actively tested in CI)

## Reporting a Vulnerability

Please report suspected vulnerabilities privately through GitHub Security Advisories for this repository.
If private reporting is not available, open an issue with minimal details and request a private follow-up channel.

Include:

- Affected version or commit SHA
- Reproduction steps
- Impact scope
- Any logs or proof-of-concept details

## Security Posture

- Root-only execution is required by design.
- CI enforces static analysis (`cppcheck`, `scan-build`) and shell script linting (`shellcheck`).
- Public releases are generated in GitHub Actions from signed tags and include SHA256 checksums.
- No staging or production auto-deployment workflow exists in this repository.

## Out of Scope

- Security of downstream systems where `resetusb` is executed with elevated privileges.
- Hardware/firmware bugs in third-party USB devices.
