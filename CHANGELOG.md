# Changelog

## v2.0.12

- Clamp oversized USB product-string lengths before appending a terminating NUL, closing a root-process out-of-bounds write in `resetusb_run()`.
- Pin and verify the Debian snapshot `InRelease` digest during CI and builder bootstrap so the trusted toolchain cannot silently drift under snapshot replay or substitution.
- Anchor release publication and manifest provenance to the signed release tag instead of the mutable `main` branch workflow revision.
- Add a checked-in release security contract check to `make lint` so CI keeps enforcing the snapshot lock and tag-anchored release invariants.
- Document that local workflow linting needs `actionlint` `v1.7.10` or newer because older releases such as `v1.7.8` falsely reject GitHub's `artifact-metadata` permission.
