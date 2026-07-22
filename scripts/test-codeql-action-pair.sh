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

write_analyze_inputs() {
	local path="$1" skip_queries="$2" upload="$3"
	printf '%s\n' \
		"jobs:" \
		"  analyze:" \
		"    runs-on: ubuntu-24.04" \
		"    steps:" \
		"      - uses: github/codeql-action/init@${sha_one}" \
		"      - uses: github/codeql-action/analyze@${sha_one}" \
		"        with:" \
		"          skip-queries: ${skip_queries}" \
		"          upload: ${upload}" >"${path}"
}

valid="${TMP_DIR}/valid.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: actions/checkout@${sha_two}" \
	"      - uses: github/codeql-action/init@${sha_one} # v4.37.0" \
	"      - run: go build ./..." \
	"      - uses: 'github/codeql-action/analyze@${sha_one}'" >"${valid}"
expect_pass "one ordered matching executable pair" "${valid}"

missing="${TMP_DIR}/missing.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" >"${missing}"
expect_fail "a missing analyze phase" "${missing}"

duplicate="${TMP_DIR}/duplicate.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${duplicate}"
expect_fail "a duplicate init phase" "${duplicate}"

swapped="${TMP_DIR}/swapped.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/analyze@${sha_one}" \
	"      - run: go build ./..." \
	"      - uses: github/codeql-action/init@${sha_one}" >"${swapped}"
expect_fail "swapped phases" "${swapped}"

mismatch="${TMP_DIR}/mismatch.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_two}" >"${mismatch}"
expect_fail "different immutable revisions" "${mismatch}"

run_scalar="${TMP_DIR}/run-scalar.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - name: Print text" \
	"        run: |" \
	"          uses: github/codeql-action/init@${sha_one}" \
	"          uses: github/codeql-action/analyze@${sha_one}" >"${run_scalar}"
expect_fail "CodeQL-looking text in a run block" "${run_scalar}"

suffixed_ref="${TMP_DIR}/suffixed-ref.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}-not-immutable" \
	"      - uses: github/codeql-action/analyze@${sha_one}-not-immutable" >"${suffixed_ref}"
expect_fail "immutable revisions with suffixes" "${suffixed_ref}"

separate_jobs="${TMP_DIR}/separate-jobs.yml"
printf '%s\n' \
	"jobs:" \
	"  initialize:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${separate_jobs}"
expect_fail "phases in separate jobs" "${separate_jobs}"

outside_steps="${TMP_DIR}/outside-steps.yml"
printf '%s\n' \
	"env:" \
	"  INIT_TEXT: uses: github/codeql-action/init@${sha_one}" \
	"  ANALYZE_TEXT: uses: github/codeql-action/analyze@${sha_one}" \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - run: echo no-codeql-steps" >"${outside_steps}"
expect_fail "CodeQL-looking text outside steps" "${outside_steps}"

mapping_alias="${TMP_DIR}/mapping-alias.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - &codeql-init" \
	"        uses: github/codeql-action/init@${sha_one}" \
	"      - *codeql-init" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${mapping_alias}"
expect_fail "a repeated CodeQL step through a mapping alias" "${mapping_alias}"

scalar_alias="${TMP_DIR}/scalar-alias.yml"
printf '%s\n' \
	"env:" \
	"  INIT_ACTION: &init github/codeql-action/init@${sha_one}" \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: *init" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${scalar_alias}"
expect_fail "a CodeQL action through a scalar alias" "${scalar_alias}"

flow_step="${TMP_DIR}/flow-step.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - { uses: github/codeql-action/init@${sha_one} }" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${flow_step}"
expect_fail "a CodeQL action in a flow-mapping step" "${flow_step}"

quoted_uses_key="${TMP_DIR}/quoted-uses-key.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - \"uses\": github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${quoted_uses_key}"
expect_fail "a CodeQL action under a quoted uses key" "${quoted_uses_key}"

