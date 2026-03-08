# resetusb

`resetusb` is a Linux utility that enumerates USB devices and issues resets through `libusb`.
It is designed for operational recovery workflows where USB devices are stuck or misbehaving.

## Safety and Scope

- `resetusb` requires root privileges.
- It refuses `setuid`-style or other mismatched real/effective UID invocations.
- It resets every enumerated USB device, including hubs.
- This can interrupt keyboards, storage, serial devices, and USB-backed networking.
- Use only during controlled maintenance windows or recovery procedures.

## Requirements

- Linux
- `libusb-1.0` development headers (`libusb-1.0-0-dev` on Debian/Ubuntu)
- C toolchain (`gcc`/`clang`) and `make`

## Build

```bash
make
```

## Run

```bash
sudo ./resetusb
```

Example output:

```text
reset bus 1 device 2 (1234:5678) Example Device
Summary: reset 1 device(s), 0 failure(s)
```

## Test and Verification

```bash
make test
```

Additional contributor checks:

```bash
make lint
make check-format
make sanitize
make release-preflight
```

The CI pipeline enforces:

- `ci-security`: `make lint`, `make check-format`, and `scan-build`
- `ci-build`: Linux build with `ccache`
- `ci-test`: unit tests with `ccache`
- `ci-sanitize`: AddressSanitizer + UndefinedBehaviorSanitizer test run
- `release-preflight`: release-gating Linux preflight, `gitleaks`, and Trivy scans

## Public Releases

- Public release artifacts are published from signed annotated Git tags (`v*`) via `.github/workflows/release.yml`.
- Releases are only published after the `release-preflight` job passes.
- Each release includes:
  - `resetusb-<tag>-linux-amd64.tar.gz`
  - `resetusb-<tag>-linux-amd64.tar.gz.sha256`
  - `resetusb-<tag>-linux-arm64.tar.gz`
  - `resetusb-<tag>-linux-arm64.tar.gz.sha256`
  - `resetusb-<tag>-linux-armv7.tar.gz`
  - `resetusb-<tag>-linux-armv7.tar.gz.sha256`
  - `resetusb-<tag>-linux-amd64.tar.gz.bundle.json`
  - `resetusb-<tag>-linux-amd64.tar.gz.sha256.bundle.json`
  - `resetusb-<tag>-linux-arm64.tar.gz.bundle.json`
  - `resetusb-<tag>-linux-arm64.tar.gz.sha256.bundle.json`
  - `resetusb-<tag>-linux-armv7.tar.gz.bundle.json`
  - `resetusb-<tag>-linux-armv7.tar.gz.sha256.bundle.json`

Platform guidance:

- x86/AMD: use `linux-amd64` (64-bit only).
- Raspberry Pi 64-bit OS: use `linux-arm64`.
- Raspberry Pi 32-bit OS: use `linux-armv7`.

Verify an artifact:

```bash
sha256sum -c resetusb-<tag>-linux-amd64.tar.gz.sha256
```

Verify Sigstore provenance (keyless):

```bash
cosign verify-blob \
  --bundle resetusb-<tag>-linux-amd64.tar.gz.bundle.json \
  --certificate-identity-regexp '^https://github\.com/omkhar/resetusb/\.github/workflows/release\.yml@refs/tags/.*$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  resetusb-<tag>-linux-amd64.tar.gz
```

## Collaboration

- Report bugs: open a GitHub Issue with logs and reproduction steps.
- Propose changes: open a PR and follow `.github/pull_request_template.md`.
- Security reports: see [SECURITY.md](SECURITY.md).
- Development guidance: see [CONTRIBUTING.md](CONTRIBUTING.md).
- Community expectations: see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Coding Style

- C source follows Linux kernel style conventions.
- Formatting is enforced with `.clang-format`.
- Run `make format` before submitting style-related changes.

## License

Apache-2.0 (see [LICENSE](LICENSE)).
