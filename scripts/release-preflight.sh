#!/usr/bin/env bash

set -euo pipefail

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "$1 not found" >&2
		exit 1
	}
}

validate_image_ref() {
	local name="$1"
	local value="$2"

	if [[ ! "${value}" =~ ^[A-Za-z0-9./:@_-]+$ ]]; then
		echo "Unexpected ${name}: ${value}" >&2
		exit 1
	fi
}

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
BUILDER_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"
SOURCE_ROOT="${SOURCE_ROOT:-${BUILDER_ROOT}}"
WORK_ROOT="${WORK_ROOT:-${SOURCE_ROOT}}"
DIST_DIR="${DIST_DIR:-${SOURCE_ROOT}/dist}"
CONTAINER_UID_GID="$(id -u):$(id -g)"

BUILDER_IMAGE="${BUILDER_IMAGE:-resetusb-release-builder:preflight}"
PREFLIGHT_IMAGE="${PREFLIGHT_IMAGE:-resetusb-release-preflight:preflight}"
GITLEAKS_IMAGE="${GITLEAKS_IMAGE:-zricethezav/gitleaks:v8.30.0@sha256:691af3c7c5a48b16f187ce3446d5f194838f91238f27270ed36eef6359a574d9}"

validate_image_ref "BUILDER_IMAGE" "${BUILDER_IMAGE}"
validate_image_ref "PREFLIGHT_IMAGE" "${PREFLIGHT_IMAGE}"
validate_image_ref "GITLEAKS_IMAGE" "${GITLEAKS_IMAGE}"

require_cmd docker

tmp_dockerfile="$(mktemp)"
cleanup() {
	rm -f "$tmp_dockerfile"
}
trap cleanup EXIT

echo "==> Building release builder image"
"${BUILDER_ROOT}"/scripts/docker-build-release-builder.sh --platform=linux/amd64 \
	-f "${BUILDER_ROOT}/docker/release-builder.Dockerfile" \
	-t "${BUILDER_IMAGE}" "${BUILDER_ROOT}"

cat >"${tmp_dockerfile}" <<EOF
FROM ${BUILDER_IMAGE}
ENV DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    echo 'Acquire::Retries "6";' > /etc/apt/apt.conf.d/80-retries; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      clang \
      clang-format \
      clang-tools \
      cppcheck \
      shellcheck; \
    rm -rf /var/lib/apt/lists/*
EOF

echo "==> Building release preflight image"
docker build --platform=linux/amd64 \
	-f "${tmp_dockerfile}" -t "${PREFLIGHT_IMAGE}" "${BUILDER_ROOT}"

echo "==> Running Linux release preflight"
docker run --rm --platform=linux/amd64 \
	--user "${CONTAINER_UID_GID}" \
	-v "${SOURCE_ROOT}":/source \
	-w /source \
	"${PREFLIGHT_IMAGE}" \
	bash -lc '
		set -euo pipefail
		make clean
		make CC=gcc
		make CC=gcc test
		make clean
		make CC=clang
		make CC=clang test
		make lint
		make check-format
		scan-build --status-bugs --keep-empty --exclude /usr/include \
			make clean all test
		make clean
		make sanitize CC=gcc
	'

SOURCE_ROOT="${SOURCE_ROOT}" \
	WORK_ROOT="${WORK_ROOT}" \
	DIST_DIR="${DIST_DIR}" \
	BUILDER_IMAGE="${BUILDER_IMAGE}" \
	"${BUILDER_ROOT}/scripts/run-package-smoke.sh"

echo "==> Running gitleaks history scan"
docker run --rm \
	-v "${SOURCE_ROOT}":/repo:ro \
	-w /repo \
	"${GITLEAKS_IMAGE}" \
	git /repo --log-opts="--all" --no-banner --redact --exit-code 1
