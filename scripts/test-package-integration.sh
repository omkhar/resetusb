#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
REPO_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"

DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist}"
PACKAGE_TEST_CHANNELS="${PACKAGE_TEST_CHANNELS:-stable unstable}"
PACKAGE_TEST_ARCHES="${PACKAGE_TEST_ARCHES:-amd64 arm64 armv7}"

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

find_artifact() {
	local pattern="$1"

	find "${DIST_DIR}" -maxdepth 1 -type f -name "${pattern}" | sort | head -n 1
}

require_artifact() {
	local path="$1"

	if [[ -z "${path}" || ! -f "${path}" ]]; then
		echo "Required artifact not found" >&2
		exit 1
	fi
}

run_deb_test() {
	local distro="$1"
	local channel="$2"
	local arch="$3"
	local image="$4"
	local package_arch="${ARCH_DEB[${arch}]}"
	local package_file
	local tarball_file

	package_file="$(find_artifact "resetusb-*-${distro}-${package_arch}.deb")"
	tarball_file="$(find_artifact "resetusb-*-linux-${arch}.tar.gz")"
	require_artifact "${package_file}"
	require_artifact "${tarball_file}"

	echo "==> ${distro}/${channel}/${arch}"
	docker run --rm \
		--platform="${ARCH_PLATFORM[${arch}]}" \
		-v "${REPO_ROOT}":/work \
		-w /work \
		"${image}" \
		sh -euxc '
			export DEBIAN_FRONTEND=noninteractive
			apt-get update
			apt-get install -y --no-install-recommends ca-certificates passwd
			apt-get install -y ./dist/'"$(basename "${package_file}")"'
			test -x /usr/sbin/resetusb
			useradd -m tester
			set +e
			su -s /bin/sh -c /usr/sbin/resetusb tester >/tmp/pkg.out 2>/tmp/pkg.err
			rc=$?
			set -e
			test "$rc" -ne 0
			grep -q "Must be root" /tmp/pkg.err

			mkdir -p /tmp/tarball
			tar -xzf ./dist/'"$(basename "${tarball_file}")"' -C /tmp/tarball
			binary="$(find /tmp/tarball -type f -name resetusb | head -n 1)"
			test -x "$binary"
			set +e
			su -s /bin/sh -c "$binary" tester >/tmp/tar.out 2>/tmp/tar.err
			rc=$?
			set -e
			test "$rc" -ne 0
			grep -q "Must be root" /tmp/tar.err
		'
}

run_rpm_test() {
	local channel="$1"
	local arch="$2"
	local image="$3"
	local rpm_arch="${ARCH_RPM[${arch}]}"
	local package_file
	local tarball_file

	package_file="$(find_artifact "resetusb-*-fedora-${rpm_arch}.rpm")"
	tarball_file="$(find_artifact "resetusb-*-linux-${arch}.tar.gz")"
	require_artifact "${package_file}"
	require_artifact "${tarball_file}"

	echo "==> fedora/${channel}/${arch}"
	docker run --rm \
		--platform="${ARCH_PLATFORM[${arch}]}" \
		-v "${REPO_ROOT}":/work \
		-w /work \
		"${image}" \
		sh -euxc '
			dnf install -y shadow-utils util-linux ./dist/'"$(basename "${package_file}")"'
			test -x /usr/sbin/resetusb
			useradd -m tester
			set +e
			su -s /bin/sh -c /usr/sbin/resetusb tester >/tmp/pkg.out 2>/tmp/pkg.err
			rc=$?
			set -e
			test "$rc" -ne 0
			grep -q "Must be root" /tmp/pkg.err

			mkdir -p /tmp/tarball
			tar -xzf ./dist/'"$(basename "${tarball_file}")"' -C /tmp/tarball
			binary="$(find /tmp/tarball -type f -name resetusb | head -n 1)"
			test -x "$binary"
			set +e
			su -s /bin/sh -c "$binary" tester >/tmp/tar.out 2>/tmp/tar.err
			rc=$?
			set -e
			test "$rc" -ne 0
			grep -q "Must be root" /tmp/tar.err
		'
}

main() {
	local channel
	local arch

	if [[ ! -d "${DIST_DIR}" ]]; then
		echo "Artifact directory not found: ${DIST_DIR}" >&2
		exit 1
	fi

	for channel in ${PACKAGE_TEST_CHANNELS}; do
		for arch in ${PACKAGE_TEST_ARCHES}; do
			run_deb_test debian "${channel}" "${arch}" \
				"debian:$([[ "${channel}" == stable ]] && echo stable || echo sid)"
			run_deb_test ubuntu "${channel}" "${arch}" \
				"ubuntu:$([[ "${channel}" == stable ]] && echo 24.04 || echo devel)"
		done

		if [[ " ${PACKAGE_TEST_ARCHES} " == *" amd64 "* ]]; then
			run_rpm_test "${channel}" amd64 \
				"fedora:$([[ "${channel}" == stable ]] && echo latest || echo rawhide)"
		fi
	done
}

main "$@"