escaped_action="${TMP_DIR}/escaped-action.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: \"github/codeql-action/\\u0069nit@${sha_one}\"" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${escaped_action}"
expect_fail "a CodeQL action with an escaped action name" "${escaped_action}"

quoted_job="${TMP_DIR}/quoted-job.yml"
printf '%s\n' \
	"jobs:" \
	"  \"hidden\":" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${quoted_job}"
expect_fail "a CodeQL action in a quoted job mapping" "${quoted_job}"

duplicate_steps="${TMP_DIR}/duplicate-steps.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"    steps:" \
	"      - run: go build ./..." \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${duplicate_steps}"
expect_fail "phases split across duplicate steps mappings" "${duplicate_steps}"

duplicate_jobs="${TMP_DIR}/duplicate-jobs.yml"
printf '%s\n' \
	"jobs:" \
	"  hidden:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_two}" \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${duplicate_jobs}"
expect_fail "phases split across duplicate jobs mappings" "${duplicate_jobs}"

duplicate_uses="${TMP_DIR}/duplicate-uses.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - name: Hidden init" \
	"        uses: github/codeql-action/init@${sha_two}" \
	"        uses: actions/checkout@${sha_two}" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${duplicate_uses}"
expect_fail "a duplicate uses key in one step" "${duplicate_uses}"

block_scalar_uses="${TMP_DIR}/block-scalar-uses.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: >-" \
	"          github/codeql-action/init@${sha_two}" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${block_scalar_uses}"
expect_fail "a CodeQL action in a folded uses scalar" "${block_scalar_uses}"

case_variant_owner="${TMP_DIR}/case-variant-owner.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: GitHub/codeql-action/init@${sha_two}" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${case_variant_owner}"
expect_fail "a case-variant CodeQL action owner" "${case_variant_owner}"

job_condition="${TMP_DIR}/job-condition.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    if: \${{ github.repository == 'example/never' }}" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${job_condition}"
expect_fail "a condition that can disable the CodeQL job" "${job_condition}"
step_conditions="${TMP_DIR}/step-conditions.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"        if: \${{ github.repository == 'example/never' }}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" \
	"        if: \${{ github.repository == 'example/never' }}" >"${step_conditions}"
expect_fail "conditions that can disable the CodeQL steps" "${step_conditions}"
ignored_failures="${TMP_DIR}/ignored-failures.yml"
printf '%s\n' \
	"jobs:" \
	"  analyze:" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"        continue-on-error: true" \
	"      - uses: github/codeql-action/analyze@${sha_one}" \
	"        continue-on-error: true" >"${ignored_failures}"
expect_fail "CodeQL steps whose failures can be ignored" "${ignored_failures}"

needs_skipped="${TMP_DIR}/needs-skipped.yml"
printf '%s\n' \
	"jobs:" \
	"  gate:" \
	"    if: \${{ github.repository == 'example/never' }}" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - run: echo gate" \
	"  analyze:" \
	"    needs: gate" \
	"    runs-on: ubuntu-24.04" \
	"    steps:" \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${needs_skipped}"
expect_fail "a prerequisite that can skip the CodeQL job" "${needs_skipped}"

write_analyze_inputs "${TMP_DIR}/skip-queries.yml" true never
expect_fail "an analyze step that skips queries and upload" "${TMP_DIR}/skip-queries.yml"
write_analyze_inputs "${TMP_DIR}/upload-never.yml" false never
expect_fail "an analyze step that never uploads" "${TMP_DIR}/upload-never.yml"
write_analyze_inputs "${TMP_DIR}/upload-failure.yml" false failure-only
expect_fail "an analyze step that uploads failures only" "${TMP_DIR}/upload-failure.yml"
write_analyze_inputs "${TMP_DIR}/safe-inputs.yml" False always
expect_pass "an analyze step that runs and uploads" "${TMP_DIR}/safe-inputs.yml"
