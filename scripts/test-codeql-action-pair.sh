#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
CHECKER="${SCRIPT_DIR}/check-codeql-action-pair.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
	rm -rf "${TMP_DIR}"
}
trap cleanup EXIT INT TERM

sha_one="99df26d4f13ea111d4ec1a7dddef6063f76b97e9"
sha_two="8aad20d150bbac5944a9f9d289da16a4b0d87c1e"

expect_pass() {
	local name="$1"
	local path="$2"

	if ! "${CHECKER}" "${path}"; then
		echo "Expected ${name} to pass" >&2
		exit 1
	fi
}

expect_fail() {
	local name="$1"
	local path="$2"

	if "${CHECKER}" "${path}" >/dev/null 2>&1; then
		echo "Expected ${name} to fail" >&2
		exit 1
	fi
}

valid="${TMP_DIR}/valid.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	"run: go build ./..." \
	"uses: github/codeql-action/analyze@${sha_one}" >"${valid}"
expect_pass "one ordered matching pair" "${valid}"

missing="${TMP_DIR}/missing.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" >"${missing}"
expect_fail "a missing analyze phase" "${missing}"

commented="${TMP_DIR}/commented.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	"# uses: github/codeql-action/analyze@${sha_one}" >"${commented}"
expect_fail "a commented analyze phase" "${commented}"

duplicate="${TMP_DIR}/duplicate.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}" >"${duplicate}"
expect_fail "a duplicate init phase" "${duplicate}"

swapped="${TMP_DIR}/swapped.yml"
printf '%s\n' \
	"uses: github/codeql-action/analyze@${sha_one}" \
	"run: go build ./..." \
	"uses: github/codeql-action/init@${sha_one}" >"${swapped}"
expect_fail "swapped phases" "${swapped}"

mismatch="${TMP_DIR}/mismatch.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_two}" >"${mismatch}"
expect_fail "different immutable revisions" "${mismatch}"
