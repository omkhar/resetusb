FROM debian:trixie@sha256:55a15a112b42be10bfc8092fcc40b6748dc236f7ef46a358d9392b339e9d60e8 AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      build-essential \
      libusb-1.0-0-dev; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .
RUN make CC=gcc && strip /src/resetusb

FROM debian:trixie-slim@sha256:26f98ccd92fd0a44d6928ce8ff8f4921b4d2f535bfa07555ee5d18f61429cf0c

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      libusb-1.0-0; \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /src/resetusb /usr/sbin/resetusb

ENTRYPOINT ["/usr/sbin/resetusb"]
