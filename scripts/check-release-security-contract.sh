#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
REPO_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"

require_literal() {
	local path="$1"
	local needle="$2"

	if ! grep -Fq -- "${needle}" "${path}"; then
		echo "Missing expected text in ${path}: ${needle}" >&2
		exit 1
	fi
}

require_literal_after() {
	local path="$1"
	local marker="$2"
	local needle="$3"
	local max_lines="${4:-80}"

	if ! awk \
		-v marker="${marker}" \
		-v needle="${needle}" \
		-v max_lines="${max_lines}" '
		index($0, marker) {
			window = max_lines
		}
		window > 0 && index($0, needle) {
			found = 1
			exit
		}
		window > 0 {
			window--
		}
		END {
			exit(found ? 0 : 1)
		}
	' "${path}"; then
		echo "Missing expected text after marker in ${path}: ${marker} -> ${needle}" >&2
		exit 1
	fi
}

cd "${REPO_ROOT}"

require_literal "docker/release-builder.lock" "DEBIAN_SNAPSHOT_INRELEASE_SHA256="

# shellcheck disable=SC2016
snapshot_sha_check='echo "${DEBIAN_SNAPSHOT_INRELEASE_SHA256}  ${snapshot_inrelease}" | sha256sum --check --strict'

for path in \
	".github/workflows/build-test.yml" \
	".github/workflows/codeql.yml" \
	"docker/release-builder.Dockerfile" \
	"scripts/release-preflight.sh"; do
	require_literal "${path}" "DEBIAN_SNAPSHOT_INRELEASE_SHA256"
	require_literal "${path}" "sha256sum --check --strict"
done

require_literal_after \
	".github/workflows/build-test.yml" \
	"name: static-analysis" \
	"${snapshot_sha_check}"
require_literal_after \
	".github/workflows/build-test.yml" \
	"unit-tests:" \
	"${snapshot_sha_check}"
require_literal_after \
	".github/workflows/build-test.yml" \
	"name: sanitize" \
	"${snapshot_sha_check}"
require_literal_after \
	".github/workflows/build-test.yml" \
	"name: Run lint, format, and clang static analysis" \
	"make lint"

# shellcheck disable=SC2016
require_literal ".github/workflows/release.yml" 'if [[ "${REF_TYPE}" != "tag" ]]; then'
# shellcheck disable=SC2016
require_literal ".github/workflows/release.yml" 'if [[ "${WORKFLOW_SHA}" != "${source_digest}" ]]; then'
# shellcheck disable=SC2016
require_literal ".github/workflows/release.yml" 'builder_sha="${source_digest}"'
require_literal ".github/workflows/release-builder.yml" "@refs/tags/"
require_literal ".github/workflows/release-builder.yml" '"debian_snapshot_inrelease_sha256": builder_lock["DEBIAN_SNAPSHOT_INRELEASE_SHA256"]'
require_literal "scripts/validate-release-manifest.py" "@refs/tags/{workflow_tag}"
require_literal "scripts/validate-release-manifest.py" "debian_snapshot_inrelease_sha256"
require_literal "release-manifest.schema.json" '"const": 3'
require_literal "release-manifest.schema.json" '@refs/tags/v('
