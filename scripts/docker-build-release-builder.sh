#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
BUILDER_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"
LOCK_FILE="${BUILDER_ROOT}/docker/release-builder.lock"

if [[ ! -f "${LOCK_FILE}" ]]; then
	echo "release builder lock file not found: ${LOCK_FILE}" >&2
	exit 1
fi

# shellcheck disable=SC1090
source "${LOCK_FILE}"

required_vars=(
	DEBIAN_BASE_IMAGE
	DEBIAN_SNAPSHOT_URL
	DEBIAN_SNAPSHOT_TIMESTAMP
	DEBIAN_SNAPSHOT_INRELEASE_SHA256
	DEBIAN_SUITE
)

for name in "${required_vars[@]}"; do
	if [[ -z "${!name:-}" ]]; then
		echo "release builder lock is missing ${name}" >&2
		exit 1
	fi
done

base_image_from_dockerfile="$(
	awk 'toupper($1) == "FROM" {print $2; exit}' \
		"${BUILDER_ROOT}/docker/release-builder.Dockerfile"
)"

if [[ "${base_image_from_dockerfile}" != "${DEBIAN_BASE_IMAGE}" ]]; then
	echo "release builder lock base image does not match docker/release-builder.Dockerfile" >&2
	exit 1
fi

have_tag=false
expect_tag_value=false
for arg in "$@"; do
	if [[ "${expect_tag_value}" == true ]]; then
		if [[ -z "${arg}" || "${arg}" == -* ]]; then
			echo "docker build requires a value for -t/--tag" >&2
			exit 1
		fi
		have_tag=true
		expect_tag_value=false
		continue
	fi

	case "${arg}" in
		-t|--tag)
			expect_tag_value=true
			;;
		--tag=*)
			have_tag=true
			;;
	esac
done

if [[ "${expect_tag_value}" == true ]]; then
	echo "docker build requires a value for -t/--tag" >&2
	exit 1
fi

if [[ "${have_tag}" != true ]]; then
	echo "docker build requires -t/--tag for the release builder image" >&2
	exit 1
fi

exec docker build \
	--build-arg "DEBIAN_SNAPSHOT_URL=${DEBIAN_SNAPSHOT_URL}" \
	--build-arg "DEBIAN_SNAPSHOT_TIMESTAMP=${DEBIAN_SNAPSHOT_TIMESTAMP}" \
	--build-arg "DEBIAN_SNAPSHOT_INRELEASE_SHA256=${DEBIAN_SNAPSHOT_INRELEASE_SHA256}" \
	--build-arg "DEBIAN_SUITE=${DEBIAN_SUITE}" \
	"$@"
