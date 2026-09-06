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

forbid_literal() {
	local path="$1"
	local needle="$2"

	if grep -Fq -- "${needle}" "${path}"; then
		echo "Unexpected text in ${path}: ${needle}" >&2
		exit 1
	fi
}

require_digest_ref() {
	local path="$1"
	local prefix="$2"

	if ! grep -Eq -- "${prefix}@sha256:[0-9a-f]{64}" "${path}"; then
		echo "Missing digest-pinned reference in ${path}: ${prefix}" >&2
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

# Every workflow must reference actions by immutable revision. The CodeQL
# workflow must also keep its init and analyze pair. Exact revisions live in
# the workflow files and move through dependabot review. The actionlint run
# uses an empty configuration so a repository ignore list cannot hide a
# duplicate key from the policy check.
workflow_count=0
while IFS= read -r workflow_path; do
	workflow_count=$((workflow_count + 1))
	actionlint -config-file /dev/null -shellcheck= -pyflakes= \
		"${workflow_path}" >/dev/null
	if [[ "${workflow_path}" == ".github/workflows/codeql.yml" ]]; then
		python3 -I "${SCRIPT_DIR}/check-workflow-action-policy.py" \
			--require-codeql-pair "${workflow_path}"
	else
		python3 -I "${SCRIPT_DIR}/check-workflow-action-policy.py" \
			"${workflow_path}"
	fi
done < <(
	find .github/workflows -maxdepth 1 -type f \
		\( -name '*.yml' -o -name '*.yaml' \) -print | sort
)

if [[ "${workflow_count}" -eq 0 ]]; then
	echo "No GitHub workflow files found" >&2
	exit 1
fi

require_literal "CONTRIBUTING.md" "\`v1.7.12\` or newer."
forbid_literal "CONTRIBUTING.md" "\`v1.7.10\` or newer."
require_literal "CONTRIBUTING.md" \
	"libusb-1.0-0-dev python3 python3-yaml shellcheck"
require_literal "CONTRIBUTING.md" "Use Python 3.10 or newer."
require_literal "CONTRIBUTING.md" \
	"Local checks support Bash 3.2 or newer."
require_literal "CONTRIBUTING.md" \
	"Release and package scripts require Bash 4.0 or newer."
forbid_literal "scripts/check-public-surface.sh" "mapfile -d '' repo_paths"
require_literal "scripts/check-public-surface.sh" \
	"while IFS= read -r -d '' path; do"

# shellcheck disable=SC1091
source "docker/release-builder.lock"

# The lock file is the single source of truth for the trusted builder
# runtime. The contract validates its shape and cross-file consistency.
if [[ ! "${DEBIAN_BASE_IMAGE}" =~ ^debian:trixie@sha256:[0-9a-f]{64}$ ||
      ! "${DEBIAN_SNAPSHOT_TIMESTAMP}" =~ ^[0-9]{8}T[0-9]{6}Z$ ||
      ! "${DEBIAN_SNAPSHOT_INRELEASE_SHA256}" =~ ^[0-9a-f]{64}$ ]]; then
	echo "The trusted builder runtime lock is not valid" >&2
	exit 1
fi

for path in \
	".github/workflows/build-test.yml" \
	".github/workflows/codeql.yml" \
	"docker/release-builder.Dockerfile"; do
	base_image_refs="$(
		grep -Eo 'debian:trixie@sha256:[0-9a-f]{64}' "${path}" | sort -u
	)"
	if [[ "${base_image_refs}" != "${DEBIAN_BASE_IMAGE}" ]]; then
		echo "Debian base image references in ${path} must match docker/release-builder.lock" >&2
		exit 1
	fi
done

require_literal ".github/workflows/security-baseline.yml" 'go-version: "1.27.1"'
require_literal ".github/workflows/security-baseline.yml" \
	"github.com/zricethezav/gitleaks/v8@v8.30.1"
require_literal "scripts/release-preflight.sh" \
	"zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f"
require_literal "scripts/release-preflight.sh" 'rev-list --count --all'
require_literal "scripts/release-preflight.sh" 'git_common_dir'
require_literal "scripts/release-preflight.sh" 'gitleaks_docker_args=('
require_literal "scripts/release-preflight.sh" 'preflight_docker_args=('
require_literal "scripts/release-preflight.sh" 'git -C /source rev-list --count --all'
require_literal "scripts/build-release-artifacts.sh" '--nodeps'
# shellcheck disable=SC2016
require_literal "scripts/build-release-artifacts.sh" '--dbpath "${rpm_root}/rpmdb"'
require_literal "scripts/build-release-artifacts.sh" \
	'build_mtime_policy clamp_to_source_date_epoch'
