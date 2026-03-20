FROM gcr.io/oss-fuzz-base/base-builder:v1

RUN apt-get update && apt-get install -y --no-install-recommends \
    libusb-1.0-0-dev \
    make && \
    rm -rf /var/lib/apt/lists/*

COPY . $SRC/resetusb
WORKDIR $SRC/resetusb
COPY ./.clusterfuzzlite/build.sh $SRC/build.sh
