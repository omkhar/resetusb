# resetusb

[![CI](https://github.com/omkhar/resetusb/workflows/CI/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/build-test.yml)
[![Dependency Review](https://github.com/omkhar/resetusb/workflows/Dependency%20Review/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/dependency-review.yml)
[![Release](https://github.com/omkhar/resetusb/workflows/Release/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/release.yml)
[![Security Baseline](https://github.com/omkhar/resetusb/workflows/Security%20Baseline/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/security-baseline.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/omkhar/resetusb/badge)](https://scorecard.dev/viewer/?uri=github.com/omkhar/resetusb)

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
- `ci-package-integration`: signed-release artifact build plus stable/unstable package and tarball smoke tests
- `release-preflight`: release-gating Linux preflight, `gitleaks`, and Trivy scans
- `scorecard-analysis`: OpenSSF Scorecard scan on `main`, published to GitHub code scanning and `scorecard.dev`

## Public Releases

- Public release artifacts are published from signed annotated Git tags (`v*`) via `.github/workflows/release.yml`.
- Releases are only published after the `release-preflight` job passes.
- Each release includes generic tarballs for:
  - `linux-amd64`
  - `linux-arm64`
  - `linux-armv7`
- Each release includes distro packages for:
  - Debian: `amd64`, `arm64`, `armhf`
  - Ubuntu: `amd64`, `arm64`, `armhf`
  - Fedora: `x86_64`, `aarch64`
- Every primary artifact ships with:
  - a SHA256 checksum (`.sha256`)
  - a Sigstore keyless bundle for the artifact (`.bundle.json`)
  - a Sigstore keyless bundle for the checksum (`.sha256.bundle.json`)

Release validation matrix:

- Debian stable and Debian sid: `amd64`, `arm64`, `armv7`
- Ubuntu 24.04 and Ubuntu devel: `amd64`, `arm64`, `armv7`
- Fedora stable and Fedora rawhide: `amd64`, `arm64`

Platform guidance:

- x86/AMD: use `linux-amd64`, `debian-amd64.deb`, `ubuntu-amd64.deb`, or `fedora-x86_64.rpm`.
- Raspberry Pi 64-bit OS: use `linux-arm64`, `debian-arm64.deb`, `ubuntu-arm64.deb`, or `fedora-aarch64.rpm`.
- Raspberry Pi 32-bit OS: use `linux-armv7`, `debian-armhf.deb`, or `ubuntu-armhf.deb`.

Install examples:

Debian:

```bash
sudo apt-get install ./resetusb-<tag>-debian-amd64.deb
```

Ubuntu:

```bash
sudo apt-get install ./resetusb-<tag>-ubuntu-amd64.deb
```

Fedora:

```bash
sudo dnf install ./resetusb-<tag>-fedora-x86_64.rpm
```

Generic tarball:

```bash
tar -xzf resetusb-<tag>-linux-amd64.tar.gz
sudo install -m 0755 <tag>-linux-amd64/resetusb /usr/sbin/resetusb
```

Verify an artifact:

```bash
sha256sum -c resetusb-<tag>-ubuntu-amd64.deb.sha256
```

Verify Sigstore provenance (keyless):

```bash
cosign verify-blob \
  --bundle resetusb-<tag>-ubuntu-amd64.deb.bundle.json \
  --certificate-identity-regexp '^https://github\.com/omkhar/resetusb/\.github/workflows/release\.yml@refs/tags/.*$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  resetusb-<tag>-ubuntu-amd64.deb
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
