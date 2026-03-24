#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
BUILDER_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"
SOURCE_ROOT="${SOURCE_ROOT:-${BUILDER_ROOT}}"
export LC_ALL=C
export TZ=UTC
umask 022

resolve_source_date_epoch() {
	if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
		if [[ ! "${SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]]; then
			echo "SOURCE_DATE_EPOCH must be an integer" >&2
			exit 1
		fi
		printf '%s\n' "${SOURCE_DATE_EPOCH}"
		return
	fi

	if command -v git >/dev/null 2>&1 &&
		git -C "${SOURCE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "${SOURCE_ROOT}" log -1 --format=%ct HEAD
		return
	fi

	echo "SOURCE_DATE_EPOCH is required when git metadata is unavailable" >&2
	exit 1
}

resolve_short_sha() {
	if [[ -n "${GITHUB_SHA:-}" ]]; then
		printf '%s\n' "${GITHUB_SHA:0:12}"
		return
	fi

	if command -v git >/dev/null 2>&1 &&
		git -C "${SOURCE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "${SOURCE_ROOT}" rev-parse --short=12 HEAD
		return
	fi

	printf '%s\n' "unknown"
}

normalize_tree_timestamps() {
	local root="$1"

	while IFS= read -r -d '' path; do
		touch --no-dereference --date="@${SOURCE_DATE_EPOCH}" "${path}"
	done < <(find "${root}" -print0 | sort -z)
}

SOURCE_DATE_EPOCH="$(resolve_source_date_epoch)"
export SOURCE_DATE_EPOCH

SHORT_SHA="$(resolve_short_sha)"
REF_TYPE="${GITHUB_REF_TYPE:-}"
ARTIFACT_VERSION_OVERRIDE="${ARTIFACT_VERSION:-}"
PACKAGE_VERSION_OVERRIDE="${PACKAGE_VERSION:-}"
SEMVER_RELEASE_TAG_REGEX='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
PACKAGE_VERSION_REGEX='^[A-Za-z0-9.+~]+$'
MAINTAINER_REGEX='^[A-Za-z0-9][A-Za-z0-9 .,@_:+<>()-]*$'
HOMEPAGE_REGEX='^https?://[A-Za-z0-9./:@?&=%_+~-]+$'

if [[ $# -gt 0 ]]; then
	ARTIFACT_VERSION="$1"
elif [[ -n "${ARTIFACT_VERSION_OVERRIDE}" ]]; then
	ARTIFACT_VERSION="${ARTIFACT_VERSION_OVERRIDE}"
elif [[ -n "${GITHUB_REF_NAME:-}" && "${REF_TYPE}" == "tag" ]]; then
	ARTIFACT_VERSION="${GITHUB_REF_NAME}"
else
	ARTIFACT_VERSION="dev-${SHORT_SHA}"
fi

if [[ "${REF_TYPE}" == "tag" && ! "${ARTIFACT_VERSION}" =~ ${SEMVER_RELEASE_TAG_REGEX} ]]; then
	echo "Release tags must follow semver: vMAJOR.MINOR.PATCH" >&2
	exit 1
fi

if [[ "${ARTIFACT_VERSION}" == v* && ! "${ARTIFACT_VERSION}" =~ ${SEMVER_RELEASE_TAG_REGEX} ]]; then
	echo "Release-style artifact versions must follow semver: vMAJOR.MINOR.PATCH" >&2
	exit 1
fi

if [[ -n "${PACKAGE_VERSION_OVERRIDE}" ]]; then
	PACKAGE_VERSION="${PACKAGE_VERSION_OVERRIDE}"
elif [[ "${ARTIFACT_VERSION}" == v* ]]; then
	PACKAGE_VERSION="${ARTIFACT_VERSION#v}"
else
	PACKAGE_VERSION="0.0.0.git${SHORT_SHA}"
fi

DIST_DIR="${DIST_DIR:-${SOURCE_ROOT}/dist}"
WORK_DIR="${WORK_DIR:-${SOURCE_ROOT}/build/release}"
BIN_DIR="${WORK_DIR}/bin"
STAGE_DIR="${WORK_DIR}/stage"
MAINTAINER="${MAINTAINER:-resetusb maintainers <noreply@github.com>}"
HOMEPAGE="${HOMEPAGE:-https://github.com/omkhar/resetusb}"

declare -A ARCH_CC=(
	[amd64]="gcc"
	[arm64]="aarch64-linux-gnu-gcc"
	[armv7]="arm-linux-gnueabihf-gcc"
)

declare -A ARCH_TARBALL=(
	[amd64]="amd64"
	[arm64]="arm64"
	[armv7]="armv7"
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

declare -A ARCH_QEMU=(
	[arm64]="qemu-aarch64 -L /usr/aarch64-linux-gnu"
	[armv7]="qemu-arm -L /usr/arm-linux-gnueabihf"
)

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "$1 not found" >&2
		exit 1
	}
}

validate_single_line_value() {
	local name="$1"
	local value="$2"

	if [[ -z "${value}" ]]; then
		echo "${name} must not be empty" >&2
		exit 1
	fi

	if [[ "${value}" == *$'\n'* || "${value}" == *$'\r'* ]]; then
		echo "${name} must be a single line" >&2
		exit 1
	fi
}

validate_regex_value() {
	local name="$1"
	local value="$2"
	local pattern="$3"

	validate_single_line_value "${name}" "${value}"
	if [[ ! "${value}" =~ ${pattern} ]]; then
		echo "Unexpected ${name}: ${value}" >&2
		exit 1
	fi
}

validate_regex_value "PACKAGE_VERSION" "${PACKAGE_VERSION}" \
	"${PACKAGE_VERSION_REGEX}"
validate_regex_value "MAINTAINER" "${MAINTAINER}" "${MAINTAINER_REGEX}"
validate_regex_value "HOMEPAGE" "${HOMEPAGE}" "${HOMEPAGE_REGEX}"

expect_non_root_error() {
	local log_file="$1"
	shift
	local rc=0

	set +e
	if [[ "$(id -u)" -eq 0 ]]; then
		local non_root_user=""

		require_cmd runuser
		if id -u nobody >/dev/null 2>&1; then
			non_root_user="nobody"
		elif command -v getent >/dev/null 2>&1; then
			non_root_user="$(
				getent passwd | awk -F: '$3 > 0 {print $1; exit}'
			)"
		elif [[ -r /etc/passwd ]]; then
			non_root_user="$(
				awk -F: '$3 > 0 {print $1; exit}' /etc/passwd
			)"
		fi

		if [[ -z "${non_root_user}" ]]; then
			echo "Unable to find a non-root user for smoke test" >&2
			exit 1
		fi

		runuser -u "${non_root_user}" -- "$@" > /dev/null 2>"${log_file}"
	else
		"$@" > /dev/null 2>"${log_file}"
	fi
	rc=$?
	set -e

	if [[ ${rc} -eq 0 ]]; then
		echo "Expected non-zero exit for non-root invocation: $*" >&2
		exit 1
	fi

	grep -q "Must be root" "${log_file}"
}

run_binary_test() {
	local arch="$1"
	local test_bin="$2"
	local runtime_bin="$3"
	local qemu_prefix="${ARCH_QEMU[${arch}]:-}"
	local log_file="/tmp/resetusb-${arch}.log"

	if [[ -n "${qemu_prefix}" ]]; then
		read -r -a qemu_cmd <<< "${qemu_prefix}"
		"${qemu_cmd[@]}" "${test_bin}"
		expect_non_root_error "${log_file}" "${qemu_cmd[@]}" "${runtime_bin}"
	else
		make -C "${SOURCE_ROOT}" CC="${ARCH_CC[${arch}]}" test
		expect_non_root_error "${log_file}" "${runtime_bin}"
	fi
}

build_binary() {
	local arch="$1"
	local cc="${ARCH_CC[${arch}]}"
	local out_dir="${BIN_DIR}/${arch}"

	echo "==> Building and validating ${arch}"
	make -C "${SOURCE_ROOT}" clean

	if [[ "${arch}" == "amd64" ]]; then
		make -C "${SOURCE_ROOT}" CC="${cc}"
	else
		make -C "${SOURCE_ROOT}" CC="${cc}" resetusb-tests resetusb
	fi

	run_binary_test "${arch}" "${SOURCE_ROOT}/resetusb-tests" \
		"${SOURCE_ROOT}/resetusb"

	mkdir -p "${out_dir}"
	install -m 0755 "${SOURCE_ROOT}/resetusb" "${out_dir}/resetusb"
}

create_tarball() {
	local arch="$1"
	local stage_name="${ARTIFACT_VERSION}-linux-${ARCH_TARBALL[${arch}]}"
	local archive_path="${DIST_DIR}/resetusb-${ARTIFACT_VERSION}-linux-${ARCH_TARBALL[${arch}]}.tar.gz"
	local stage_path="${STAGE_DIR}/${stage_name}"

	rm -rf "${stage_path}"
	mkdir -p "${stage_path}"

	install -m 0755 "${BIN_DIR}/${arch}/resetusb" "${stage_path}/resetusb"
	install -m 0644 "${SOURCE_ROOT}/resetusb.8" "${stage_path}/resetusb.8"
	install -m 0644 "${SOURCE_ROOT}/README.md" "${stage_path}/README.md"
	install -m 0644 "${SOURCE_ROOT}/LICENSE" "${stage_path}/LICENSE"

	normalize_tree_timestamps "${stage_path}"
	(
		cd "${STAGE_DIR}"
		tar --sort=name --format=gnu \
			--mtime="@${SOURCE_DATE_EPOCH}" \
			--owner=0 --group=0 --numeric-owner \
			-cf - "${stage_name}" | gzip -n > "${archive_path}"
	)
}

create_deb_package() {
	local distro="$1"
	local arch="$2"
	local deb_arch="${ARCH_DEB[${arch}]}"
	local artifact="${DIST_DIR}/resetusb-${ARTIFACT_VERSION}-${distro}-${deb_arch}.deb"
	local pkg_root

	pkg_root="$(mktemp -d)"
	mkdir -p "${pkg_root}/DEBIAN" \
		"${pkg_root}/usr/sbin" \
		"${pkg_root}/usr/share/man/man8" \
		"${pkg_root}/usr/share/doc/resetusb"

	install -m 0755 "${BIN_DIR}/${arch}/resetusb" \
		"${pkg_root}/usr/sbin/resetusb"
	install -m 0644 "${SOURCE_ROOT}/README.md" \
		"${pkg_root}/usr/share/doc/resetusb/README.md"
	install -m 0644 "${SOURCE_ROOT}/LICENSE" \
		"${pkg_root}/usr/share/doc/resetusb/LICENSE"
	install -m 0644 "${SOURCE_ROOT}/resetusb.8" \
		"${pkg_root}/usr/share/man/man8/resetusb.8"

	cat >"${pkg_root}/DEBIAN/control" <<EOF
Package: resetusb
Version: ${PACKAGE_VERSION}
Section: admin
Priority: optional
Architecture: ${deb_arch}
Maintainer: ${MAINTAINER}
Depends: libusb-1.0-0
Homepage: ${HOMEPAGE}
Description: Reset enumerated USB devices from Linux
 resetusb enumerates USB devices and issues resets for operational recovery
 workflows. It requires root privileges and should only be used during
 controlled maintenance windows.
EOF

	normalize_tree_timestamps "${pkg_root}"
	dpkg-deb --build --root-owner-group "${pkg_root}" "${artifact}" >/dev/null
	rm -rf "${pkg_root}"
}

create_rpm_package() {
	local arch="$1"
	local rpm_arch="${ARCH_RPM[${arch}]}"
	local rpm_root
	local spec_path
	local built_rpm
	local -a built_rpms=()
	local artifact="${DIST_DIR}/resetusb-${ARTIFACT_VERSION}-fedora-${rpm_arch}.rpm"

	rpm_root="$(mktemp -d)"
	mkdir -p "${rpm_root}/BUILD" "${rpm_root}/BUILDROOT" \
		"${rpm_root}/RPMS" "${rpm_root}/SOURCES" "${rpm_root}/SPECS" \
		"${rpm_root}/SRPMS"

	install -m 0755 "${BIN_DIR}/${arch}/resetusb" \
		"${rpm_root}/SOURCES/resetusb"
	install -m 0644 "${SOURCE_ROOT}/README.md" \
		"${rpm_root}/SOURCES/README.md"
	install -m 0644 "${SOURCE_ROOT}/LICENSE" \
		"${rpm_root}/SOURCES/LICENSE"
	install -m 0644 "${SOURCE_ROOT}/resetusb.8" \
		"${rpm_root}/SOURCES/resetusb.8"

	spec_path="${rpm_root}/SPECS/resetusb.spec"
	cat >"${spec_path}" <<EOF
Name: resetusb
Version: ${PACKAGE_VERSION}
Release: 1
Summary: Reset enumerated USB devices from Linux
License: Apache-2.0
URL: ${HOMEPAGE}
Requires: libusb1
Source0: resetusb
Source1: README.md
Source2: LICENSE
Source3: resetusb.8

%description
resetusb enumerates USB devices and issues resets for operational recovery
workflows. It requires root privileges and should only be used during
controlled maintenance windows.

%prep

%build

%install
install -D -m 0755 %{SOURCE0} %{buildroot}%{_sbindir}/resetusb
install -D -m 0644 %{SOURCE1} %{buildroot}%{_docdir}/resetusb/README.md
install -D -m 0644 %{SOURCE2} %{buildroot}%{_licensedir}/resetusb/LICENSE
install -D -m 0644 %{SOURCE3} %{buildroot}%{_mandir}/man8/resetusb.8

%files
%license %{_licensedir}/resetusb/LICENSE
%doc %{_docdir}/resetusb/README.md
%{_mandir}/man8/resetusb.8*
%attr(0755,root,root) %{_sbindir}/resetusb
EOF

	normalize_tree_timestamps "${rpm_root}"
	rpmbuild --quiet \
		--define "_topdir ${rpm_root}" \
		--define "_buildhost reproducible" \
		--define "_source_date_epoch ${SOURCE_DATE_EPOCH}" \
		--define "clamp_mtime_to_source_date_epoch 1" \
		--define "use_source_date_epoch_as_buildtime 1" \
		--target "${rpm_arch}" \
		-bb "${spec_path}"

	mapfile -t built_rpms < <(
		find "${rpm_root}/RPMS" -type f -name '*.rpm' | sort
	)
	if [[ ${#built_rpms[@]} -eq 0 ]]; then
		echo "rpmbuild produced no RPM output for ${arch}" >&2
		exit 1
	fi
	if [[ ${#built_rpms[@]} -ne 1 ]]; then
		printf 'Expected exactly one RPM for %s, found: %s\n' \
			"${arch}" "${built_rpms[*]}" >&2
		exit 1
	fi
	built_rpm="${built_rpms[0]}"
	install -m 0644 "${built_rpm}" "${artifact}"
	rm -rf "${rpm_root}"
}

write_checksums() {
	local artifact

	shopt -s nullglob
	for artifact in "${DIST_DIR}"/*; do
		if [[ ! -f "${artifact}" || "${artifact}" == *.sha256 ]]; then
			continue
		fi
		(
			cd "${DIST_DIR}"
			sha256sum "$(basename "${artifact}")" > "$(basename "${artifact}").sha256"
		)
	done
	shopt -u nullglob
}

main() {
	require_cmd dpkg-deb
	require_cmd gzip
	require_cmd make
	require_cmd rpmbuild
	require_cmd sha256sum
	require_cmd tar

	rm -rf "${DIST_DIR}" "${WORK_DIR}"
	mkdir -p "${DIST_DIR}" "${BIN_DIR}" "${STAGE_DIR}"

	build_binary amd64
	build_binary arm64
	build_binary armv7

	create_tarball amd64
	create_tarball arm64
	create_tarball armv7

	create_deb_package debian amd64
	create_deb_package debian arm64
	create_deb_package debian armv7
	create_deb_package ubuntu amd64
	create_deb_package ubuntu arm64
	create_deb_package ubuntu armv7

	create_rpm_package amd64

	write_checksums

	echo "==> Release artifacts written to ${DIST_DIR}"
	find "${DIST_DIR}" -maxdepth 1 -type f -print | sort
}

main "$@"
