#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
REPO_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"

WORK_ROOT="${WORK_ROOT:-${REPO_ROOT}}"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist}"
PACKAGE_TEST_IMAGE_LOCK_FILE="${PACKAGE_TEST_IMAGE_LOCK_FILE:-${REPO_ROOT}/docker/package-test-images.lock}"
PACKAGE_TEST_CHANNELS="${PACKAGE_TEST_CHANNELS:-stable unstable}"
PACKAGE_TEST_ARCHES="${PACKAGE_TEST_ARCHES:-amd64 arm64 armv7}"
BINFMT_IMAGE="${BINFMT_IMAGE:-tonistiigi/binfmt@sha256:d3b963f787999e6c0219a48dba02978769286ff61a5f4d26245cb6a6e5567ea3}"
SEMVER_RELEASE_TAG_REGEX='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
DEV_ARTIFACT_VERSION_REGEX='^dev-[0-9a-f]{12}$'
LOCKED_IMAGE_REF_REGEX='^[a-z0-9./_-]+(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$'
ARTIFACT_VERSION_RESOLVED=""

declare -A ARCH_PLATFORM=(
	[amd64]="linux/amd64"
	[arm64]="linux/arm64"
	[armv7]="linux/arm/v7"
)

declare -A ARCH_DEB=(
	[amd64]="amd64"
	[arm64]="arm64"
	[armv7]="armhf"
)

declare -A ARCH_RPM=(
	[amd64]="x86_64"
	[arm64]="aarch64"
)

declare -A ARCH_BINFMT=(
	[arm64]="arm64"
	[armv7]="arm"
)

declare -A PLATFORM_SUPPORT_VERIFIED=()

validate_locked_image_ref() {
	local name="$1"
	local value="$2"

	if [[ ! "${value}" =~ ${LOCKED_IMAGE_REF_REGEX} ]]; then
		echo "Unexpected ${name}: ${value}" >&2
		exit 1
	fi
}

load_package_test_image_lock() {
	local required_vars=(
		DEBIAN_STABLE_AMD64_IMAGE
		DEBIAN_STABLE_ARM64_IMAGE
		DEBIAN_STABLE_ARMV7_IMAGE
		DEBIAN_UNSTABLE_AMD64_IMAGE
		DEBIAN_UNSTABLE_ARM64_IMAGE
		DEBIAN_UNSTABLE_ARMV7_IMAGE
		UBUNTU_STABLE_AMD64_IMAGE
		UBUNTU_STABLE_ARM64_IMAGE
		UBUNTU_STABLE_ARMV7_IMAGE
		UBUNTU_UNSTABLE_AMD64_IMAGE
		UBUNTU_UNSTABLE_ARM64_IMAGE
		UBUNTU_UNSTABLE_ARMV7_IMAGE
		FEDORA_STABLE_AMD64_IMAGE
		FEDORA_UNSTABLE_AMD64_IMAGE
	)
	local name

	if [[ ! -f "${PACKAGE_TEST_IMAGE_LOCK_FILE}" ]]; then
		echo "Package test image lock file not found: ${PACKAGE_TEST_IMAGE_LOCK_FILE}" >&2
		exit 1
	fi

	# shellcheck disable=SC1090
	source "${PACKAGE_TEST_IMAGE_LOCK_FILE}"

	for name in "${required_vars[@]}"; do
		if [[ -z "${!name:-}" ]]; then
			echo "Package test image lock is missing ${name}" >&2
			exit 1
		fi

		validate_locked_image_ref "${name}" "${!name}"
	done

	validate_locked_image_ref "BINFMT_IMAGE" "${BINFMT_IMAGE}"
}

