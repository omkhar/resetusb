#!/usr/bin/env bash

set -euo pipefail

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "$1 not found" >&2
		exit 1
	}
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

	mapfile -t left_files < <(list_artifacts "${left_dir}")
	mapfile -t right_files < <(list_artifacts "${right_dir}")

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

require_cmd docker
require_cmd find
require_cmd sort

if [[ ! -d "${DIST_DIR}" ]]; then
	echo "Artifact directory not found: ${DIST_DIR}" >&2
	exit 1
fi

mkdir -p "${SOURCE_ROOT}/build"
repro_check_dir="$(mktemp -d "${SOURCE_ROOT}/build/repro-check.XXXXXX")"
cleanup() {
	rm -rf "${repro_check_dir}"
}
trap cleanup EXIT

source_git_sha="$(
	if git -C "${SOURCE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "${SOURCE_ROOT}" rev-parse HEAD
	else
		printf "%s" "${GITHUB_SHA:-}"
	fi
)"
repro_check_rel="${repro_check_dir#"${SOURCE_ROOT}"/}"

docker run --rm --platform=linux/amd64 \
	-e GITHUB_SHA="${source_git_sha}" \
	-e GITHUB_REF_NAME="${GITHUB_REF_NAME:-}" \
	-e GITHUB_REF_TYPE="${GITHUB_REF_TYPE:-}" \
	-e SOURCE_ROOT=/source \
	-e DIST_DIR="/source/${repro_check_rel}" \
	-v "${BUILDER_ROOT}":/builder:ro \
	-v "${SOURCE_ROOT}":/source \
	-w /source \
	"${BUILDER_IMAGE}" \
	bash -lc '/builder/scripts/build-release-artifacts.sh'

compare_artifacts "${DIST_DIR}" "${repro_check_dir}"
