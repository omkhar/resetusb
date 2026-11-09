FROM gcr.io/oss-fuzz-base/base-builder:v1@sha256:47bcf5c42c4863af02843d16315014011571e31ece4ac9110a77a2e43949c5d2

# Live mirrors can fail for a short time. apt-get-retry retries each
# apt-get command with backoff.
COPY scripts/apt-get-retry.sh /usr/local/bin/apt-get-retry

RUN apt-get-retry update && apt-get-retry install -y --no-install-recommends \
    libusb-1.0-0-dev \
    make && \
    rm -rf /var/lib/apt/lists/*

COPY . $SRC/resetusb
WORKDIR $SRC/resetusb
COPY ./.clusterfuzzlite/build.sh $SRC/build.sh