resolve_package_test_image() {
	local distro="$1"
	local channel="$2"
	local arch="$3"

	case "${distro}:${channel}:${arch}" in
		debian:stable:amd64)
			printf '%s\n' "${DEBIAN_STABLE_AMD64_IMAGE}"
			;;
		debian:stable:arm64)
			printf '%s\n' "${DEBIAN_STABLE_ARM64_IMAGE}"
			;;
		debian:stable:armv7)
			printf '%s\n' "${DEBIAN_STABLE_ARMV7_IMAGE}"
			;;
		debian:unstable:amd64)
			printf '%s\n' "${DEBIAN_UNSTABLE_AMD64_IMAGE}"
			;;
		debian:unstable:arm64)
			printf '%s\n' "${DEBIAN_UNSTABLE_ARM64_IMAGE}"
			;;
		debian:unstable:armv7)
			printf '%s\n' "${DEBIAN_UNSTABLE_ARMV7_IMAGE}"
			;;
		ubuntu:stable:amd64)
			printf '%s\n' "${UBUNTU_STABLE_AMD64_IMAGE}"
			;;
		ubuntu:stable:arm64)
			printf '%s\n' "${UBUNTU_STABLE_ARM64_IMAGE}"
			;;
		ubuntu:stable:armv7)
			printf '%s\n' "${UBUNTU_STABLE_ARMV7_IMAGE}"
			;;
		ubuntu:unstable:amd64)
			printf '%s\n' "${UBUNTU_UNSTABLE_AMD64_IMAGE}"
			;;
		ubuntu:unstable:arm64)
			printf '%s\n' "${UBUNTU_UNSTABLE_ARM64_IMAGE}"
			;;
		ubuntu:unstable:armv7)
			printf '%s\n' "${UBUNTU_UNSTABLE_ARMV7_IMAGE}"
			;;
		fedora:stable:amd64)
			printf '%s\n' "${FEDORA_STABLE_AMD64_IMAGE}"
			;;
		fedora:unstable:amd64)
			printf '%s\n' "${FEDORA_UNSTABLE_AMD64_IMAGE}"
			;;
		*)
			echo "Unsupported package test target: ${distro}/${channel}/${arch}" >&2
			exit 1
			;;
	esac
}

require_artifact_version() {
	local version="$1"

	if [[ "${version}" =~ ${SEMVER_RELEASE_TAG_REGEX} ]]; then
		return
	fi

	if [[ "${version}" =~ ${DEV_ARTIFACT_VERSION_REGEX} ]]; then
		return
	fi

	echo "Unexpected artifact version: ${version}" >&2
	exit 1
}

probe_platform_support() {
	local arch="$1"
	local image="$2"

	docker run --rm \
		--platform="${ARCH_PLATFORM[${arch}]}" \
		--entrypoint /bin/sh \
		"${image}" \
		-c 'exit 0' >/dev/null 2>&1
}

ensure_platform_support() {
	local arch="$1"
	local image="$2"
	local binfmt_arch="${ARCH_BINFMT[${arch}]:-}"

	if [[ -n "${PLATFORM_SUPPORT_VERIFIED[${arch}]:-}" ]]; then
		return
	fi

	if probe_platform_support "${arch}" "${image}"; then
		PLATFORM_SUPPORT_VERIFIED["${arch}"]=1
		return
	fi

	if [[ -n "${binfmt_arch}" ]]; then
		docker run --privileged --rm "${BINFMT_IMAGE}" --install "${binfmt_arch}" >/dev/null
		if probe_platform_support "${arch}" "${image}"; then
			PLATFORM_SUPPORT_VERIFIED["${arch}"]=1
			return
		fi
	fi

	echo "Docker cannot execute ${ARCH_PLATFORM[${arch}]} containers. Install the required binfmt emulator or adjust PACKAGE_TEST_ARCHES." >&2
	exit 1
}

with_extracted_tarball() {
	local tarball_file="$1"
	local callback="$2"
	local extracted_dir
	local rc=0

	extracted_dir="$(mktemp -d "${WORK_ROOT}/.resetusb-tarball.XXXXXX")"
	tar -xzf "${tarball_file}" -C "${extracted_dir}"
	"${callback}" "${extracted_dir}" || rc=$?
	rm -rf "${extracted_dir}"
	return "${rc}"
}

