# resetusb

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/omkhar/resetusb/badge)](https://scorecard.dev/viewer/?uri=github.com/omkhar/resetusb)

`resetusb` resets USB devices on Linux through `libusb`.
Use it during recovery or maintenance when a device does not respond.
It asks `libusb` to do a USB port reset for each open device.
This reset can reinitialize the device.
If `libusb` requires re-enumeration, `resetusb` records a failure and does not rediscover the device.

This user documentation uses ASD-STE100 Simplified Technical English.

`resetusb` has no flags or filtering. When you run it, it processes each entry
in the `libusb` device list. It attempts a reset only after it reads a descriptor and opens a non-null handle.

Read [LIMITATIONS.md](LIMITATIONS.md) before you run the program.
Read [RUNTIMES.md](RUNTIMES.md) for runtime and build requirements.
Read [FUNCTIONS.md](FUNCTIONS.md) for the source-derived function inventory.

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
- It can attempt a reset for each device that it opens. The device list can include hubs.
- This can interrupt keyboards, storage, serial devices, and USB-backed networking.
- Use it only during controlled maintenance or recovery work.

## Runtime Requirements

- Linux
- Root privileges
- Generic tarballs require a system `libusb-1.0` runtime (`libusb-1.0-0` on Debian/Ubuntu or `libusb1` on Fedora).

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

The program ignores all command-line arguments. Thus, `--help` does not show help.
It starts the normal reset operation. Do not supply arguments.

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

## Agent Control Plane

`AGENTS.md` contains the canonical shared agent instructions. `CLAUDE.md`
and `GEMINI.md` are short pointers to it.

Canonical shared skills live in `.agents/skills/`. `.claude/skills` is a
symbolic link to `.agents/skills`.

If you edit an agent file, run `make lint`.

Keep agent-facing content public-repo safe: do not add internal-only notes,
local paths, usernames, scratch artifacts, or other repository detritus.

CI covers linting, unit tests, sanitizers, package validation, fuzzing, secret
scanning, and Scorecard checks.

Notes:

- `resetusb` exits `0` only when all attempted resets succeed.
- It exits `1` if a device operation fails. The program continues with the next device.
- It exits `1` when the user is not root or when the real and effective UIDs differ.
- It exits `1` when `libusb` initialization or enumeration fails.
- The program changes non-printable product-name bytes to question marks before it prints them.

## Releases

- Public releases use semantic versioning and signed annotated tags in the form `vMAJOR.MINOR.PATCH`.
- Release tags are immutable. If release contents change, maintainers create a new patch version.
- Publication only happens after `release-preflight` succeeds. This check includes a repeat-build digest comparison for the release artifacts.
- `docker/release-builder.lock` pins the trusted builder inputs.
- The lock fixes the Debian base image digest and snapshot timestamp.
- It also fixes the expected snapshot `InRelease` digest for build dependencies.
- CI build and test jobs use the same snapshot-pinned Debian inputs as the release path.
- Thus, the compiler and analysis tools do not drift from the release builder.
- Release packaging requires a Git checkout or an explicit `SOURCE_DATE_EPOCH`.
- Trusted workflows set the builder time from the source commit timestamp.
- Generic archives and distribution packages include these documents:
  `README.md`, `FUNCTIONS.md`, `LIMITATIONS.md`, and `RUNTIMES.md`.
- They also include the binary, license, and `resetusb(8)` manual page.
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
- Each release includes a builder-signed release manifest named `resetusb-vMAJOR.MINOR.PATCH-release-manifest.json`.
- The manifest contains the release tag, commit digest, trusted builder digest, reproducible inputs, and primary artifact SHA256 hashes.
- `release-manifest.schema.json` defines the manifest contract and its version.
- GitHub Actions also emits per-asset provenance and SBOM attestations before publication, and publish re-verifies them against the trusted builder workflow revision.
- `CONTRIBUTING.md` contains the maintainer release steps.
- `CHANGELOG.md` contains the release notes for the next patch version.

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
  --certificate-identity-regexp '^https://github\.com/omkhar/resetusb/\.github/workflows/release-builder\.yml@refs/tags/vMAJOR\.MINOR\.PATCH$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  resetusb-vMAJOR.MINOR.PATCH-ubuntu-amd64.deb
```

Verify the builder-signed release manifest:

```bash
cosign verify-blob \
  --bundle resetusb-vMAJOR.MINOR.PATCH-release-manifest.json.sigstore.json \
  --certificate-identity-regexp '^https://github\.com/omkhar/resetusb/\.github/workflows/release-builder\.yml@refs/tags/vMAJOR\.MINOR\.PATCH$' \
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

The signed release tag establishes public release provenance.
The trusted builder signs a release manifest.
The manifest records artifact digests, the builder revision, snapshot-pinned inputs, and the commit digest from the signed tag.
The source commit time determines primary artifact timestamps.
If you rebuild the same tag, the process produces byte-stable tarballs and distribution packages.
The release process generates new SBOMs, signatures, and attestations.

## Community

- Report bugs: open a GitHub Issue with logs and reproduction steps.
- Propose changes: open a PR. Follow `.github/pull_request_template.md`.
- Security reports: see [SECURITY.md](SECURITY.md).
- Development guidance: see [CONTRIBUTING.md](CONTRIBUTING.md).
- Community expectations: see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Coding Style

- C source follows Linux kernel style conventions.
- `.clang-format` defines the source format.
- Run `make format` before you submit style-related changes.

## Documentation

- Keep `README.md`, `LIMITATIONS.md`, and `resetusb(8)` consistent.
- Update [RUNTIMES.md](RUNTIMES.md) when a runtime or immutable runtime input changes.
- Update [FUNCTIONS.md](FUNCTIONS.md) when a non-test source function changes.
- If you change command behavior, output, installation paths, or packaging, update the related documents.
- `make lint` checks every tracked Markdown, reStructuredText, text, and section 8 manual file.
- The style checker permits 20 words in an instruction and 25 words in a descriptive sentence.
- It rejects selected unapproved words, unapproved `-ing` forms, contractions, passive patterns, combined instructions, and disallowed punctuation.
- It skips fenced code, inline technical syntax, and link targets.
- It checks headings and counts each heading as one word.

## License

Apache-2.0 (see [LICENSE](LICENSE)).
