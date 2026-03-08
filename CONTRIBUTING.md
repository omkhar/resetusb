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
sudo apt-get install -y build-essential clang-format clang-tools cppcheck libusb-1.0-0-dev shellcheck
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

- Create and push a signed annotated tag matching `v*` (for example `git tag -s v1.2.3 -m "resetusb release v1.2.3"`).
- GitHub Actions `release.yml` builds, tests, signs artifacts with Sigstore, verifies signatures, and publishes release artifacts.
- Do not publish binaries manually outside the release workflow.
