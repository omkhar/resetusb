# Contributing to resetusb

## Ground Rules

- Keep changes minimal and auditable.
- Prefer measured results over assumptions.
- Preserve safety messaging: this tool can disrupt active USB-connected systems.
- Do not add automatic staging/production deployments in this repository.

## Local Setup

Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y build-essential libusb-1.0-0-dev
```

Build and test:

```bash
make clean
make
make test
```

## Security and Quality Checks

Before opening a PR, run:

```bash
cppcheck --enable=warning,style,performance,portability --error-exitcode=1 --suppress=missingIncludeSystem resetusb.c
shellcheck scripts/*.sh
```

Linux static-analysis gate:

```bash
scan-build --status-bugs --keep-empty --exclude /usr/include make clean all test
```

## Pull Request Expectations

- Include a short problem statement and rationale.
- Include exact test/analyzer commands run and their results.
- Add/adjust unit tests when behavior changes.
- Keep GitHub Actions pinned to commit hashes.

## Release Process

- Create and push an annotated tag matching `v*` (for example `v1.2.3`).
- GitHub Actions `release.yml` builds, tests, signs artifacts with Sigstore, verifies signatures, and publishes release artifacts.
- Do not publish binaries manually outside the release workflow.
