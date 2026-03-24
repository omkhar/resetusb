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

resolve_source_git_sha() {
	if git -C "${SOURCE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "${SOURCE_ROOT}" rev-parse HEAD
		return
	fi

	if [[ -n "${GITHUB_SHA:-}" ]]; then
		printf '%s\n' "${GITHUB_SHA}"
		return
	fi

	echo "GITHUB_SHA is required when git metadata is unavailable" >&2
	exit 1
}

resolve_source_date_epoch() {
	if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
		if [[ ! "${SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]]; then
			echo "SOURCE_DATE_EPOCH must be an integer" >&2
			exit 1
		fi
		printf '%s\n' "${SOURCE_DATE_EPOCH}"
		return
	fi

	if git -C "${SOURCE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "${SOURCE_ROOT}" log -1 --format=%ct HEAD
		return
	fi

	echo "SOURCE_DATE_EPOCH is required when git metadata is unavailable" >&2
	exit 1
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
BUILD_BUILDER_IMAGE="${BUILD_BUILDER_IMAGE:-0}"

validate_image_ref "BUILDER_IMAGE" "${BUILDER_IMAGE}"
require_cmd docker
if [[ "${BUILD_BUILDER_IMAGE}" != "0" && "${BUILD_BUILDER_IMAGE}" != "1" ]]; then
	echo "BUILD_BUILDER_IMAGE must be 0 or 1" >&2
	exit 1
fi

if [[ "${BUILD_BUILDER_IMAGE}" == "1" ]]; then
	echo "==> Building release builder image"
	"${BUILDER_ROOT}"/scripts/docker-build-release-builder.sh --platform=linux/amd64 \
		-f "${BUILDER_ROOT}/docker/release-builder.Dockerfile" \
		-t "${BUILDER_IMAGE}" "${BUILDER_ROOT}"
fi

source_git_sha="$(resolve_source_git_sha)"
source_date_epoch="$(resolve_source_date_epoch)"

echo "==> Building release artifacts"
mkdir -p "${DIST_DIR}"
docker run --rm --platform=linux/amd64 \
	-e GITHUB_SHA="${source_git_sha}" \
	-e GITHUB_REF_NAME="${GITHUB_REF_NAME:-}" \
	-e GITHUB_REF_TYPE="${GITHUB_REF_TYPE:-}" \
	-e SOURCE_DATE_EPOCH="${source_date_epoch}" \
	-e SOURCE_ROOT=/source \
	-e DIST_DIR=/dist \
	-e WORK_DIR=/tmp/resetusb-build \
	-v "${BUILDER_ROOT}":/builder:ro \
	-v "${DIST_DIR}":/dist \
	-v "${SOURCE_ROOT}":/source \
	-w /source \
	"${BUILDER_IMAGE}" \
	bash -lc '/builder/scripts/build-release-artifacts.sh'

echo "==> Verifying release artifact reproducibility"
GITHUB_SHA="${source_git_sha}" \
	GITHUB_REF_NAME="${GITHUB_REF_NAME:-}" \
	GITHUB_REF_TYPE="${GITHUB_REF_TYPE:-}" \
	SOURCE_DATE_EPOCH="${source_date_epoch}" \
	SOURCE_ROOT="${SOURCE_ROOT}" \
	DIST_DIR="${DIST_DIR}" \
	BUILDER_IMAGE="${BUILDER_IMAGE}" \
	"${BUILDER_ROOT}/scripts/verify-release-reproducibility.sh"

echo "==> Running stable and unstable package integration tests"
WORK_ROOT="${WORK_ROOT}" DIST_DIR="${DIST_DIR}" \
	"${BUILDER_ROOT}/scripts/test-package-integration.sh"
