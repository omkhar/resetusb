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
BUILDER_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"
SOURCE_ROOT="${SOURCE_ROOT:-${BUILDER_ROOT}}"
WORK_ROOT="${WORK_ROOT:-${SOURCE_ROOT}}"
DIST_DIR="${DIST_DIR:-${SOURCE_ROOT}/dist}"

BUILDER_IMAGE="${BUILDER_IMAGE:-resetusb-release-builder:preflight}"
PREFLIGHT_IMAGE="${PREFLIGHT_IMAGE:-resetusb-release-preflight:preflight}"
GITLEAKS_IMAGE="${GITLEAKS_IMAGE:-zricethezav/gitleaks:v8.30.0@sha256:691af3c7c5a48b16f187ce3446d5f194838f91238f27270ed36eef6359a574d9}"

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

echo "==> Building release artifacts"
SOURCE_GIT_SHA="$(
	if git -C "${SOURCE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "${SOURCE_ROOT}" rev-parse HEAD
	else
		printf "%s" "${GITHUB_SHA:-}"
	fi
)"
SOURCE_DATE_EPOCH="$(
	if git -C "${SOURCE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "${SOURCE_ROOT}" log -1 --format=%ct HEAD
	else
		printf "%s" "${SOURCE_DATE_EPOCH:-}"
	fi
)"
if [[ ! "${SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]]; then
	echo "Unable to resolve SOURCE_DATE_EPOCH from the source commit" >&2
	exit 1
fi
docker run --rm --platform=linux/amd64 \
	-e GITHUB_SHA="${SOURCE_GIT_SHA}" \
	-e GITHUB_REF_NAME="${GITHUB_REF_NAME:-}" \
	-e GITHUB_REF_TYPE="${GITHUB_REF_TYPE:-}" \
	-e SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
	-e SOURCE_ROOT=/source \
	-e DIST_DIR=/source/dist \
	-e WORK_DIR=/tmp/resetusb-build \
	-v "${BUILDER_ROOT}":/builder:ro \
	-v "${SOURCE_ROOT}":/source \
	-w /source \
	"${BUILDER_IMAGE}" \
	bash -lc '/builder/scripts/build-release-artifacts.sh'

echo "==> Verifying release artifact reproducibility"
GITHUB_SHA="${SOURCE_GIT_SHA}" \
	SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
	SOURCE_ROOT="${SOURCE_ROOT}" \
	DIST_DIR="${DIST_DIR}" \
	BUILDER_IMAGE="${BUILDER_IMAGE}" \
	"${BUILDER_ROOT}/scripts/verify-release-reproducibility.sh"

echo "==> Running stable and unstable package integration tests"
WORK_ROOT="${WORK_ROOT}" DIST_DIR="${DIST_DIR}" \
	"${BUILDER_ROOT}/scripts/test-package-integration.sh"

echo "==> Running gitleaks history scan"
docker run --rm \
	-v "${SOURCE_ROOT}":/repo \
	-w /repo \
	"${GITLEAKS_IMAGE}" \
	git /repo --log-opts="--all" --no-banner --redact --exit-code 1
