# resetusb

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/omkhar/resetusb/badge)](https://scorecard.dev/viewer/?uri=github.com/omkhar/resetusb)

`resetusb` is a Linux utility that enumerates USB devices and issues resets through `libusb`.
It is designed for operational recovery workflows where USB devices are stuck or misbehaving.

## Actions

Current GitHub Actions workflow status:

- [CI](https://github.com/omkhar/resetusb/actions/workflows/build-test.yml): [![CI](https://github.com/omkhar/resetusb/actions/workflows/build-test.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/build-test.yml)
- [ClusterFuzzLite Batch](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-batch.yml): [![ClusterFuzzLite Batch](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-batch.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-batch.yml)
- [ClusterFuzzLite PR](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-pr.yml): [![ClusterFuzzLite PR](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-pr.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-pr.yml)
- [CodeQL (codeql.yml)](https://github.com/omkhar/resetusb/actions/workflows/codeql.yml): [![CodeQL (codeql.yml)](https://github.com/omkhar/resetusb/actions/workflows/codeql.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/codeql.yml)
- [CodeQL (dynamic/github-code-scanning/codeql)](https://github.com/omkhar/resetusb/actions/workflows/dynamic/github-code-scanning/codeql): [![CodeQL (dynamic/github-code-scanning/codeql)](https://github.com/omkhar/resetusb/actions/workflows/dynamic/github-code-scanning/codeql/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/dynamic/github-code-scanning/codeql)
- [Dependabot Updates](https://github.com/omkhar/resetusb/actions/workflows/dynamic/dependabot/dependabot-updates): [![Dependabot Updates](https://github.com/omkhar/resetusb/actions/workflows/dynamic/dependabot/dependabot-updates/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/dynamic/dependabot/dependabot-updates)
- [Dependency Review](https://github.com/omkhar/resetusb/actions/workflows/dependency-review.yml): [![Dependency Review](https://github.com/omkhar/resetusb/actions/workflows/dependency-review.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/dependency-review.yml)
- [OSV Scanner](https://github.com/omkhar/resetusb/actions/workflows/osv-scanner.yml): [![OSV Scanner](https://github.com/omkhar/resetusb/actions/workflows/osv-scanner.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/osv-scanner.yml)
- [Package Publish](https://github.com/omkhar/resetusb/actions/workflows/package-publish.yml): [![Package Publish](https://github.com/omkhar/resetusb/actions/workflows/package-publish.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/package-publish.yml)
- [Release](https://github.com/omkhar/resetusb/actions/workflows/release.yml): [![Release](https://github.com/omkhar/resetusb/actions/workflows/release.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/release.yml)
- [Scorecard](https://github.com/omkhar/resetusb/actions/workflows/scorecard.yml): [![Scorecard](https://github.com/omkhar/resetusb/actions/workflows/scorecard.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/scorecard.yml)
- [Security Baseline](https://github.com/omkhar/resetusb/actions/workflows/security-baseline.yml): [![Security Baseline](https://github.com/omkhar/resetusb/actions/workflows/security-baseline.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/security-baseline.yml)
- [zizmor](https://github.com/omkhar/resetusb/actions/workflows/zizmor.yml): [![zizmor](https://github.com/omkhar/resetusb/actions/workflows/zizmor.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/zizmor.yml)

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
- `osv-scanner`: OSV dependency vulnerability scan for pull requests and pushes to `main`
- `package-publish`: publishes a minimal GHCR container package from `main` and release tags
- `pr-fuzzing`: ClusterFuzzLite presubmit fuzzing for pull requests
- `batch-fuzzing`: scheduled ClusterFuzzLite batch fuzzing
- `release-preflight`: release-gating Linux preflight and `gitleaks` scan
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
  - Fedora: `x86_64`
- A minimal GHCR container package is also published as `ghcr.io/omkhar/resetusb:<ref>`.
- Every primary artifact ships with:
  - a SHA256 checksum (`.sha256`)
  - a Sigstore keyless bundle for the artifact (`.sigstore.json`)
  - a Sigstore keyless bundle for the checksum (`.sha256.sigstore.json`)

Release validation matrix:

- Debian stable and Debian sid: `amd64`, `arm64`, `armv7`
- Ubuntu 24.04 and Ubuntu devel: `amd64`, `arm64`, `armv7`
- Fedora stable and Fedora rawhide: `amd64`

Platform guidance:

- x86/AMD: use `linux-amd64`, `debian-amd64.deb`, `ubuntu-amd64.deb`, or `fedora-x86_64.rpm`.
- Raspberry Pi 64-bit OS: use `linux-arm64`, `debian-arm64.deb`, or `ubuntu-arm64.deb`.
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
  --bundle resetusb-<tag>-ubuntu-amd64.deb.sigstore.json \
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
