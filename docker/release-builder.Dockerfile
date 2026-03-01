FROM debian:trixie@sha256:3615a749858a1cba49b408fb49c37093db813321355a9ab7c1f9f4836341e9db

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
