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

normalize_arch() {
	local raw="$1"

	case "${raw}" in
		x86_64 | amd64)
			printf '%s\n' amd64
			;;
		aarch64 | arm64)
			printf '%s\n' arm64
			;;
		*)
			echo "Unsupported container architecture: ${raw}" >&2
			exit 1
			;;
	esac
}

resolve_prefight_platform() {
	local server_arch

	server_arch="$(
		docker version --format '{{.Server.Arch}}' 2>/dev/null || true
	)"
	if [[ -z "${server_arch}" || "${server_arch}" == "<no value>" ]]; then
		server_arch="$(uname -m)"
	fi

	printf 'linux/%s\n' "$(normalize_arch "${server_arch}")"
}

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
BUILDER_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"
LOCK_FILE="${BUILDER_ROOT}/docker/release-builder.lock"
SOURCE_ROOT="${SOURCE_ROOT:-${BUILDER_ROOT}}"
WORK_ROOT="${WORK_ROOT:-${SOURCE_ROOT}}"
DIST_DIR="${DIST_DIR:-${SOURCE_ROOT}/dist}"
CONTAINER_UID_GID="$(id -u):$(id -g)"

if [[ ! -f "${LOCK_FILE}" ]]; then
	echo "release builder lock file not found: ${LOCK_FILE}" >&2
	exit 1
fi

# shellcheck disable=SC1090
source "${LOCK_FILE}"

required_lock_vars=(
	DEBIAN_SNAPSHOT_TIMESTAMP
	DEBIAN_SNAPSHOT_INRELEASE_SHA256
	DEBIAN_SUITE
)

for name in "${required_lock_vars[@]}"; do
	if [[ -z "${!name:-}" ]]; then
		echo "release builder lock is missing ${name}" >&2
		exit 1
	fi
done

BUILDER_IMAGE="${BUILDER_IMAGE:-resetusb-release-builder:preflight}"
PREFLIGHT_IMAGE="${PREFLIGHT_IMAGE:-resetusb-release-preflight:preflight}"
GITLEAKS_IMAGE="${GITLEAKS_IMAGE:-zricethezav/gitleaks:v8.30.0@sha256:691af3c7c5a48b16f187ce3446d5f194838f91238f27270ed36eef6359a574d9}"
RELEASE_PLATFORM="${RELEASE_PLATFORM:-linux/amd64}"
PREFLIGHT_PLATFORM="${PREFLIGHT_PLATFORM:-$(resolve_prefight_platform)}"
PREFLIGHT_BUILDER_IMAGE="${PREFLIGHT_BUILDER_IMAGE:-resetusb-release-builder:preflight-native}"

validate_image_ref "BUILDER_IMAGE" "${BUILDER_IMAGE}"
validate_image_ref "PREFLIGHT_IMAGE" "${PREFLIGHT_IMAGE}"
validate_image_ref "GITLEAKS_IMAGE" "${GITLEAKS_IMAGE}"
validate_image_ref "PREFLIGHT_BUILDER_IMAGE" "${PREFLIGHT_BUILDER_IMAGE}"

require_cmd docker

tmp_dockerfile="$(mktemp)"
cleanup() {
	rm -f "$tmp_dockerfile"
}
trap cleanup EXIT

echo "==> Building release builder image"
"${BUILDER_ROOT}"/scripts/docker-build-release-builder.sh --platform="${RELEASE_PLATFORM}" \
	-f "${BUILDER_ROOT}/docker/release-builder.Dockerfile" \
	-t "${BUILDER_IMAGE}" "${BUILDER_ROOT}"

if [[ "${PREFLIGHT_PLATFORM}" == "${RELEASE_PLATFORM}" ]]; then
	PREFLIGHT_BUILDER_IMAGE="${BUILDER_IMAGE}"
else
	echo "==> Building native preflight builder image"
	"${BUILDER_ROOT}"/scripts/docker-build-release-builder.sh --platform="${PREFLIGHT_PLATFORM}" \
		-f "${BUILDER_ROOT}/docker/release-builder.Dockerfile" \
		-t "${PREFLIGHT_BUILDER_IMAGE}" "${BUILDER_ROOT}"
fi

cat >"${tmp_dockerfile}" <<EOF
FROM ${PREFLIGHT_BUILDER_IMAGE}
ENV DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    echo 'Acquire::Retries "6";' > /etc/apt/apt.conf.d/80-retries; \
    apt-get update; \
    snapshot_inrelease="/var/lib/apt/lists/snapshot.debian.org_archive_debian_${DEBIAN_SNAPSHOT_TIMESTAMP}_dists_${DEBIAN_SUITE}_InRelease"; \
    test -f "\${snapshot_inrelease}"; \
    echo "${DEBIAN_SNAPSHOT_INRELEASE_SHA256}  \${snapshot_inrelease}" | sha256sum --check --strict; \
    apt-get install -y --no-install-recommends \
      clang \
      clang-format \
      clang-tools \
      cppcheck \
      shellcheck; \
    rm -rf /var/lib/apt/lists/*
EOF

echo "==> Building release preflight image"
docker build --platform="${PREFLIGHT_PLATFORM}" \
	-f "${tmp_dockerfile}" -t "${PREFLIGHT_IMAGE}" "${BUILDER_ROOT}"

echo "==> Running Linux release preflight"
docker run --rm --platform="${PREFLIGHT_PLATFORM}" \
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
