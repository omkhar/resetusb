# resetusb

`resetusb` is a Linux utility that enumerates USB devices and issues resets through `libusb`.
It is designed for operational recovery workflows where USB devices are stuck or misbehaving.

## Safety and Scope

- `resetusb` requires root privileges.
- It resets every enumerated USB device, including hubs.
- This can interrupt keyboards, storage, serial devices, and USB-backed networking.
- Use only during controlled maintenance windows or recovery procedures.

## Requirements

- Linux
- `libusb-1.0` development headers (`libusb-1.0-0-dev` on Debian/Ubuntu)
- C toolchain (`gcc`/`clang`) and `make`

## Build

```bash
make
```

## Run

```bash
sudo ./resetusb
```

Example output:

```text
reset bus 1 device 2 (1234:5678) Example Device
Summary: reset 1 device(s), 0 failure(s)
```

## Test and Verification

```bash
make test
```

The CI pipeline enforces:

- `ci-security`: `cppcheck`, `shellcheck`, and `scan-build`
- `ci-build`: Linux build with `ccache`
- `ci-test`: unit tests with `ccache`

## Public Releases

- Public release artifacts are published from Git tags (`v*`) via `.github/workflows/release.yml`.
- Each release includes:
  - `resetusb-<tag>-linux-amd64.tar.gz`
  - `resetusb-<tag>-linux-amd64.tar.gz.sha256`
  - `resetusb-<tag>-linux-amd64.tar.gz.sig`
  - `resetusb-<tag>-linux-amd64.tar.gz.pem`
  - `resetusb-<tag>-linux-amd64.tar.gz.bundle.json`

Verify an artifact:

```bash
sha256sum -c resetusb-<tag>-linux-amd64.tar.gz.sha256
```

Verify Sigstore provenance (keyless):

```bash
cosign verify-blob \
  --bundle resetusb-<tag>-linux-amd64.tar.gz.bundle.json \
  --certificate resetusb-<tag>-linux-amd64.tar.gz.pem \
  --signature resetusb-<tag>-linux-amd64.tar.gz.sig \
  --certificate-identity-regexp '^https://github\.com/omkhar/resetusb/\.github/workflows/release\.yml@refs/tags/.*$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  resetusb-<tag>-linux-amd64.tar.gz
```

## Collaboration

- Report bugs: open a GitHub Issue with logs and reproduction steps.
- Propose changes: open a PR and follow `.github/pull_request_template.md`.
- Security reports: see [SECURITY.md](SECURITY.md).
- Latest security review: [docs/security-review-2026-03-01.md](docs/security-review-2026-03-01.md).
- Development guidance: see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache-2.0 (see [LICENSE](LICENSE)).
