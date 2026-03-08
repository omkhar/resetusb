#!/usr/bin/env bash

set -euo pipefail

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "$1 not found" >&2
		exit 1
	}
}

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
REPO_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"

BUILDER_IMAGE="${BUILDER_IMAGE:-resetusb-release-builder:preflight}"
PREFLIGHT_IMAGE="${PREFLIGHT_IMAGE:-resetusb-release-preflight:preflight}"
GITLEAKS_IMAGE="${GITLEAKS_IMAGE:-zricethezav/gitleaks:v8.30.0}"
TRIVY_IMAGE="${TRIVY_IMAGE:-aquasec/trivy:0.61.0}"

require_cmd docker

tmp_dockerfile="$(mktemp)"
cleanup() {
	rm -f "$tmp_dockerfile"
}
trap cleanup EXIT

echo "==> Building release builder image"
docker build -f "${REPO_ROOT}/docker/release-builder.Dockerfile" \
	-t "${BUILDER_IMAGE}" "${REPO_ROOT}"

cat >"${tmp_dockerfile}" <<EOF
FROM ${BUILDER_IMAGE}
ENV DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    echo 'Acquire::Retries "6";' > /etc/apt/apt.conf.d/80-retries; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      clang-format \
      clang-tools \
      cppcheck \
      shellcheck; \
    rm -rf /var/lib/apt/lists/*
EOF

echo "==> Building release preflight image"
docker build -f "${tmp_dockerfile}" -t "${PREFLIGHT_IMAGE}" "${REPO_ROOT}"

echo "==> Running Linux release preflight"
docker run --rm \
	-v "${REPO_ROOT}":/work \
	-w /work \
	"${PREFLIGHT_IMAGE}" \
	bash -lc '
		set -euo pipefail
		make clean
		make CC=gcc
		make CC=gcc test
		make lint
		make check-format
		scan-build --status-bugs --keep-empty --exclude /usr/include \
			make clean all test
		make clean
		make sanitize CC=gcc
	'

echo "==> Running gitleaks history scan"
docker run --rm \
	-v "${REPO_ROOT}":/repo \
	-w /repo \
	"${GITLEAKS_IMAGE}" \
	git /repo --log-opts="--all" --no-banner --redact --exit-code 1

echo "==> Running Trivy filesystem scan"
docker run --rm \
	-v "${REPO_ROOT}":/work \
	-w /work \
	"${TRIVY_IMAGE}" \
	fs --scanners vuln --pkg-types os,library \
	--severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 /work

echo "==> Running Trivy release-builder image scan"
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		"${TRIVY_IMAGE}" \
	image --scanners vuln --pkg-types os,library \
	--severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 \
		"${BUILDER_IMAGE}"
