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
		ca-certificates
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
	./scripts/install-actionlint.sh
fi
