#!/usr/bin/env bash

set -euo pipefail

# Print the trusted builder base image.
#
# The FROM line in docker/release-builder.Dockerfile is the single source of
# truth for this image. Dependabot changes the digest only in that line, so
# no other file keeps a copy. The builder build script, the release
# manifest, and the release security contract read the image with this
# script.
#
# The Dockerfile must have exactly one FROM line, and that line must pin
# debian:trixie by a full sha256 digest. Any other form is an error.

REPO_ROOT="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd
)"
DOCKERFILE="${REPO_ROOT}/docker/release-builder.Dockerfile"

base_image="$(awk 'toupper($1) == "FROM" {print $2}' "${DOCKERFILE}")"

if [[ ! "${base_image}" =~ ^debian:trixie@sha256:[0-9a-f]{64}$ ]]; then
	echo "${DOCKERFILE} must have one FROM line that pins debian:trixie by sha256 digest" >&2
	exit 1
fi

printf '%s\n' "${base_image}"
