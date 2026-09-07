#!/usr/bin/env bash

set -euo pipefail

require_text() {
	local file="$1"
	local text="$2"

	if ! grep -Fq -- "${text}" "${file}"; then
		echo "${file} must contain: ${text}" >&2
		exit 1
	fi
}

reject_text() {
	local file="$1"
	local text="$2"

	if grep -Fq -- "${text}" "${file}"; then
		echo "${file} must not contain: ${text}" >&2
		exit 1
	fi
}

compare_inventory() {
	local name="$1"
	local source_inventory="$2"
	local documented_inventory="$3"

	if [[ "${source_inventory}" == "${documented_inventory}" ]]; then
		return
	fi

	echo "FUNCTIONS.md ${name} inventory differs from the source" >&2
	diff -u <(printf '%s\n' "${source_inventory}") \
		<(printf '%s\n' "${documented_inventory}") >&2 || true
	exit 1
}

cd "$(git rev-parse --show-toplevel)"
markdown_code_delimiter="$(printf '\140')"

require_text scripts/build-release-artifacts.sh 'expect_non_root_error() {'
if SOURCE_ROOT="${PWD}" TMPDIR="${PWD}/tests" DIST_DIR="${PWD}/tests" \
	bash <(sed '/^expect_non_root_error()/,$d' scripts/build-release-artifacts.sh) \
	>/dev/null 2>&1; then
	echo "DIST_DIR must not equal a nested TMPDIR root" >&2
	exit 1
fi

for file in README.md RUNTIMES.md LIMITATIONS.md FUNCTIONS.md resetusb.8; do
	require_text "${file}" "ASD-STE100 Simplified Technical English"
done

for text in \
	"asks ${markdown_code_delimiter}libusb${markdown_code_delimiter} to do a USB port reset" \
	"If ${markdown_code_delimiter}libusb${markdown_code_delimiter} requires re-enumeration, ${markdown_code_delimiter}resetusb${markdown_code_delimiter} records a failure and does not rediscover the device" \
	"attempts a reset only after it reads a descriptor and opens a non-null handle" \
	"The device list can include hubs" \
	"ignores all command-line arguments" \
	"${markdown_code_delimiter}--help${markdown_code_delimiter} does not show help" \
	"continues with the next device" \
	"LIMITATIONS.md" \
	"RUNTIMES.md" \
	"FUNCTIONS.md" \
	"Generic archives and distribution packages include these documents"; do
	require_text README.md "${text}"
done

reject_text README.md "A reset asks Linux to enumerate the device again."
reject_text README.md "attempts to reset every enumerated USB device"
reject_text README.md "every enumerated USB device it can open"

for text in \
	"records this condition as a failure. It does not rediscover the device" \
	"attempts a reset only after it reads a device descriptor and opens a non-null handle" \
	"does not provide a dry-run mode" \
	"does not ask for confirmation" \
	"does not retry a reset" \
	"does not roll back a reset" \
	"does not quiesce drivers or file systems" \
	"does not reset devices concurrently" \
	"does not guarantee a stable device order" \
	"has no reset timeout or cancellation control" \
	"does not explicitly detach or attach kernel drivers" \
	"does not guarantee that a device will recover" \
	"${markdown_code_delimiter}<unknown>${markdown_code_delimiter}" \
	"${markdown_code_delimiter}<string unavailable>${markdown_code_delimiter}" \
	"internal test seam" \
	"returns 1 without output when an output stream pointer is null" \
	"requires a complete operations table and does not validate it" \
	"Exit status 0 requires successful initialization, enumeration, and all device-specific operations" \
	"A descriptor, open, null-handle, or reset failure causes exit status 1" \
	"does not install ${markdown_code_delimiter}resetusb.h${markdown_code_delimiter}"; do
	require_text LIMITATIONS.md "${text}"
done

reject_text LIMITATIONS.md \
	"attempts to reset each device that ${markdown_code_delimiter}libusb${markdown_code_delimiter} enumerates"
reject_text LIMITATIONS.md \
	"Exit status 0 means that initialization, enumeration, and all attempted resets succeeded"

runtime_blob_hash_pattern='hash-object '
runtime_blob_hash_pattern+='RUNTIMES.md'
reject_text scripts/check-documentation-contract.sh \
	"${runtime_blob_hash_pattern}"

