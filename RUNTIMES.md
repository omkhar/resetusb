# resetusb runtimes

This document uses ASD-STE100 Simplified Technical English.

## Program runtime

- The program runs only on Linux.
- The source uses C11.
- The program links to the system `libusb-1.0` shared library.
- Generic archives support Linux `amd64`, `arm64`, and `armv7`.
- Debian and Ubuntu packages support `amd64`, `arm64`, and `armhf`.
- The Fedora RPM supports `x86_64`.

## Build runtime

- The trusted builder uses Debian 13 (`trixie`).
- The trusted builder uses the Debian snapshot at `20260721T000000Z`.
- `docker/release-builder.lock` contains the exact base-image digest, snapshot time, and snapshot `InRelease` digest.
- CI compiles with GCC and Clang from the locked Debian snapshot.
- Repository security automation uses Go 1.26.5. The `resetusb` executable does not need Go.
- Workflow lint uses actionlint `v1.7.12`.
- Secret scans use Gitleaks 8.30.1.
- Release workflows use Cosign 3.1.2 and Syft 1.49.0.
- GitHub-hosted jobs use Ubuntu 24.04.

## Package-test runtime

- Stable package tests use Debian 13, Ubuntu 24.04, and Fedora 44.
- Unstable package tests use Debian `sid`, Ubuntu `devel`, and Fedora `rawhide`.
- `docker/package-test-images.lock` contains one immutable image digest for each tested platform.
- The Ubuntu `devel` ARMv7 test extracts the GNU `rm` command from the current `gnu-coreutils` package.
- The uutils `rm` command in the locked image cannot remove a nonempty directory when the CI emulator runs it.
- The test does not add GNU Coreutils to a `resetusb` package.

The lock files are the source of truth for exact runtime digests. A runtime-update pull request must update related workflows and checks.
