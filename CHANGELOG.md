# Changelog

## v2.0.13

- Add a repo-owned portable agent control plane with canonical shared instructions, generated `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`, and a generated Claude skill mirror so Codex, Claude, and Gemini consume the same project invariants.
- Enforce public-repo hygiene and control-plane drift in `make lint`, including checks for leaked local paths, internal-only references, local-only config files, scratch detritus, and unsynchronized generated agent surfaces.
- Install pinned upstream `actionlint` binaries in CI and local static-analysis bootstrap paths, and require `actionlint` `v1.7.10` or newer.
- Enforce reviewable pull requests in CI by rejecting PRs over 20 changed files or 750 total changed lines, matching the repo policy for small, human-reviewable changes.
- Tighten the release security contract check so CI must keep the snapshot digest validation in each bootstrap path and must keep the lint path that enforces the release guard itself.

## v2.0.12

- Clamp oversized USB product-string lengths before appending a terminating NUL, closing a root-process out-of-bounds write in `resetusb_run()`.
- Pin and verify the Debian snapshot `InRelease` digest during CI and builder bootstrap so the trusted toolchain cannot silently drift under snapshot replay or substitution.
- Anchor release publication and manifest provenance to the signed release tag instead of the mutable `main` branch workflow revision.
- Add a checked-in release security contract check to `make lint` so CI keeps enforcing the snapshot lock and tag-anchored release invariants.
- Document that local workflow linting needs `actionlint` `v1.7.10` or newer because older releases such as `v1.7.8` falsely reject GitHub's `artifact-metadata` permission.