for text in \
	"attempt resets for enumerated USB devices on Linux" \
	"asks libusb to do a USB port reset" \
	"If libusb requires re-enumeration, resetusb records a failure and does not" \
	"attempts a reset only after it reads a device descriptor and opens a non-null handle" \
	"can attempt a reset for each device that it opens" \
	"ignores all command-line arguments" \
	"does not show help" \
	"continues with the next device" \
	"null device entry" \
	"descriptor failure" \
	"open failure" \
	"null-handle failure" \
	"Privilege failures do not contain device fields" \
	"Initialization and enumeration failures do not contain device fields" \
	"returns 1"; do
	require_text resetusb.8 "${text}"
done

reject_text resetusb.8 "A reset asks the kernel to probe the device again."
reject_text resetusb.8 "reset all enumerated USB devices on Linux"
reject_text resetusb.8 "It attempts to reset every enumerated USB device"
reject_text resetusb.8 "resets every enumerated USB device"

for document in FUNCTIONS.md LIMITATIONS.md README.md RUNTIMES.md; do
	require_text scripts/build-release-artifacts.sh "${document}"
	require_text scripts/test-package-integration.sh "${document}"
done

source_c_functions="$({
	sed -nE 's/^(static[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*[[:space:]*]+)+([A-Za-z_][A-Za-z0-9_]*)\(.*/\3/p' resetusb.c
} | LC_ALL=C sort)"
documented_c_functions="$({
	sed -n '/^## C program$/,/^## Python automation$/p' FUNCTIONS.md |
		sed -nE "s/^\\| ${markdown_code_delimiter}([A-Za-z_][A-Za-z0-9_]*)${markdown_code_delimiter} \\|.*$/\\1/p"
} | LC_ALL=C sort)"

workflow_files=()
while IFS= read -r file; do
	workflow_files+=("${file}")
done < <(
	find .github/workflows -maxdepth 1 -type f \
		\( -name '*.yml' -o -name '*.yaml' \) -print | LC_ALL=C sort
)

source_python_functions="$({
	for file in scripts/*.py "${workflow_files[@]}"; do
		base="${file##*/}"
		sed -nE "s/^[[:space:]]*def ([A-Za-z_][A-Za-z0-9_]*)\\(.*/${base}: \\1/p" "${file}"
	done
} | LC_ALL=C sort)"
documented_python_functions="$({
	sed -n '/^## Python automation$/,/^## Shell automation$/p' FUNCTIONS.md |
		sed -nE "s/^\\| ${markdown_code_delimiter}([^${markdown_code_delimiter}]+: [A-Za-z_][A-Za-z0-9_]*)${markdown_code_delimiter} \\|.*$/\\1/p"
} | LC_ALL=C sort)"

source_shell_functions="$({
	for file in scripts/*.sh "${workflow_files[@]}"; do
		base="${file##*/}"
		sed -nE "s/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)\\(\\)[[:space:]]*\\{.*/${base}: \\1/p" "${file}"
	done
} | LC_ALL=C sort)"
documented_shell_functions="$({
	sed -n '/^## Shell automation$/,$p' FUNCTIONS.md |
		sed -nE "s/^\\| ${markdown_code_delimiter}([^${markdown_code_delimiter}]+: [A-Za-z_][A-Za-z0-9_]*)${markdown_code_delimiter} \\|.*$/\\1/p"
} | LC_ALL=C sort)"

compare_inventory "C function" "${source_c_functions}" \
	"${documented_c_functions}"
compare_inventory "Python function" "${source_python_functions}" \
	"${documented_python_functions}"
compare_inventory "shell function" "${source_shell_functions}" \
	"${documented_shell_functions}"

require_text FUNCTIONS.md \
	"${markdown_code_delimiter}release-builder.yml: load_builder_lock${markdown_code_delimiter}"
require_text FUNCTIONS.md \
	"Allows only a descendant of the source root, ${markdown_code_delimiter}TMPDIR${markdown_code_delimiter}, or ${markdown_code_delimiter}/tmp${markdown_code_delimiter}. Rejects each root itself."
reject_text FUNCTIONS.md "Requires the path below an approved private root."
require_text resetusb.c "int main(void)"
reject_text resetusb.c "argc"
reject_text resetusb.c "argv"
reject_text Makefile "install -Dm644 resetusb.h"
