#!/usr/bin/env bash

set -euo pipefail

actionlint_version="1.7.12"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

case "$(uname -m)" in
	x86_64|amd64)
		actionlint_platform="linux_amd64"
		actionlint_sha256="8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"
		;;
	aarch64|arm64)
		actionlint_platform="linux_arm64"
		actionlint_sha256="325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6"
		;;
	*)
		echo "Unsupported architecture for actionlint: $(uname -m)" >&2
		exit 1
		;;
esac

actionlint_archive="actionlint_${actionlint_version}_${actionlint_platform}.tar.gz"
actionlint_url="https://github.com/rhysd/actionlint/releases/download/v${actionlint_version}/${actionlint_archive}"

curl --fail --silent --show-error --location \
	--retry 5 --retry-delay 2 --retry-all-errors \
	-o "${tmpdir}/${actionlint_archive}" "${actionlint_url}"
printf '%s  %s\n' "${actionlint_sha256}" "${tmpdir}/${actionlint_archive}" \
	| sha256sum --check --strict
tar -xzf "${tmpdir}/${actionlint_archive}" -C "${tmpdir}"
install -m 0755 "${tmpdir}/actionlint" /usr/local/bin/actionlint
