# resetusb

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/omkhar/resetusb/badge)](https://scorecard.dev/viewer/?uri=github.com/omkhar/resetusb)

`resetusb` resets USB devices on Linux through `libusb`.
Use it during recovery or maintenance when a device stops responding and needs
to be re-enumerated.

`resetusb` has no flags or filtering. When you run it, it attempts to reset
every enumerated USB device it can open.

## Project Status

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
- Use it only during controlled maintenance or recovery work.

## Runtime Requirements

- Linux
- Root privileges
- A system `libusb-1.0` runtime when using the generic tarball (`libusb-1.0-0` on Debian/Ubuntu or `libusb1` on Fedora)

## Build From Source

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

## Usage

```bash
sudo ./resetusb
```

After installation:

```bash
sudo /usr/sbin/resetusb
man 8 resetusb
```

Example output:

```text
reset bus 1 device 2 (1234:5678) Example Device
Summary: reset 1 device(s), 0 failure(s)
```

## Development

```bash
make test
```

Additional checks:

```bash
make lint
make check-format
make sanitize
make fuzz FUZZ_TIME=10
make release-preflight
```

CI covers linting, unit tests, sanitizers, package validation, fuzzing, secret
scanning, and Scorecard checks.

Notes:

- `resetusb` exits `0` only when all attempted resets succeed.
- It exits `1` if any device reset fails, if it is not run as root, if the real and effective UIDs do not match, or if `libusb` initialization or enumeration fails.
- USB product strings are sanitized before printing so non-printable bytes do not reach the terminal.

## Releases

- Public releases use semantic versioning and signed annotated tags in the form `vMAJOR.MINOR.PATCH`.
- Release tags are immutable. If release contents need to change, a new patch version is cut.
- Publication only happens after `release-preflight` succeeds, including a repeat-build digest comparison for the release artifacts.
- The trusted builder is pinned by `docker/release-builder.lock`, which fixes both the Debian base image digest and the Debian snapshot used for build dependencies.
- CI build/test jobs use the same snapshot-pinned Debian inputs as the release path, so the compiler and analysis toolchain does not drift independently of the release builder.
- Tarballs include the binary and the `resetusb(8)` manual page. Distro packages install both.
- Each release includes tarballs for:
  - `linux-amd64`
  - `linux-arm64`
  - `linux-armv7`
- Each release includes distro packages for:
  - Debian: `amd64`, `arm64`, `armhf`
  - Ubuntu: `amd64`, `arm64`, `armhf`
  - Fedora: `x86_64`
- Each primary artifact also includes:
  - a SHA256 checksum (`.sha256`)
  - an SPDX JSON SBOM (`.spdx.json`)
  - a Sigstore keyless bundle for the artifact (`.sigstore.json`)
  - a Sigstore keyless bundle for the checksum (`.sha256.sigstore.json`)
- Each release also includes a builder-signed release manifest (`resetusb-vMAJOR.MINOR.PATCH-release-manifest.json`) with the release tag, the commit digest resolved from the signed tag, the trusted builder digest, the reproducible builder inputs, and SHA256 hashes for the primary artifacts. The manifest contract is versioned and documented in `release-manifest.schema.json`.
- GitHub Actions also emits per-asset provenance and SBOM attestations before publication, and publish re-verifies them against the trusted builder workflow revision.
- Maintainer release steps are documented in `CONTRIBUTING.md`.

Release validation matrix:

- Debian stable and Debian sid: `amd64`, `arm64`, `armv7`
- Ubuntu 24.04 and Ubuntu devel: `amd64`, `arm64`, `armv7`
- Fedora stable and Fedora rawhide: `amd64`

Choose an artifact:

- x86/AMD: use `linux-amd64`, `debian-amd64.deb`, `ubuntu-amd64.deb`, or `fedora-x86_64.rpm`.
- Raspberry Pi 64-bit OS: use `linux-arm64`, `debian-arm64.deb`, or `ubuntu-arm64.deb`.
- Raspberry Pi 32-bit OS: use `linux-armv7`, `debian-armhf.deb`, or `ubuntu-armhf.deb`.

Install examples:

Debian:

```bash
sudo apt-get install ./resetusb-vMAJOR.MINOR.PATCH-debian-amd64.deb
```

Ubuntu:

```bash
sudo apt-get install ./resetusb-vMAJOR.MINOR.PATCH-ubuntu-amd64.deb
```

Fedora:

```bash
sudo dnf install ./resetusb-vMAJOR.MINOR.PATCH-fedora-x86_64.rpm
```

Generic tarball:

```bash
tar -xzf resetusb-vMAJOR.MINOR.PATCH-linux-amd64.tar.gz
sudo install -m 0755 vMAJOR.MINOR.PATCH-linux-amd64/resetusb /usr/sbin/resetusb
sudo install -m 0644 vMAJOR.MINOR.PATCH-linux-amd64/resetusb.8 /usr/share/man/man8/resetusb.8
```

Tarball note: install the system `libusb-1.0` runtime first, for example `libusb-1.0-0` on Debian/Ubuntu or `libusb1` on Fedora.

Verify an artifact:

```bash
sha256sum -c resetusb-vMAJOR.MINOR.PATCH-ubuntu-amd64.deb.sha256
```

Verify Sigstore provenance (keyless):

```bash
cosign verify-blob \
  --bundle resetusb-vMAJOR.MINOR.PATCH-ubuntu-amd64.deb.sigstore.json \
  --certificate-identity-regexp '^https://github\.com/omkhar/resetusb/\.github/workflows/release-builder\.yml@refs/heads/main$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  resetusb-vMAJOR.MINOR.PATCH-ubuntu-amd64.deb
```

Verify the builder-signed release manifest:

```bash
cosign verify-blob \
  --bundle resetusb-vMAJOR.MINOR.PATCH-release-manifest.json.sigstore.json \
  --certificate-identity-regexp '^https://github\.com/omkhar/resetusb/\.github/workflows/release-builder\.yml@refs/heads/main$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  resetusb-vMAJOR.MINOR.PATCH-release-manifest.json
```

Verify the GitHub provenance attestation for an artifact:

```bash
builder_digest="$(jq -r '.builder_digest' resetusb-vMAJOR.MINOR.PATCH-release-manifest.json)"
gh attestation verify \
  resetusb-vMAJOR.MINOR.PATCH-ubuntu-amd64.deb \
  --repo omkhar/resetusb \
  --signer-workflow omkhar/resetusb/.github/workflows/release-builder.yml \
  --signer-digest "$builder_digest"
```

Verify the GitHub SBOM attestation for an artifact:

```bash
builder_digest="$(jq -r '.builder_digest' resetusb-vMAJOR.MINOR.PATCH-release-manifest.json)"
gh attestation verify \
  resetusb-vMAJOR.MINOR.PATCH-ubuntu-amd64.deb \
  --repo omkhar/resetusb \
  --signer-workflow omkhar/resetusb/.github/workflows/release-builder.yml \
  --signer-digest "$builder_digest" \
  --predicate-type https://spdx.dev/Document/v2.3
```

Public release provenance is rooted in the trusted builder workflow on `main`. The builder also signs a release manifest that records the artifact digests, the builder revision, the snapshot-pinned builder inputs, and the commit digest resolved from the signed release tag. Primary artifact timestamps are normalized from the source commit time so rebuilding the same tag produces byte-stable tarballs and distro packages. Fresh SBOMs, signatures, and attestations are generated at release time.

## Community

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

- Keep `README.md` and `resetusb(8)` in sync.
- If you change CLI behavior, output semantics, installation paths, or release packaging, update both in the same change.

## License

Apache-2.0 (see [LICENSE](LICENSE)).
