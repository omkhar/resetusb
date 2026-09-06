#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
BUILDER_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"

# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

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
GITLEAKS_IMAGE="${GITLEAKS_IMAGE:-zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f}"
RELEASE_PLATFORM="${RELEASE_PLATFORM:-linux/amd64}"
PREFLIGHT_PLATFORM="${PREFLIGHT_PLATFORM:-$(resolve_prefight_platform)}"
PREFLIGHT_BUILDER_IMAGE="${PREFLIGHT_BUILDER_IMAGE:-resetusb-release-builder:preflight-native}"

validate_image_ref "BUILDER_IMAGE" "${BUILDER_IMAGE}"
validate_image_ref "PREFLIGHT_IMAGE" "${PREFLIGHT_IMAGE}"
validate_image_ref "GITLEAKS_IMAGE" "${GITLEAKS_IMAGE}"
validate_image_ref "PREFLIGHT_BUILDER_IMAGE" "${PREFLIGHT_BUILDER_IMAGE}"

require_cmd docker

git_common_dir="$(
	git -C "${SOURCE_ROOT}" rev-parse --path-format=absolute --git-common-dir
)"
if [[ ! -d "${git_common_dir}" || "${git_common_dir}" == "/" ]]; then
	echo "Unsafe or missing Git common directory: ${git_common_dir}" >&2
	exit 1
fi

preflight_docker_args=(
	--rm
	--platform="${PREFLIGHT_PLATFORM}"
	--user "${CONTAINER_UID_GID}"
	-v "${SOURCE_ROOT}:/source"
	-w /source
)
if [[ -f "${SOURCE_ROOT}/.git" ]]; then
	preflight_docker_args+=(-v "${git_common_dir}:${git_common_dir}:ro")
fi

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
COPY scripts/install-actionlint.sh /tmp/install-actionlint.sh
RUN set -eux; \
    echo 'Acquire::Retries "6";' > /etc/apt/apt.conf.d/80-retries; \
    apt-get update; \
    snapshot_inrelease="/var/lib/apt/lists/snapshot.debian.org_archive_debian_${DEBIAN_SNAPSHOT_TIMESTAMP}_dists_${DEBIAN_SUITE}_InRelease"; \
    test -f "\${snapshot_inrelease}"; \
    echo "${DEBIAN_SNAPSHOT_INRELEASE_SHA256}  \${snapshot_inrelease}" | sha256sum --check --strict; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      clang \
      clang-format \
      clang-tools \
      cppcheck \
      curl \
      git \
      python3 \
      python3-yaml \
      shellcheck; \
    /bin/bash /tmp/install-actionlint.sh; \
    rm -rf /var/lib/apt/lists/*
EOF

echo "==> Building release preflight image"
docker build --platform="${PREFLIGHT_PLATFORM}" \
	-f "${tmp_dockerfile}" -t "${PREFLIGHT_IMAGE}" "${BUILDER_ROOT}"

echo "==> Running Linux release preflight"
docker run \
	"${preflight_docker_args[@]}" \
	"${PREFLIGHT_IMAGE}" \
	bash -lc '
		set -euo pipefail
		commit_count="$(git -C /source rev-list --count --all)"
		case "${commit_count}" in
			""|*[!0-9]*)
				echo "Release preflight could not count repository commits" >&2
				exit 1
				;;
		esac
		if [ "${commit_count}" -eq 0 ]; then
			echo "Release preflight found no repository commits" >&2
			exit 1
		fi
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
gitleaks_docker_args=(
	--rm
	-v "${SOURCE_ROOT}:/repo:ro"
	-w /repo
	--entrypoint /bin/sh
)
if [[ -f "${SOURCE_ROOT}/.git" ]]; then
	gitleaks_docker_args+=(-v "${git_common_dir}:${git_common_dir}:ro")
fi
docker run \
	"${gitleaks_docker_args[@]}" \
	"${GITLEAKS_IMAGE}" \
	-ec '
		commit_count="$(git -C /repo rev-list --count --all)"
		case "${commit_count}" in
			""|*[!0-9]*)
				echo "Gitleaks could not count repository commits" >&2
				exit 1
				;;
		esac
		if [ "${commit_count}" -eq 0 ]; then
			echo "Gitleaks found no repository commits to scan" >&2
			exit 1
		fi
		exec gitleaks git /repo --log-opts=--all --no-banner --redact --exit-code 1
	'
