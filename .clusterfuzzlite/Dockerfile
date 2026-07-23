FROM gcr.io/oss-fuzz-base/base-builder:v1@sha256:8aa36c8f128e4afa83ae566f413e944094a4923969b26b5cd85be6803d5eacf3

RUN apt-get update && apt-get install -y --no-install-recommends \
    libusb-1.0-0-dev \
    make && \
    rm -rf /var/lib/apt/lists/*

COPY . $SRC/resetusb
WORKDIR $SRC/resetusb
COPY ./.clusterfuzzlite/build.sh $SRC/build.sh
