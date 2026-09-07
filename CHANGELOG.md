# Changelog

This document uses ASD-STE100 Simplified Technical English.

## Unreleased

- The pending release refreshes pinned GitHub Actions, analysis tools, Debian builder inputs, and package validation images.
- It adds current runtime, function, limitation, behavior, failure-output, and package-content documentation.
- It puts the linked user documents in generic archives and distribution packages.
- It adds an automated Simplified Technical English check for tracked documentation.
- It removes the duplicate action revision table and duplicate image digests from the release security contract.
- It validates immutable action references in each workflow through one policy check.
- It groups CodeQL action updates into one dependency update.
- It makes `AGENTS.md` the canonical agent instruction file and removes the agent document render script.
- It changes `CLAUDE.md` and `GEMINI.md` to short pointers and changes `.claude/skills` to a symbolic link.

## v2.0.15

- This release refreshes the pinned `docker/setup-qemu-action` dependency for CI, nightly preflight, and release publication.

## v2.0.14

- This release refreshes the Debian `trixie` image for CI containers and the trusted builder lock.
- It updates the pinned GitHub Actions and workflow tools for repository validation.
- These tools include checkout, CodeQL, upload-sarif, dependency-review, setup-go, setup-qemu, and zizmor.

## v2.0.13

- This release adds a portable repository agent control plane with canonical instructions and generated agent files.
- It adds a Claude skill mirror. Codex, Claude, and Gemini now use the same project rules.
- It adds public-file and control-plane drift checks to `make lint`.
- These checks find local paths, internal references, local configuration, scratch waste, and generated-file drift.
- CI installs pinned upstream `actionlint` binaries. Local static-analysis setup also installs these binaries.
- Repository checks require `actionlint` `v1.7.10` or newer.
- CI rejects PRs with more than 20 files or 750 changed lines.
- The release security contract keeps snapshot digest validation in each setup path and keeps the release guard in lint.
- Host release scripts no longer use Bash 4 `mapfile` or associative arrays.
- Local release preflight now works with older macOS Bash versions.

## v2.0.12

- This release limits oversized USB product strings before the program adds a terminating NUL.
- This change closes an out-of-bounds write in the root process.
- CI and builder setup pin and verify the Debian snapshot `InRelease` digest.
- The signed release tag establishes release publication and manifest provenance.
- A release security contract check in `make lint` keeps the snapshot lock and tag-based release rules.
- Local workflow checks require `actionlint` `v1.7.10` or newer.
- Older releases incorrectly reject the GitHub `artifact-metadata` permission.
