# resetusb

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/omkhar/resetusb/badge)](https://scorecard.dev/viewer/?uri=github.com/omkhar/resetusb)

`resetusb` is a Linux utility that enumerates USB devices and issues resets through `libusb`.
It is designed for operational recovery workflows where USB devices are stuck or misbehaving.
It has no flags or filtering options: when run, it attempts to reset every enumerated USB device it can open.

## Actions

Current GitHub Actions workflow status:

- [CI](https://github.com/omkhar/resetusb/actions/workflows/build-test.yml): [![CI](https://github.com/omkhar/resetusb/actions/workflows/build-test.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/build-test.yml)
- [Nightly Deep Validation](https://github.com/omkhar/resetusb/actions/workflows/nightly-deep.yml): [![Nightly Deep Validation](https://github.com/omkhar/resetusb/actions/workflows/nightly-deep.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/nightly-deep.yml)
- [ClusterFuzzLite Batch](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-batch.yml): [![ClusterFuzzLite Batch](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-batch.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-batch.yml)
- [ClusterFuzzLite PR](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-pr.yml): [![ClusterFuzzLite PR](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-pr.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/clusterfuzzlite-pr.yml)
- [CodeQL (codeql.yml)](https://github.com/omkhar/resetusb/actions/workflows/codeql.yml): [![CodeQL (codeql.yml)](https://github.com/omkhar/resetusb/actions/workflows/codeql.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/codeql.yml)
- [Dependency Review](https://github.com/omkhar/resetusb/actions/workflows/dependency-review.yml): [![Dependency Review](https://github.com/omkhar/resetusb/actions/workflows/dependency-review.yml/badge.svg)](https://github.com/omkhar/resetusb/actions/workflows/dependency-review.yml)
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

## Install

```bash
sudo make install
```

This installs the binary to `/usr/sbin/resetusb` and the man page to `/usr/share/man/man8/resetusb.8`.

## Run

```bash
sudo ./resetusb
```

Installed usage:

```bash
sudo /usr/sbin/resetusb
man 8 resetusb
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
make fuzz FUZZ_TIME=10
make release-preflight
```

The CI pipeline enforces:

- `ci/static-analysis`: `make lint`, `make check-format`, and `scan-build`
- `ci/unit-tests`: Linux unit tests with both `gcc` and `clang`
- `ci/sanitize`: AddressSanitizer + UndefinedBehaviorSanitizer test run
- `ci/package-smoke`: conditional stable distro smoke tests when release/build plumbing changes
- `pr-fuzzing`: ClusterFuzzLite presubmit fuzzing for pull requests
- `batch-fuzzing`: scheduled ClusterFuzzLite batch fuzzing
- `security-baseline`: diff-based `gitleaks` scanning on pull requests and pushes to `main`
- `nightly-deep-validation`: weekly full `release-preflight` execution, including the full package matrix and full-history secret scan
- `scorecard-analysis`: OpenSSF Scorecard scan on `main`, published to GitHub code scanning and `scorecard.dev`

Operational notes:

- `resetusb` exits `0` only when all attempted resets succeed.
- It exits `1` if any device reset fails, if it is not run as root, if the real and effective UIDs do not match, or if it cannot initialize or enumerate through `libusb`.
- Product strings from USB descriptors are sanitized before printing so non-printable bytes do not reach the terminal.

## Public Releases

- Public releases use semantic versioning and are published from signed annotated Git tags in the form `vMAJOR.MINOR.PATCH`.
- Push the signed tag first, then manually dispatch `.github/workflows/release.yml` from `main` with the matching `release_tag`.
- Releases are only published after the `release-preflight` job passes.
- The trusted release workflow on `main` delegates artifact builds and attestations to the dedicated reusable builder workflow at `.github/workflows/release-builder.yml` from the same pinned commit.
- Existing signed release tags can be rebuilt and republished by manually dispatching `.github/workflows/release.yml` on `main` with the `release_tag` input.
- Release tarballs contain the program plus the `resetusb(8)` manual page, and distro packages install both.
- Each release includes generic tarballs for:
  - `linux-amd64`
  - `linux-arm64`
  - `linux-armv7`
- Each release includes distro packages for:
  - Debian: `amd64`, `arm64`, `armhf`
  - Ubuntu: `amd64`, `arm64`, `armhf`
  - Fedora: `x86_64`
- Every primary artifact ships with:
  - a SHA256 checksum (`.sha256`)
  - an SPDX JSON SBOM (`.spdx.json`)
  - a Sigstore keyless bundle for the artifact (`.sigstore.json`)
  - a Sigstore keyless bundle for the checksum (`.sha256.sigstore.json`)
- GitHub Actions also emits per-asset GitHub provenance attestations and GitHub SBOM attestations from the dedicated builder workflow before publication.

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
sudo apt-get install ./resetusb-v2.0.3-debian-amd64.deb
```

Ubuntu:

```bash
sudo apt-get install ./resetusb-v2.0.3-ubuntu-amd64.deb
```

Fedora:

```bash
sudo dnf install ./resetusb-v2.0.3-fedora-x86_64.rpm
```

Generic tarball:

```bash
tar -xzf resetusb-v2.0.3-linux-amd64.tar.gz
sudo install -m 0755 v2.0.3-linux-amd64/resetusb /usr/sbin/resetusb
sudo install -m 0644 v2.0.3-linux-amd64/resetusb.8 /usr/share/man/man8/resetusb.8
```

Tarball runtime prerequisite: install the system `libusb-1.0` runtime first, for example `libusb-1.0-0` on Debian/Ubuntu or `libusb1` on Fedora.

Verify an artifact:

```bash
sha256sum -c resetusb-v2.0.3-ubuntu-amd64.deb.sha256
```

Verify Sigstore provenance (keyless):

```bash
cosign verify-blob \
  --bundle resetusb-v2.0.3-ubuntu-amd64.deb.sigstore.json \
  --certificate-identity-regexp '^https://github\.com/omkhar/resetusb/\.github/workflows/release-builder\.yml@refs/heads/main$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  resetusb-v2.0.3-ubuntu-amd64.deb
```

Verify the GitHub provenance attestation:

```bash
gh attestation verify \
  resetusb-v2.0.3-ubuntu-amd64.deb \
  --repo omkhar/resetusb \
  --signer-workflow omkhar/resetusb/.github/workflows/release-builder.yml
```

Verify the GitHub SBOM attestation:

```bash
gh attestation verify \
  resetusb-v2.0.3-ubuntu-amd64.deb \
  --repo omkhar/resetusb \
  --signer-workflow omkhar/resetusb/.github/workflows/release-builder.yml \
  --predicate-type https://spdx.dev/Document/v2.3
```

GitHub provenance for public releases is anchored to the trusted builder workflow on `main`; the workflow separately verifies the signed source tag before building.

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

## Documentation

- User-facing behavior and packaging notes in `README.md` should stay aligned with `resetusb(8)`.
- If you change CLI behavior, output semantics, installation paths, or release packaging, update `resetusb.8` in the same change.

## License

Apache-2.0 (see [LICENSE](LICENSE)).
