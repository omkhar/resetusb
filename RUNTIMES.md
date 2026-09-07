# resetusb runtimes

This document uses ASD-STE100 Simplified Technical English.

## Program runtime

- The program runs only on Linux.
- The program must run as root.
- The program refuses to run if the real user ID and the effective user ID are different.
- The program has no flags and no device filter.
- The program tries to reset each enumerated USB device after it reads the device descriptor and opens the device.
- A reset can interrupt a keyboard, a storage device, a serial device, a hub, or USB network equipment.
- The program needs the system `libusb-1.0` shared library.
- Generic archives support Linux `amd64`, `arm64`, and `armv7`.
- Debian and Ubuntu packages support `amd64`, `arm64`, and `armhf`.
- The Fedora RPM supports `x86_64`.

## Development runtime

- The source uses C11.
- A source build needs GCC or Clang, Make, and the `libusb-1.0` development files.
- Local checks support Bash 3.2 or newer.
- Release and package scripts require Bash 4.0 or newer.
- Repository checks require Python 3.10 or newer.
- Workflow lint uses actionlint 1.7.12 or newer.
- Build, unit-test, sanitizer, and fuzz targets run only on Linux.
- On a non-Linux host, `make test` and `make fuzz` skip their tests.
- On a non-Linux host, build, install, and sanitizer targets stop with an error.

## Trusted build and automation runtime

- The trusted builder uses Debian 13 (`trixie`).
- The trusted builder uses the Debian snapshot at `20260721T000000Z`.
- `docker/release-builder.lock` contains the base-image digest, snapshot time, and snapshot `InRelease` digest.
- CI compiles with GCC and Clang from the locked Debian snapshot.
- Repository security automation uses Go 1.27.1.
- The `resetusb` executable does not need Go.
- Secret scans use Gitleaks 8.30.1.
- Release workflows use Cosign 3.1.2 and Syft 1.49.0.
- GitHub-hosted jobs use Ubuntu 24.04.
- ClusterFuzzLite uses the locked OSS-Fuzz base-builder image.

## Container and package-test runtime

- `make release-preflight` needs the Docker command and a Docker daemon.
- The preflight accepts only an `amd64` or `arm64` Docker server.
- An `arm64` Docker server must be able to execute `amd64` containers.
- The package tests use QEMU and `binfmt` for non-native containers.
- The `binfmt` setup needs a privileged Docker container.
- The package tests need network access to distribution package repositories.
- Debian and Ubuntu package tests use `amd64`, `arm64`, and `armv7` containers.
- Fedora package tests use only an `amd64` container.
- Stable package tests use Debian 13, Ubuntu 24.04, and Fedora 44.
- Unstable package tests use Debian `sid`, Ubuntu `devel`, and Fedora `rawhide`.
- `docker/package-test-images.lock` contains one image digest for each tested platform.
- `scripts/test-package-integration.sh` contains the immutable `binfmt` image digest.
- The Ubuntu `devel` ARMv7 image uses a uutils `rm` command.
- That `rm` command cannot remove a nonempty directory under the CI emulator.
- The test extracts GNU `rm` from the distribution `gnu-coreutils` package before package installation.
- The test does not add GNU Coreutils to a `resetusb` package.

The lock files and pinned image references are the source of truth for exact digests. A runtime-update pull request must update the related workflows, documentation, and contract checks.
