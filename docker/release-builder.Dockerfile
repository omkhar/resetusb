FROM debian:trixie@sha256:55a15a112b42be10bfc8092fcc40b6748dc236f7ef46a358d9392b339e9d60e8

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    dpkg --add-architecture arm64; \
    dpkg --add-architecture armhf; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      build-essential \
      gcc-aarch64-linux-gnu \
      gcc-arm-linux-gnueabihf \
      libc6-dev-arm64-cross \
      libc6-dev-armhf-cross \
      libusb-1.0-0-dev \
      libusb-1.0-0-dev:arm64 \
      libusb-1.0-0-dev:armhf \
      pkg-config \
      qemu-user-static; \
    rm -rf /var/lib/apt/lists/*
