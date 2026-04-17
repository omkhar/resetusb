FROM debian:trixie@sha256:3352c2e13876c8a5c5873ef20870e1939e73cb9a3c1aeba5e3e72172a85ce9ed

ARG DEBIAN_SNAPSHOT_URL
ARG DEBIAN_SNAPSHOT_TIMESTAMP
ARG DEBIAN_SNAPSHOT_INRELEASE_SHA256
ARG DEBIAN_SUITE

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    echo 'Acquire::Retries "6";' > /etc/apt/apt.conf.d/80-retries; \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/90snapshot; \
    rm -f /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; \
    printf 'deb [check-valid-until=no] %s/%s/ %s main\n' \
      "${DEBIAN_SNAPSHOT_URL}" "${DEBIAN_SNAPSHOT_TIMESTAMP}" "${DEBIAN_SUITE}" \
      > /etc/apt/sources.list.d/snapshot.list; \
    dpkg --add-architecture arm64; \
    dpkg --add-architecture armhf; \
    apt-get update; \
    snapshot_inrelease="/var/lib/apt/lists/snapshot.debian.org_archive_debian_${DEBIAN_SNAPSHOT_TIMESTAMP}_dists_${DEBIAN_SUITE}_InRelease"; \
    test -f "${snapshot_inrelease}"; \
    echo "${DEBIAN_SNAPSHOT_INRELEASE_SHA256}  ${snapshot_inrelease}" | sha256sum --check --strict; \
    apt-get install -y --no-install-recommends \
      dpkg-dev \
      file \
      gcc \
      gcc-aarch64-linux-gnu \
      gcc-arm-linux-gnueabihf \
      libc6-dev \
      libc6-dev-arm64-cross \
      libc6-dev-armhf-cross \
      libusb-1.0-0-dev \
      libusb-1.0-0-dev:arm64 \
      libusb-1.0-0-dev:armhf \
      make \
      pkg-config \
      qemu-user \
      rpm; \
    rm -rf /var/lib/apt/lists/*
