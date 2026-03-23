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
	DEBIAN_SUITE
)

for name in "${required_vars[@]}"; do
	if [[ -z "${!name:-}" ]]; then
		echo "release builder lock is missing ${name}" >&2
		exit 1
	fi
done

exec docker build \
	--build-arg "DEBIAN_BASE_IMAGE=${DEBIAN_BASE_IMAGE}" \
	--build-arg "DEBIAN_SNAPSHOT_URL=${DEBIAN_SNAPSHOT_URL}" \
	--build-arg "DEBIAN_SNAPSHOT_TIMESTAMP=${DEBIAN_SNAPSHOT_TIMESTAMP}" \
	--build-arg "DEBIAN_SUITE=${DEBIAN_SUITE}" \
	"$@"
