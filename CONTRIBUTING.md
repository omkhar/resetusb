# Contributing to resetusb

## Guidelines

- Keep changes small, reviewable, and security-conscious.
- Preserve the safety messaging: this tool can disrupt active USB-connected systems.
- Keep Linux-only assumptions explicit in code, CI, and docs.
- Follow Linux kernel C style for source changes.
- Do not add automatic staging/production deployment jobs in this repository.

## Community Expectations

By participating, you agree to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Setup

Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y build-essential clang clang-format clang-tools cppcheck libusb-1.0-0-dev shellcheck
```

Install `actionlint` separately from the upstream release binaries and keep it at
`v1.7.10` or newer. `v1.7.8` predates GitHub's `artifact-metadata` permission
support and reports a false positive on the release workflows in this
repository. `make lint` now requires `actionlint`.

## Agent Control Plane

- `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` are generated files. Do not hand-edit them.
- Canonical shared skills live in `.agents/skills/`.
- `.claude/skills/` is a generated mirror of the canonical shared skills.
- After editing the canonical agent-control-plane source or shared skills, rerun the repository render script and then `make lint`.
- Keep agent-facing content public-repo appropriate: remove internal-only notes, local paths, usernames, scratch artifacts, and other repository detritus before opening a PR.

## Before Opening a PR

Run these checks before opening a pull request:

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
- Include exact commands run and summarized results.
- Add/adjust unit tests when behavior changes.
- Keep GitHub Actions references pinned to immutable commit SHAs.
- If you change the canonical agent-control-plane source, include the regenerated `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, and `.claude/skills/` updates in the same PR.
- Document behavior changes in `README.md` and `SECURITY.md` when they affect users or operators.
- Update `resetusb.8` when user-visible behavior, output, installation paths, or packaging contents change.

## Release Process

- Public releases use semantic versioning.
- Bump `MAJOR` for breaking behavior or release-contract changes, `MINOR` for backward-compatible features, and `PATCH` for backward-compatible fixes.
- Create and push a signed annotated tag in the form `vMAJOR.MINOR.PATCH` at the commit you intend to release (for example `git tag -s vMAJOR.MINOR.PATCH -m "resetusb release vMAJOR.MINOR.PATCH"`).
- Summarize release-ready changes in `CHANGELOG.md` before cutting the tag.
- Run `make release-preflight` before cutting the tag. It rebuilds the release artifacts twice and compares digests before publish is allowed to proceed.
- After pushing a signed semver tag, manually dispatch `release.yml` using that same tag as the workflow ref. The workflow verifies that the checked-out workflow revision matches the signed tag digest, runs `release-preflight`, builds and signs the release artifacts, signs a release manifest for the artifact set, verifies the resulting attestations against the trusted builder workflow revision, and publishes the release.
- Published release tags are immutable. If anything in the release contents changes, merge a fix and cut a new patch version instead of rebuilding or replacing an existing tag.
- If a release run fails before publication, rerun the workflow for the same tag. The publish step reuses any existing draft, rewrites the draft notes, and replaces the draft assets before publication.
- The trusted builder inputs live in `docker/release-builder.lock`. If you need to refresh the release toolchain, update that file in the same PR as the builder or packaging change and explain the reason in the PR description.
- The Debian snapshot bootstrap path still starts over plain HTTP because the pinned base image does not carry CA roots before the first package install. Integrity comes from the pinned base image digest, Debian archive signing, and the pinned snapshot `InRelease` digest recorded in `docker/release-builder.lock`.
- Release packaging derives `SOURCE_DATE_EPOCH` from the source commit timestamp and uses the snapshot-pinned builder image so rebuilding the same tag reproduces the primary tarballs and distro packages. Release-time SBOMs and signatures are expected to be regenerated.
- Ad hoc release-artifact builds now require either git metadata for the source tree or an explicit `SOURCE_DATE_EPOCH`; the trusted workflows export the commit timestamp into the builder automatically.
- The release manifest contract is versioned in `release-manifest.schema.json`. If you add or rename manifest fields, bump the manifest format version and update the schema, validator, and docs in the same change.
- Release packaging is validated against stable and unstable distro channels before publication:
  - Debian stable and sid on `amd64`, `arm64`, and `armv7`
  - Ubuntu 24.04 and devel on `amd64`, `arm64`, and `armv7`
  - Fedora stable and rawhide on `amd64`
- Do not publish binaries manually outside the release workflow or bypass the builder workflow.
- When packaging changes, verify that release artifacts still include the installed documentation set, especially `resetusb(8)`.