if grep -Fq -- 'clamp_mtime_to_source_date_epoch' \
	"scripts/build-release-artifacts.sh"; then
	echo "The RPM build must not use the deprecated clamp_mtime_to_source_date_epoch macro" >&2
	exit 1
fi
for path in \
	".github/workflows/release-builder.yml" \
	".github/workflows/release.yml"; do
	require_literal "${path}" 'version="v3.1.3"'
	require_literal "${path}" \
		'expected_sha256="4629c757b7618056f8ddd7e2625ae9fdd94c0372a65049520bc7d9df9efc7f71"'
done
require_literal ".github/workflows/release-builder.yml" "syft-version: v1.51.1"
require_literal "scripts/check-actionlint-version.py" "MINIMUM = (1, 7, 12)"

if grep -R -Fq -- "runs-on: ubuntu-latest" .github/workflows; then
	echo "GitHub-hosted jobs must use the explicit ubuntu-24.04 runtime" >&2
	exit 1
fi

require_digest_ref "scripts/test-package-integration.sh" "tonistiigi/binfmt"
require_digest_ref ".clusterfuzzlite/Dockerfile" \
	"gcr.io/oss-fuzz-base/base-builder:v1"

require_literal "scripts/test-package-integration.sh" \
	"RESETUSB_PACKAGE_TEST_TARGET=\"\${distro}/\${channel}/\${arch}\""
require_literal "scripts/test-package-integration.sh" \
	'ubuntu/unstable/armv7'
require_literal "scripts/test-package-integration.sh" 'gnu-coreutils'
require_literal "scripts/test-package-integration.sh" 'gnurm'
require_literal "scripts/test-package-integration.sh" \
	'apt-get install -y --no-install-recommends ca-certificates passwd'

# docker/package-test-images.lock is the single source of truth for the
# package test images. Every entry must stay digest-pinned; the exact
# digests move through the lock file alone.
package_image_count="$(
	grep -Ec -- '^[A-Z0-9_]+_IMAGE=[a-z0-9./_-]+(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$' \
		"docker/package-test-images.lock"
)"
if [[ "${package_image_count}" -ne 14 ]]; then
	echo "docker/package-test-images.lock must pin all 14 package test images by digest" >&2
	exit 1
fi
if grep -Evq -- '^(#|$|[A-Z0-9_]+_IMAGE=[a-z0-9./_-]+(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$)' \
	"docker/package-test-images.lock"; then
	echo "docker/package-test-images.lock contains an entry that is not digest-pinned" >&2
	exit 1
fi

while IFS= read -r runtime_statement; do
	require_literal "RUNTIMES.md" "${runtime_statement}"
done <<'EOF'
This document uses ASD-STE100 Simplified Technical English.
The program runs only on Linux.
The program must run as root.
Local checks support Bash 3.2 or newer.
Release and package scripts require Bash 4.0 or newer.
Repository checks require Python 3.10 or newer.
Repository security automation uses Go 1.27.1.
GitHub-hosted jobs use Ubuntu 24.04.
`make release-preflight` needs the Docker command and a Docker daemon.
The preflight accepts only an `amd64` or `arm64` Docker server.
The package tests use QEMU and `binfmt` for non-native containers.
The `binfmt` setup needs a privileged Docker container.
The package tests need network access to distribution package repositories.
Stable package tests use Debian 13, Ubuntu 24.04, and Fedora 44.
Unstable package tests use Debian `sid`, Ubuntu `devel`, and Fedora `rawhide`.
Debian and Ubuntu package tests use `amd64`, `arm64`, and `armv7` containers.
Fedora package tests use only an `amd64` container.
EOF

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
require_literal "Makefile" "actionlint"
require_literal "Makefile" 'scripts/check-actionlint-version.py'
require_literal "Makefile" "./scripts/check-public-surface.sh"
require_literal "Makefile" "./scripts/check-release-security-contract.sh"
require_literal "scripts/install-ci-deps.sh" "python3-yaml"
require_literal "scripts/release-preflight.sh" "make lint"
require_literal "scripts/release-preflight.sh" "python3-yaml"

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
