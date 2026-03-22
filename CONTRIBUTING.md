# Contributing to resetusb

## Ground Rules

- Keep changes minimal, auditable, and security-conscious.
- Preserve safety messaging: this tool can disrupt active USB-connected systems.
- Keep Linux-only assumptions explicit in code, CI, and docs.
- Follow Linux kernel C style for source changes.
- Do not add automatic staging/production deployment jobs in this repository.

## Community Expectations

By participating, you agree to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Local Setup

Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y build-essential clang clang-format clang-tools cppcheck libusb-1.0-0-dev shellcheck
```

## Required Local Checks

Run before opening a PR:

```bash
make clean
make
make test
make lint
make check-format
scan-build --status-bugs --keep-empty --exclude /usr/include make clean all test
make sanitize
make release-preflight
```

Optional deeper local check:

```bash
make fuzz FUZZ_TIME=10
```

Auto-format source files with:

```bash
make format
```

## Pull Request Expectations

- Include a short problem statement and rationale.
- Include exact commands run and summarized results.
- Add/adjust unit tests when behavior changes.
- Keep GitHub Actions references pinned to immutable commit SHAs.
- Keep behavior changes explicit in docs (`README.md`, `SECURITY.md`) when applicable.

## Release Process

- Public releases use semantic versioning.
- Bump `MAJOR` for breaking behavior or release-contract changes, `MINOR` for backward-compatible features, and `PATCH` for backward-compatible fixes.
- Create and push a signed annotated tag in the form `vMAJOR.MINOR.PATCH` (for example `git tag -s v2.0.0 -m "resetusb release v2.0.0"`).
- Run `make release-preflight` before cutting the tag.
- GitHub Actions `release.yml` runs `release-preflight`, then builds generic tarballs plus Debian/Ubuntu/Fedora packages, generates SPDX JSON SBOMs, signs each release artifact with Sigstore, emits per-asset GitHub provenance and SBOM attestations, verifies those attestations, and publishes the release.
- Release packaging is validated against stable and unstable distro channels before publication:
  - Debian stable and sid on `amd64`, `arm64`, and `armv7`
  - Ubuntu 24.04 and devel on `amd64`, `arm64`, and `armv7`
  - Fedora stable and rawhide on `amd64`
- Do not publish binaries manually outside the release workflow.
