FROM gcr.io/oss-fuzz-base/base-builder:v1@sha256:5d16653db7d96570d09b91e022867a0ff6fa32826fd5f3f0625e5afa61157414

RUN apt-get update && apt-get install -y --no-install-recommends \
    libusb-1.0-0-dev \
    make && \
    rm -rf /var/lib/apt/lists/*

COPY . $SRC/resetusb
WORKDIR $SRC/resetusb
COPY ./.clusterfuzzlite/build.sh $SRC/build.sh
