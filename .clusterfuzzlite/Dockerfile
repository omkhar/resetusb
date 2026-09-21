FROM gcr.io/oss-fuzz-base/base-builder:v1@sha256:47bcf5c42c4863af02843d16315014011571e31ece4ac9110a77a2e43949c5d2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libusb-1.0-0-dev \
    make && \
    rm -rf /var/lib/apt/lists/*

COPY . $SRC/resetusb
WORKDIR $SRC/resetusb
COPY ./.clusterfuzzlite/build.sh $SRC/build.sh