discover_artifact_version() {
	local version_override="${ARTIFACT_VERSION:-}"
	local name
	local version
	local -a versions=()
	local -a unique_versions=()

	if [[ -n "${version_override}" ]]; then
		require_artifact_version "${version_override}"
		printf '%s\n' "${version_override}"
		return
	fi

	while IFS= read -r name; do
		case "${name}" in
			*.sha256|*.sigstore.json|*.spdx.json|*-release-manifest.json)
				continue
				;;
			resetusb-*-linux-amd64.tar.gz)
				version="${name#resetusb-}"
				version="${version%-linux-amd64.tar.gz}"
				;;
			resetusb-*-linux-arm64.tar.gz)
				version="${name#resetusb-}"
				version="${version%-linux-arm64.tar.gz}"
				;;
			resetusb-*-linux-armv7.tar.gz)
				version="${name#resetusb-}"
				version="${version%-linux-armv7.tar.gz}"
				;;
			resetusb-*-debian-amd64.deb)
				version="${name#resetusb-}"
				version="${version%-debian-amd64.deb}"
				;;
			resetusb-*-debian-arm64.deb)
				version="${name#resetusb-}"
				version="${version%-debian-arm64.deb}"
				;;
			resetusb-*-debian-armhf.deb)
				version="${name#resetusb-}"
				version="${version%-debian-armhf.deb}"
				;;
			resetusb-*-ubuntu-amd64.deb)
				version="${name#resetusb-}"
				version="${version%-ubuntu-amd64.deb}"
				;;
			resetusb-*-ubuntu-arm64.deb)
				version="${name#resetusb-}"
				version="${version%-ubuntu-arm64.deb}"
				;;
			resetusb-*-ubuntu-armhf.deb)
				version="${name#resetusb-}"
				version="${version%-ubuntu-armhf.deb}"
				;;
			resetusb-*-fedora-x86_64.rpm)
				version="${name#resetusb-}"
				version="${version%-fedora-x86_64.rpm}"
				;;
			*)
				echo "Unexpected primary artifact in ${DIST_DIR}: ${name}" >&2
				exit 1
				;;
		esac

		require_artifact_version "${version}"
		versions+=("${version}")
	done < <(find "${DIST_DIR}" -maxdepth 1 -type f -print | sed 's#.*/##' | sort)

	if [[ ${#versions[@]} -eq 0 ]]; then
		echo "No primary release artifacts found in ${DIST_DIR}" >&2
		exit 1
	fi

	mapfile -t unique_versions < <(printf '%s\n' "${versions[@]}" | sort -u)
	if [[ ${#unique_versions[@]} -ne 1 ]]; then
		printf 'Expected exactly one artifact version in %s, found: %s\n' \
			"${DIST_DIR}" "${unique_versions[*]}" >&2
		exit 1
	fi

	printf '%s\n' "${unique_versions[0]}"
}

artifact_path() {
	local filename="$1"

	printf '%s/%s\n' "${DIST_DIR}" "${filename}"
}

require_artifact() {
	local path="$1"

	if [[ -z "${path}" || ! -f "${path}" ]]; then
		echo "Required artifact not found" >&2
		exit 1
	fi
}

verify_artifact_checksum() {
	local artifact="$1"
	local checksum_file="${artifact}.sha256"

	require_artifact "${checksum_file}"
	if command -v sha256sum >/dev/null 2>&1; then
		(
			cd "$(dirname "${artifact}")"
			sha256sum --check --strict "$(basename "${checksum_file}")" >/dev/null
		)
		return
	fi

	if command -v shasum >/dev/null 2>&1; then
		(
			cd "$(dirname "${artifact}")"
			shasum -a 256 --check "$(basename "${checksum_file}")" >/dev/null
		)
		return
	fi

	echo "sha256sum or shasum is required to verify release checksums" >&2
	exit 1
}

run_deb_test() {
	local distro="$1"
	local channel="$2"
	local arch="$3"
	local image="$4"
	local package_arch="${ARCH_DEB[${arch}]}"
	local package_file
	local tarball_file

	package_file="$(artifact_path "resetusb-${ARTIFACT_VERSION_RESOLVED}-${distro}-${package_arch}.deb")"
	tarball_file="$(artifact_path "resetusb-${ARTIFACT_VERSION_RESOLVED}-linux-${arch}.tar.gz")"
	require_artifact "${package_file}"
	require_artifact "${tarball_file}"
	verify_artifact_checksum "${package_file}"
	verify_artifact_checksum "${tarball_file}"
	ensure_platform_support "${arch}" "${image}"

	echo "==> ${distro}/${channel}/${arch}"
	run_deb_test_with_tarball_mount() {
		local extracted_dir="$1"

		docker run --rm \
			--platform="${ARCH_PLATFORM[${arch}]}" \
			-v "${WORK_ROOT}":/work:ro \
			-v "${DIST_DIR}":/dist:ro \
			-v "${extracted_dir}":/tarball:ro \
			-w /work \
			"${image}" \
			sh -euxc '
				export DEBIAN_FRONTEND=noninteractive
				apt-get update
				apt-get install -y --no-install-recommends ca-certificates passwd
				dpkg-deb -I /dist/'"$(basename "${package_file}")"' | grep -q "Package: resetusb"
				dpkg-deb -I /dist/'"$(basename "${package_file}")"' | grep -q "Architecture: '"${package_arch}"'"
				dpkg-deb -c /dist/'"$(basename "${package_file}")"' | grep -Eq "usr/share/man/man8/resetusb\\.8(\\.gz)?$"
				apt-get install -y /dist/'"$(basename "${package_file}")"'
				test -x /usr/sbin/resetusb
				ldd /usr/sbin/resetusb | grep -q libusb
				useradd -m tester
				set +e
				su -s /bin/sh -c /usr/sbin/resetusb tester >/tmp/pkg.out 2>/tmp/pkg.err
				rc=$?
				set -e
				test "$rc" -ne 0
				grep -q "Must be root" /tmp/pkg.err

				binary="$(find /tarball -type f -name resetusb | head -n 1)"
				test -x "$binary"
				find /tarball -type f -name "resetusb.8*" | grep -q .
				ldd "$binary" | grep -q libusb
				set +e
				su -s /bin/sh -c "$binary" tester >/tmp/tar.out 2>/tmp/tar.err
				rc=$?
				set -e
				test "$rc" -ne 0
				grep -q "Must be root" /tmp/tar.err
			'
	}

	with_extracted_tarball "${tarball_file}" run_deb_test_with_tarball_mount
}

run_rpm_test() {
	local channel="$1"
	local arch="$2"
	local image="$3"
	local rpm_arch="${ARCH_RPM[${arch}]}"
	local package_file
	local tarball_file

	package_file="$(artifact_path "resetusb-${ARTIFACT_VERSION_RESOLVED}-fedora-${rpm_arch}.rpm")"
	tarball_file="$(artifact_path "resetusb-${ARTIFACT_VERSION_RESOLVED}-linux-${arch}.tar.gz")"
	require_artifact "${package_file}"
	require_artifact "${tarball_file}"
	verify_artifact_checksum "${package_file}"
	verify_artifact_checksum "${tarball_file}"
	ensure_platform_support "${arch}" "${image}"

	echo "==> fedora/${channel}/${arch}"
	run_rpm_test_with_tarball_mount() {
		local extracted_dir="$1"

		docker run --rm \
			--platform="${ARCH_PLATFORM[${arch}]}" \
			-v "${WORK_ROOT}":/work:ro \
			-v "${DIST_DIR}":/dist:ro \
			-v "${extracted_dir}":/tarball:ro \
			-w /work \
			"${image}" \
			sh -euxc '
				rpm -qpi /dist/'"$(basename "${package_file}")"' | grep -Eq "^Name[[:space:]]*: resetusb$"
				rpm -qpi /dist/'"$(basename "${package_file}")"' | grep -Eq "^Architecture[[:space:]]*: '"${rpm_arch}"'$"
				rpm -qlp /dist/'"$(basename "${package_file}")"' | grep -Eq "^/usr/share/man/man8/resetusb\\.8(\\.gz)?$"
				dnf install -y shadow-utils util-linux /dist/'"$(basename "${package_file}")"'
				test -x /usr/sbin/resetusb
				ldd /usr/sbin/resetusb | grep -q libusb
				useradd -m tester
				set +e
				su -s /bin/sh -c /usr/sbin/resetusb tester >/tmp/pkg.out 2>/tmp/pkg.err
				rc=$?
				set -e
				test "$rc" -ne 0
				grep -q "Must be root" /tmp/pkg.err

				binary="$(find /tarball -type f -name resetusb | head -n 1)"
				test -x "$binary"
				find /tarball -type f -name "resetusb.8*" | grep -q .
				ldd "$binary" | grep -q libusb
				set +e
				su -s /bin/sh -c "$binary" tester >/tmp/tar.out 2>/tmp/tar.err
				rc=$?
				set -e
				test "$rc" -ne 0
				grep -q "Must be root" /tmp/tar.err
			'
	}

	with_extracted_tarball "${tarball_file}" run_rpm_test_with_tarball_mount
}

main() {
	local channel
	local arch

	load_package_test_image_lock

	if [[ ! -d "${DIST_DIR}" ]]; then
		echo "Artifact directory not found: ${DIST_DIR}" >&2
		exit 1
	fi

	ARTIFACT_VERSION_RESOLVED="$(discover_artifact_version)"

	for channel in ${PACKAGE_TEST_CHANNELS}; do
		for arch in ${PACKAGE_TEST_ARCHES}; do
			run_deb_test debian "${channel}" "${arch}" \
				"$(resolve_package_test_image debian "${channel}" "${arch}")"
			run_deb_test ubuntu "${channel}" "${arch}" \
				"$(resolve_package_test_image ubuntu "${channel}" "${arch}")"
		done

		if [[ " ${PACKAGE_TEST_ARCHES} " == *" amd64 "* ]]; then
			run_rpm_test "${channel}" amd64 \
				"$(resolve_package_test_image fedora "${channel}" amd64)"
		fi
	done
}

main "$@"
