# Contributing to resetusb

This document uses ASD-STE100 Simplified Technical English.

## Guidelines

- Keep changes small, reviewable, and security-conscious.
- Preserve the safety messaging: this tool can disrupt active USB-connected systems.
- Keep Linux-only assumptions explicit in code, CI, and docs.
- Follow Linux kernel C style for source changes.
- Do not add automatic staging or production deployment jobs in this repository.

## Community Expectations

When you participate, you agree to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Setup

Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y build-essential clang clang-format clang-tools cppcheck \
  libusb-1.0-0-dev python3 python3-yaml shellcheck
```

Use Python 3.10 or newer. Local checks support Bash 3.2 or newer.
Release and package scripts require Bash 4.0 or newer.

Install `actionlint` from the upstream release binaries.
Use `v1.7.12` or newer.
`v1.7.8` incorrectly rejects GitHub's `artifact-metadata` permission in this repository.
`make lint` requires `actionlint`.

Install PyYAML 6.0 or newer for the Python 3 interpreter that runs `make lint`.

## Agent Control Plane

- The repository render script generates `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md`.
- Do not edit these files manually.
- Canonical shared skills live in `.agents/skills/`.
- The repository render script writes the Claude skill mirror to `.claude/skills/`.
- After you edit a canonical agent file, run `python3 scripts/render-agent-control-plane.py`.
- Then run `make lint`.
- Before you open a PR, remove internal notes, local paths, usernames, scratch artifacts, and repository waste from public files.

## Before Opening a PR

Run these checks before you open a pull request:

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

For a longer local run:

```bash
make fuzz FUZZ_TIME=10
```

Format source files with:

```bash
make format
```

## Pull Requests

- Include a short problem statement and rationale.
- Include the exact commands that you ran.
- Summarize the results.
- Add unit tests when behavior changes.
- Keep each PR to no more than 20 changed files and 750 total changed lines.
- Split a larger change before you push it.
- Keep GitHub Actions references pinned to immutable commit SHAs.
- If you change a canonical agent file, include all related generated files in the same PR.
- Document behavior changes in `README.md` and `SECURITY.md` when they affect users or operators.
- Update `resetusb.8` when user-visible behavior, output, installation paths, or packaging contents change.

## Release Process

- Use semantic versioning for public releases.
- Increase `MAJOR` for a breaking behavior or release-contract change.
- Increase `MINOR` for a backward-compatible feature.
- Increase `PATCH` for a backward-compatible fix.
- Create a signed annotated tag at the release commit. Use the form `vMAJOR.MINOR.PATCH`.
- Push the signed tag.
- Before you create the tag, summarize release-ready changes in `CHANGELOG.md`.
- Before you create the tag, run `make release-preflight`.
- The preflight builds the release artifacts twice.
- It compares the two sets of digests.
- A digest mismatch stops publication.
- After you push the tag, manually start `release.yml` with that tag as the workflow reference.
- The workflow verifies that its revision matches the signed tag digest.
- It runs `release-preflight`.
- It builds the release artifacts.
- It signs the artifacts and a release manifest.
- It verifies the attestations against the trusted builder revision.
- It publishes the release.
- Do not change a published release tag.
- If release contents change, merge a fix.
- Then create a new patch version.
- If a release run fails before publication, rerun the workflow for the same tag.
- The publish step reuses an existing draft.
- It rewrites the draft notes and replaces the draft assets.
- The trusted builder inputs live in `docker/release-builder.lock`.
- When you refresh the release toolchain, update that file with the builder or packaging change.
- Explain the reason in the PR description.
- The Debian snapshot setup starts over plain HTTP.
- The pinned base image does not contain CA roots before the first package installation.
- The pinned base image digest, Debian archive signing, and pinned snapshot `InRelease` digest protect integrity.
- Release packaging gets `SOURCE_DATE_EPOCH` from the source commit timestamp.
- The snapshot-pinned builder makes primary tarballs and distribution packages reproducible for the same tag.
- Release operations generate new SBOMs and signatures.
- Ad hoc release-artifact builds require Git metadata or an explicit `SOURCE_DATE_EPOCH`.
- Trusted workflows set the builder time from the source commit timestamp.
- `release-manifest.schema.json` defines the release manifest contract and its version.
- If you add or rename manifest fields, increase the manifest format version.
- Update the schema, validator, and documents in the same change.
- Release package checks cover these stable and unstable distribution channels:
  - Debian stable and sid on `amd64`, `arm64`, and `armv7`
  - Ubuntu 24.04 and devel on `amd64`, `arm64`, and `armv7`
  - Fedora stable and rawhide on `amd64`
- Do not publish binaries outside the release workflow.
- Do not bypass the builder workflow.
- When the packaging changes, verify that release artifacts include the installed documents, especially `resetusb(8)`.
