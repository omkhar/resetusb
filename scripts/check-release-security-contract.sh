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

require_action_pin() {
	local action="$1"
	local expected_sha="$2"
	local expected_version="$3"
	local expected="uses: ${action}@${expected_sha} # ${expected_version}"
	local path
	local -a workflow_files=()

	while IFS= read -r path; do
		workflow_files+=("${path}")
	done < <(
		find .github/workflows -maxdepth 1 -type f \
			\( -name '*.yml' -o -name '*.yaml' \) -print | sort
	)

	if [[ ${#workflow_files[@]} -eq 0 ]]; then
		echo "No GitHub workflow files found" >&2
		exit 1
	fi

	if ! awk \
		-v needle="uses: ${action}@" \
		-v expected="${expected}" '
		index($0, needle) {
			found = 1
			actual = $0
			sub(/^[[:space:]]*-?[[:space:]]*/, "", actual)
			if (actual != expected) {
				printf "%s:%d: expected %s, got %s\n", \
					FILENAME, FNR, expected, actual > "/dev/stderr"
				bad = 1
			}
		}
		END {
			if (!found) {
				printf "No workflow uses %s\n", needle > "/dev/stderr"
			}
			exit(bad || !found ? 1 : 0)
		}
	' "${workflow_files[@]}"; then
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

while IFS='|' read -r action expected_sha expected_version; do
	require_action_pin "${action}" "${expected_sha}" "${expected_version}"
done <<'EOF'
actions/checkout|3d3c42e5aac5ba805825da76410c181273ba90b1|v7.0.1
actions/setup-go|b7ad1dad31e06c5925ef5d2fc7ad053ef454303e|v7.0.0
actions/upload-artifact|043fb46d1a93c77aae656e7c1c64a875d1fc6a0a|v7.0.1
actions/download-artifact|3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c|v8.0.1
actions/attest|f7c74d28b9d84cb8768d0b8ca14a4bac6ef463e6|v4.2.0
github/codeql-action/init|e4fba868fa4b1b91e1fdab776edc8cfbe6e9fb81|v4.37.3
github/codeql-action/analyze|e4fba868fa4b1b91e1fdab776edc8cfbe6e9fb81|v4.37.3
github/codeql-action/upload-sarif|e4fba868fa4b1b91e1fdab776edc8cfbe6e9fb81|v4.37.3
actions/dependency-review-action|a1d282b36b6f3519aa1f3fc636f609c47dddb294|v5.0.0
docker/setup-qemu-action|96fe6ef7f33517b61c61be40b68a1882f3264fb8|v4.2.0
anchore/sbom-action/download-syft|e22c389904149dbc22b58101806040fa8d37a610|v0.24.0
ossf/scorecard-action|4eaacf0543bb3f2c246792bd56e8cdeffafb205a|v2.4.3
zizmorcore/zizmor-action|6599ee8b7a49aef6a770f63d261d214911a7ce02|v0.6.0
google/clusterfuzzlite/actions/build_fuzzers|884713a6c30a92e5e8544c39945cd7cb630abcd1|v1
google/clusterfuzzlite/actions/run_fuzzers|884713a6c30a92e5e8544c39945cd7cb630abcd1|v1
EOF

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

expected_base_image="debian:trixie@sha256:fac46bff2e02f51425b6e33b0e1169f55dfb053d83511ca28aa50c09fd5ed7a4"
expected_snapshot_timestamp="20260721T000000Z"
expected_snapshot_inrelease_sha256="98b25b5cd185c59d34aa6e4c3e9b5b8f01bbe9d104fe2dcfbcd30dc0a14a59ed"

if [[ "${DEBIAN_BASE_IMAGE}" != "${expected_base_image}" ||
      "${DEBIAN_SNAPSHOT_TIMESTAMP}" != "${expected_snapshot_timestamp}" ||
      "${DEBIAN_SNAPSHOT_INRELEASE_SHA256}" != "${expected_snapshot_inrelease_sha256}" ]]; then
	echo "The trusted builder runtime lock is not current" >&2
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

require_literal ".github/workflows/security-baseline.yml" \
	"actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e # v7.0.0"
require_literal ".github/workflows/security-baseline.yml" 'go-version: "1.26.5"'
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
	require_literal "${path}" 'version="v3.1.2"'
	require_literal "${path}" \
		'expected_sha256="f7622ed3cf22e55e1ae6377c080979ff77a22da9981c11df222a2e444991e7cf"'
done
require_literal ".github/workflows/release-builder.yml" "syft-version: v1.49.0"
require_literal "scripts/check-actionlint-version.py" "MINIMUM = (1, 7, 12)"

if grep -R -Fq -- "runs-on: ubuntu-latest" .github/workflows; then
	echo "GitHub-hosted jobs must use the explicit ubuntu-24.04 runtime" >&2
	exit 1
fi

require_literal "scripts/test-package-integration.sh" \
	"tonistiigi/binfmt@sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0"
forbid_literal "scripts/test-package-integration.sh" \
	"tonistiigi/binfmt@sha256:d3b963f787999e6c0219a48dba02978769286ff61a5f4d26245cb6a6e5567ea3"
require_literal ".clusterfuzzlite/Dockerfile" \
	"gcr.io/oss-fuzz-base/base-builder:v1@sha256:5d16653db7d96570d09b91e022867a0ff6fa32826fd5f3f0625e5afa61157414"
forbid_literal ".clusterfuzzlite/Dockerfile" \
	"gcr.io/oss-fuzz-base/base-builder:v1@sha256:cc6982a6ce8b02c80a2acabbcfe766e5e7200988ff0424b0d4963232c3b41901"

require_literal "scripts/test-package-integration.sh" \
	"RESETUSB_PACKAGE_TEST_TARGET=\"\${distro}/\${channel}/\${arch}\""
require_literal "scripts/test-package-integration.sh" \
	'ubuntu/unstable/armv7'
require_literal "scripts/test-package-integration.sh" 'gnu-coreutils'
require_literal "scripts/test-package-integration.sh" 'gnurm'
require_literal "scripts/test-package-integration.sh" \
	'apt-get install -y --no-install-recommends ca-certificates passwd'

while IFS= read -r image; do
	require_literal "docker/package-test-images.lock" "${image}"
done <<'EOF'
debian:trixie@sha256:d63a99144861e4e460196ed93d07777490cbeab53ca660c434f2a589a6c50ea3
debian:trixie@sha256:8ac748152418b19ff289badbf878c42561c5b0cd922ade5fe4fa37cf0769b521
debian:trixie@sha256:743aca1ad24c5e48132df88f561f8d1365bfb6da33e006eb44b44fe32a7a30eb
debian:sid@sha256:2c9866a63b63e4ebafaf913f97c7c6548c3b578b9a4279f101c2ef04738d0aeb
debian:sid@sha256:e0978e3b598df62ce058da98d55bd5b34de32b6d18536fa227acfd915a7b4823
debian:sid@sha256:b2a5fd5dd970285660fab5570f252cfcb61a9f94506571f0e84c29a029678c68
ubuntu:24.04@sha256:52df9b1ee71626e0088f7d400d5c6b5f7bb916f8f0c82b474289a4ece6cf3faf
ubuntu:24.04@sha256:7f622ca8766bccb22f04242ecb6f19f770b2f08827dc4b8c707de5e78a6da7ab
ubuntu:24.04@sha256:85bd033654caaaa96ca01bd334ff21fb21d38e29b563ea8ab527bb61ea3a2307
ubuntu:devel@sha256:bb545a234ade8e929bf1f12d475d3472c4ed221e1f1c0a0c7ba8165b64da7729
ubuntu:devel@sha256:d206b9277d9b8fab7fdefa816b4a6e290d57c9e98e82a00474cb8a1f806cb9e1
ubuntu:devel@sha256:394966275ff5e8a815d8455a2db135e953574ff05acf4ffaa3c3ee7b6f99afad
fedora:44@sha256:89f61a124414261868224666aa7fb8df1b78397a53623774bdfb105d1612b48b
fedora:rawhide@sha256:ea5726b9c7d8f7c5a7826f196b93adc4e2e2bb6b0c707f3857104642bf34b4f3
EOF

while IFS= read -r runtime_statement; do
	require_literal "RUNTIMES.md" "${runtime_statement}"
done <<'EOF'
This document uses ASD-STE100 Simplified Technical English.
The program runs only on Linux.
The program must run as root.
Local checks support Bash 3.2 or newer.
Release and package scripts require Bash 4.0 or newer.
Repository checks require Python 3.10 or newer.
Repository security automation uses Go 1.26.5.
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
require_literal "Makefile" 'scripts/render-agent-control-plane.py --check'
require_literal "scripts/install-ci-deps.sh" "python3-yaml"
require_literal "scripts/release-preflight.sh" "make lint"
require_literal "scripts/release-preflight.sh" "python3-yaml"

"${SCRIPT_DIR}/check-codeql-action-pair.sh" ".github/workflows/codeql.yml"

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
