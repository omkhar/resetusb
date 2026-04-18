#!/usr/bin/env bash

set -euo pipefail

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "$1 not found" >&2
		exit 1
	}
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

list_artifacts() {
	local dir="$1"

	find "${dir}" -maxdepth 1 -type f | sed 's#.*/##' | sort
}

sha256_file() {
	local path="$1"

	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "${path}" | awk '{print $1}'
		return
	fi

	if command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "${path}" | awk '{print $1}'
		return
	fi

	echo "sha256sum or shasum not found" >&2
	exit 1
}

compare_artifacts() {
	local left_dir="$1"
	local right_dir="$2"
	local file
	local left_sha
	local right_sha
	local -a left_files=()
	local -a right_files=()

	while IFS= read -r file; do
		left_files+=("${file}")
	done < <(list_artifacts "${left_dir}")

	while IFS= read -r file; do
		right_files+=("${file}")
	done < <(list_artifacts "${right_dir}")

	if [[ ${#left_files[@]} -eq 0 ]]; then
		echo "No release artifacts found in ${left_dir}" >&2
		exit 1
	fi

	if [[ "${left_files[*]}" != "${right_files[*]}" ]]; then
		diff -u <(printf '%s\n' "${left_files[@]}") \
			<(printf '%s\n' "${right_files[@]}")
		echo "Release artifact sets differ between reproducibility runs" >&2
		exit 1
	fi

	for file in "${left_files[@]}"; do
		left_sha="$(sha256_file "${left_dir}/${file}")"
		right_sha="$(sha256_file "${right_dir}/${file}")"
		if [[ "${left_sha}" != "${right_sha}" ]]; then
			echo "Artifact digest mismatch for ${file}" >&2
			echo "first:  ${left_sha}" >&2
			echo "second: ${right_sha}" >&2
			exit 1
		fi
	done
}

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
BUILDER_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"
SOURCE_ROOT="${SOURCE_ROOT:-${BUILDER_ROOT}}"
DIST_DIR="${DIST_DIR:-${SOURCE_ROOT}/dist}"
BUILDER_IMAGE="${BUILDER_IMAGE:-resetusb-release-builder:preflight}"
CONTAINER_UID_GID="$(id -u):$(id -g)"

require_cmd docker
require_cmd find
require_cmd sort

if [[ ! -d "${DIST_DIR}" ]]; then
	echo "Artifact directory not found: ${DIST_DIR}" >&2
	exit 1
fi

source_date_epoch="$(resolve_source_date_epoch)"
# On macOS/Colima bind mounts, directories created under TMPDIR can appear as
# root-owned inside the Linux container even when the caller UID is mapped
# through. Creating the scratch tree under SOURCE_ROOT keeps the rebuild output
# writable to the unprivileged container user we use for reproducibility checks.
repro_check_dir="$(mktemp -d "${SOURCE_ROOT}/.resetusb-repro-check.XXXXXX")"
repro_dist_dir="${repro_check_dir}/dist"
mkdir -p "${repro_dist_dir}"
cleanup() {
	if [[ ! -d "${repro_check_dir}" ]]; then
		return
	fi

	docker run --rm --platform=linux/amd64 \
		-v "${repro_check_dir}":/tmp/resetusb-repro-check \
		"${BUILDER_IMAGE}" \
		bash -lc 'rm -rf /tmp/resetusb-repro-check/* /tmp/resetusb-repro-check/.[!.]* /tmp/resetusb-repro-check/..?*' >/dev/null 2>&1 || true
	rm -rf "${repro_check_dir}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

source_git_sha="$(
	if git -C "${SOURCE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "${SOURCE_ROOT}" rev-parse HEAD
	else
		printf "%s" "${GITHUB_SHA:-}"
	fi
)"

docker run --rm --platform=linux/amd64 \
	--user "${CONTAINER_UID_GID}" \
	-e GITHUB_SHA="${source_git_sha}" \
	-e GITHUB_REF_NAME="${GITHUB_REF_NAME:-}" \
	-e GITHUB_REF_TYPE="${GITHUB_REF_TYPE:-}" \
	-e SOURCE_DATE_EPOCH="${source_date_epoch}" \
	-e SOURCE_ROOT=/source \
	-e DIST_DIR=/tmp/resetusb-repro-check/dist \
	-e WORK_DIR=/tmp/resetusb-build \
	-v "${BUILDER_ROOT}":/builder:ro \
	-v "${repro_check_dir}":/tmp/resetusb-repro-check \
	-v "${SOURCE_ROOT}":/source \
	-w /source \
	"${BUILDER_IMAGE}" \
	bash -lc '/builder/scripts/build-release-artifacts.sh'

compare_artifacts "${DIST_DIR}" "${repro_dist_dir}"
