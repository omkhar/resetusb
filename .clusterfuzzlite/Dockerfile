FROM gcr.io/oss-fuzz-base/base-builder:v1@sha256:cc6982a6ce8b02c80a2acabbcfe766e5e7200988ff0424b0d4963232c3b41901

RUN apt-get update && apt-get install -y --no-install-recommends \
    libusb-1.0-0-dev \
    make && \
    rm -rf /var/lib/apt/lists/*

COPY . $SRC/resetusb
WORKDIR $SRC/resetusb
COPY ./.clusterfuzzlite/build.sh $SRC/build.sh
