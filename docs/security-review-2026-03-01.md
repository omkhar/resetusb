# Security Review 2026-03-01

## Scope

- `resetusb.c`
- `resetusb.h`
- `tests/resetusb_unit_tests.c`
- `.github/workflows/*`
- `docker/release-builder.Dockerfile`

## Summary

- Runtime behavior is root-gated and explicitly warns operators about disruptive resets.
- USB device metadata is sanitized before logging to limit control-character injection.
- CI enforces static analysis (`cppcheck`, `scan-build`), secret scanning (`gitleaks`), and dependency review.
- Release artifacts are checksummed and signed with Sigstore keyless signatures.

## Residual Risk

- Running as root is inherently high impact.
- Device reset behavior can disrupt active USB storage, HID, and networking paths.

## Recommendations

- Keep workflow action references pinned to immutable SHAs.
- Preserve Linux-only build/test assumptions in CI and release tooling.
- Require formatting/lint/static-analysis checks before merge.
