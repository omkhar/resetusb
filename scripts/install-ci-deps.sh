#!/usr/bin/env bash

set -euo pipefail

profile="${1:-}"

if [[ -z "${profile}" ]]; then
	echo "Usage: $0 <profile>" >&2
	exit 1
fi

case "${profile}" in
static-analysis)
	packages=(
		build-essential
		clang
		clang-format
		clang-tools
		cppcheck
		curl
		libusb-1.0-0-dev
		python3
		shellcheck
	)
	;;
unit-tests)
	packages=(
		build-essential
		clang
		libusb-1.0-0-dev
	)
	;;
sanitize)
	packages=(
		build-essential
		libusb-1.0-0-dev
	)
	;;
codeql-c-cpp)
	packages=(
		build-essential
		libusb-1.0-0-dev
	)
	;;
*)
	echo "Unknown CI dependency profile: ${profile}" >&2
	exit 1
	;;
esac

apt-get install -y --no-install-recommends "${packages[@]}"

if [[ "${profile}" == "static-analysis" ]]; then
	actionlint_version="1.7.12"
	actionlint_archive="actionlint_${actionlint_version}_linux_amd64.tar.gz"
	actionlint_url="https://github.com/rhysd/actionlint/releases/download/v${actionlint_version}/${actionlint_archive}"
	actionlint_sha256="8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"
	tmpdir="$(mktemp -d)"
	trap 'rm -rf "${tmpdir}"' EXIT

	curl -fsSL -o "${tmpdir}/${actionlint_archive}" "${actionlint_url}"
	printf '%s  %s\n' "${actionlint_sha256}" "${tmpdir}/${actionlint_archive}" \
		| sha256sum --check --strict
	tar -xzf "${tmpdir}/${actionlint_archive}" -C "${tmpdir}"
	install -m 0755 "${tmpdir}/actionlint" /usr/local/bin/actionlint
fi
