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
		libusb-1.0-0-dev
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
