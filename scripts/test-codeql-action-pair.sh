#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
POLICY_CHECKER="${SCRIPT_DIR}/check-workflow-action-policy.py"

run_checker() {
	actionlint -config-file /dev/null -shellcheck= -pyflakes= "$1" \
		>/dev/null &&
		python3 -I "${POLICY_CHECKER}" --require-codeql-pair "$1"
}

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT INT TERM

sha_one="99df26d4f13ea111d4ec1a7dddef6063f76b97e9"
sha_two="8aad20d150bbac5944a9f9d289da16a4b0d87c1e"
short_sha="${sha_one%?}"

wrap_fixture() {
	local steps="$1" workflow="$2"
	{
		printf '%s\n' \
			'name: CodeQL pair fixture' \
			'on: workflow_dispatch' \
			'permissions: {}' \
			'jobs:' \
			'  analyze:' \
			'    runs-on: ubuntu-latest' \
			'    steps:'
		awk '
			/^(uses|run):/ {
				print "      - " $0
				next
			}
			{ print "      " $0 }
		' "${steps}"
	} >"${workflow}"
}

expect_workflow_result() {
	local expectation="$1" name="$2" workflow="$3"
	if ! actionlint "${workflow}"; then echo "Expected ${name} to be a valid workflow fixture" >&2; exit 1; fi
	if [ "${expectation}" = pass ] && ! run_checker "${workflow}"; then echo "Expected ${name} to pass" >&2; exit 1; fi
	if [ "${expectation}" = fail ] && run_checker "${workflow}" >/dev/null 2>&1; then echo "Expected ${name} to fail" >&2; exit 1; fi
}

fixture_counter=0

expect_steps() {
	local expectation="$1" name="$2"; shift 2
	local path="${TMP_DIR}/case-${fixture_counter}.yml"; local workflow="${path}.workflow.yml"
	fixture_counter=$((fixture_counter + 1))
	printf '%s\n' "$@" >"${path}"
	wrap_fixture "${path}" "${workflow}"
	expect_workflow_result "${expectation}" "${name}" "${workflow}"
}

expect_workflow() {
	local expectation="$1" name="$2"; shift 2
	local path="${TMP_DIR}/workflow-${fixture_counter}.yml"
	fixture_counter=$((fixture_counter + 1))
	printf '%s\n' "$@" >"${path}"
	expect_workflow_result "${expectation}" "${name}" "${path}"
}

must_fail() {
	local name="$1" workflow="$2"
	if run_checker "${workflow}" >/dev/null 2>&1; then echo "Expected ${name} to fail" >&2; exit 1; fi
}

expect_steps pass "one ordered matching pair" "uses: github/codeql-action/init@${sha_one}" "run: go build ./..." "uses: github/codeql-action/analyze@${sha_one}"
expect_steps pass "an immutable revision with a YAML comment" "uses: github/codeql-action/init@${sha_one} # pinned init" "uses: github/codeql-action/analyze@${sha_one} # pinned analyze"
expect_steps pass "ordinary text that contains the word uses" "uses: github/codeql-action/init@${sha_one}" 'run: echo "This workflow uses immutable action revisions."' '# This workflow uses immutable action revisions.' "uses: github/codeql-action/analyze@${sha_one}"
expect_steps pass "a shell escape in an ordinary run step" "uses: github/codeql-action/init@${sha_one}" "run: printf '\\x41\\n'" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps pass "an immutable quoted remote action" "- uses: \"actions/checkout@${sha_one}\"" "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps pass "a local action from the checked-out revision" '- uses: ./local-action' "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps pass "a digest-pinned Docker action" '- uses: docker://alpine@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a local action path with a parent segment" '- uses: ./local-action/../other-action' "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a local action path with backslash separators" '- uses: ./local-action\..\other-action' "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a mutable remote action" '- uses: actions/checkout@main' "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a mutable action in actionlint's popular action data" '- uses: actions/checkout@v4' "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "CodeQL text in a block scalar without CodeQL action steps" '- run: |' "    uses: github/codeql-action/init@${sha_one}" "    uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a tag-pinned Docker action" '- uses: docker://alpine:latest' "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a missing analyze phase" "uses: github/codeql-action/init@${sha_one}"
expect_steps fail "a missing init phase" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a conditional CodeQL init phase" "- if: github.repository == 'never/matches'" "  uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a conditional CodeQL analyze phase" "uses: github/codeql-action/init@${sha_one}" "- if: github.repository == 'never/matches'" "  uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a tolerated CodeQL init failure" '- continue-on-error: true' "  uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a tolerated CodeQL analyze failure" "uses: github/codeql-action/init@${sha_one}" '- continue-on-error: true' "  uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a CodeQL analyze step that disables upload" "uses: github/codeql-action/init@${sha_one}" "- uses: github/codeql-action/analyze@${sha_one}" '  with:' '    upload: never'
expect_steps fail "a case-varied CodeQL analyze upload input" "uses: github/codeql-action/init@${sha_one}" "- uses: github/codeql-action/analyze@${sha_one}" '  with:' '    UPLOAD: never'
expect_steps fail "a CodeQL analyze step that skips queries" "uses: github/codeql-action/init@${sha_one}" "- uses: github/codeql-action/analyze@${sha_one}" '  with:' '    skip-queries: true'
expect_steps fail "a CodeQL analyze step that expects an error" "uses: github/codeql-action/init@${sha_one}" "- uses: github/codeql-action/analyze@${sha_one}" '  with:' '    expect-error: true'
expect_steps fail "a commented analyze phase" "uses: github/codeql-action/init@${sha_one}" "# uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a duplicate init phase" "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a duplicate analyze phase" "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "swapped phases" "uses: github/codeql-action/analyze@${sha_one}" "run: go build ./..." "uses: github/codeql-action/init@${sha_one}"
expect_steps fail "different immutable revisions" "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_two}"
expect_steps fail "a movable init suffix after an immutable revision" "uses: github/codeql-action/init@${sha_one}-moving" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a movable analyze suffix after an immutable revision" "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}-moving"
expect_steps fail "an init suffix that looks like a YAML comment" "uses: github/codeql-action/init@${sha_one}#moving" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "an analyze suffix that looks like a YAML comment" "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}#moving"
expect_steps fail "an init revision that is not 40 hexadecimal characters" "uses: github/codeql-action/init@${short_sha}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "an analyze revision that is not 40 hexadecimal characters" "uses: github/codeql-action/init@${sha_one}" "uses: github/codeql-action/analyze@${short_sha}"
expect_steps fail "a matching pair that is not 40 hexadecimal characters" "uses: github/codeql-action/init@${short_sha}" "uses: github/codeql-action/analyze@${short_sha}"
expect_steps fail "an extra list-item CodeQL phase" "uses: github/codeql-action/init@${sha_one}" "- uses: github/codeql-action/init@main" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "an extra list-item CodeQL analyze phase" "uses: github/codeql-action/init@${sha_one}" "- uses: github/codeql-action/analyze@main" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a case-varied extra CodeQL phase" "uses: github/codeql-action/init@${sha_one}" "- uses: GitHub/CodeQL-Action/init@main" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a case-varied extra CodeQL analyze phase" "uses: github/codeql-action/init@${sha_one}" "- uses: GitHub/CodeQL-Action/analyze@main" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a case-varied pinned extra CodeQL init phase" "uses: github/codeql-action/init@${sha_one}" "- uses: GitHub/CodeQL-Action/init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a case-varied pinned extra CodeQL analyze phase" "uses: github/codeql-action/init@${sha_one}" "- uses: GitHub/CodeQL-Action/analyze@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a GitHub action path with a dot segment" "uses: github/codeql-action/init@${sha_one}" "- uses: github/codeql-action/init/.@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a GitHub action path with a parent segment" "uses: github/codeql-action/init@${sha_one}" "- uses: github/codeql-action/unused/../init@${sha_one}" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "an escaped extra CodeQL phase" "uses: github/codeql-action/init@${sha_one}" '- uses: "\x67ithub/codeql-action/init@main"' "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "an escaped uses key and action owner" "uses: github/codeql-action/init@${sha_one}" '- "\x75ses": "\x67ithub/codeql-action/init@main"' "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a continued uses key and CodeQL init owner" "uses: github/codeql-action/init@${sha_one}" "- ? \"us\\" '    es"' "  : \"git\\" '    hub/codeql-action/init@main"' "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a continued uses key and CodeQL analyze owner" "uses: github/codeql-action/init@${sha_one}" "- ? \"us\\" '    es"' "  : \"git\\" '    hub/codeql-action/analyze@main"' "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a double-quoted uses key" "uses: github/codeql-action/init@${sha_one}" '- "uses": github/codeql-action/init@main' "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "a single-quoted uses key" "uses: github/codeql-action/init@${sha_one}" "- 'uses': github/codeql-action/init@main" "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "an aliased duplicate init phase" '- &pinned_init' "  uses: github/codeql-action/init@${sha_one}" '- *pinned_init' "uses: github/codeql-action/analyze@${sha_one}"
expect_steps fail "an aliased duplicate analyze phase" "uses: github/codeql-action/init@${sha_one}" '- &pinned_analyze' "  uses: github/codeql-action/analyze@${sha_one}" '- *pinned_analyze'

expect_workflow pass "an immutable reusable workflow call" 'name: immutable reusable workflow' 'on: workflow_dispatch' 'permissions: {}' 'jobs:' '  analyze:' '    runs-on: ubuntu-latest' '    steps:' "      - uses: github/codeql-action/init@${sha_one}" "      - uses: github/codeql-action/analyze@${sha_one}" '  reusable:' "    uses: actions/starter-workflows/.github/workflows/codeql.yml@${sha_one}"
expect_workflow fail "a mutable reusable workflow call" 'name: mutable reusable workflow' 'on: workflow_dispatch' 'permissions: {}' 'jobs:' '  analyze:' '    runs-on: ubuntu-latest' '    steps:' "      - uses: github/codeql-action/init@${sha_one}" "      - uses: github/codeql-action/analyze@${sha_one}" '  reusable:' '    uses: actions/starter-workflows/.github/workflows/codeql.yml@main'
expect_workflow fail "CodeQL phases in different jobs" 'name: split CodeQL phases' 'on: workflow_dispatch' 'permissions: {}' 'jobs:' '  initialize:' '    runs-on: ubuntu-latest' '    steps:' "      - uses: github/codeql-action/init@${sha_one}" '  analyze:' '    runs-on: ubuntu-latest' '    steps:' "      - run: ':'" "      - uses: github/codeql-action/analyze@${sha_one}"
expect_workflow fail "a conditional CodeQL job" 'name: conditional CodeQL job' 'on: workflow_dispatch' 'permissions: {}' 'jobs:' '  analyze:' "    if: github.repository == 'never/matches'" '    runs-on: ubuntu-latest' '    steps:' "      - uses: github/codeql-action/init@${sha_one}" "      - uses: github/codeql-action/analyze@${sha_one}"
expect_workflow fail "a CodeQL job with a prerequisite" 'name: dependent CodeQL job' 'on: workflow_dispatch' 'permissions: {}' 'jobs:' '  prerequisite:' "    if: github.repository == 'never/matches'" '    runs-on: ubuntu-latest' '    steps:' "      - run: ':'" '  analyze:' '    needs: prerequisite' '    runs-on: ubuntu-latest' '    steps:' "      - uses: github/codeql-action/init@${sha_one}" "      - uses: github/codeql-action/analyze@${sha_one}"
expect_workflow fail "a tolerated CodeQL job failure" 'name: tolerated CodeQL job failure' 'on: workflow_dispatch' 'permissions: {}' 'jobs:' '  analyze:' '    continue-on-error: true' '    runs-on: ubuntu-latest' '    steps:' "      - uses: github/codeql-action/init@${sha_one}" "      - uses: github/codeql-action/analyze@${sha_one}"
expect_workflow fail "distinct YAML boolean-like job identifiers" 'name: YAML boolean-like job identifiers' 'on: workflow_dispatch' 'permissions: {}' 'jobs:' '  yes:' '    runs-on: ubuntu-latest' '    steps:' '      - uses: actions/checkout@main' '  true:' '    runs-on: ubuntu-latest' '    steps:' "      - uses: github/codeql-action/init@${sha_one}" "      - uses: github/codeql-action/analyze@${sha_one}"

merge_source="${TMP_DIR}/merge-alias.yml"
printf '%s\n' '- &pinned_init' "  uses: github/codeql-action/init@${sha_one}" '- <<: *pinned_init' "uses: github/codeql-action/analyze@${sha_one}" >"${merge_source}"
wrap_fixture "${merge_source}" "${merge_source}.workflow.yml"; must_fail "a merge-key duplicate init phase" "${merge_source}.workflow.yml"

invalid_workflow="${TMP_DIR}/invalid-workflow.yml"
printf '%s\n' 'name: invalid workflow' 'on: workflow_dispatch' 'jobs:' '  analyze:' '    runs-on: ubuntu-latest' '    steps: [' >"${invalid_workflow}"
must_fail "an invalid workflow" "${invalid_workflow}"

ignored_repo="${TMP_DIR}/ignored-actionlint-repo"
mkdir -p "${ignored_repo}/.github/workflows" && git init -q "${ignored_repo}"
printf '%s\n' 'paths:' '  .github/workflows/**/*.{yml,yaml}:' '    ignore:' '      - ".*"' >"${ignored_repo}/.github/actionlint.yaml"
printf '%s\n' 'name: ignored duplicate key' 'on: workflow_dispatch' 'jobs:' '  analyze:' '    runs-on: ubuntu-latest' '    steps:' '      - uses: actions/checkout@main' "        uses: github/codeql-action/init@${sha_one}" "      - uses: github/codeql-action/analyze@${sha_one}" >"${ignored_repo}/.github/workflows/codeql.yml"
(
	cd "${ignored_repo}"
	if ! actionlint .github/workflows/codeql.yml >/dev/null; then echo "Expected the fixture actionlint configuration to suppress its error" >&2; exit 1; fi
	must_fail "repository actionlint ignores" .github/workflows/codeql.yml
)

shadow_dir="${TMP_DIR}/shadow-checker"
mkdir -p "${shadow_dir}" && cp "${POLICY_CHECKER}" "${shadow_dir}/"
printf '%s\n' 'raise RuntimeError("repository yaml.py was imported")' >"${shadow_dir}/yaml.py"
shadow_source="${TMP_DIR}/shadow-source.yml"
printf '%s\n' "uses: github/codeql-action/init@${sha_one}" "run: go build ./..." "uses: github/codeql-action/analyze@${sha_one}" >"${shadow_source}"
wrap_fixture "${shadow_source}" "${shadow_source}.workflow.yml"; python3 -I "${shadow_dir}/check-workflow-action-policy.py" --require-codeql-pair "${shadow_source}.workflow.yml" || { echo "Expected repository Python modules not to affect the checker" >&2; exit 1; }

no_codeql="${TMP_DIR}/no-codeql.yml"
printf '%s\n' "uses: actions/checkout@${sha_one}" "run: go build ./..." >"${no_codeql}"
wrap_fixture "${no_codeql}" "${no_codeql}.workflow.yml"; python3 -I "${POLICY_CHECKER}" "${no_codeql}.workflow.yml" || { echo "Expected a workflow without CodeQL steps to pass without --require-codeql-pair" >&2; exit 1; }
if python3 -I "${POLICY_CHECKER}" --require-codeql-pair "${no_codeql}.workflow.yml" >/dev/null 2>&1; then echo "Expected a workflow without CodeQL steps to fail with --require-codeql-pair" >&2; exit 1; fi

single_phase="${TMP_DIR}/single-phase.yml"
printf '%s\n' "uses: github/codeql-action/init@${sha_one}" >"${single_phase}"
wrap_fixture "${single_phase}" "${single_phase}.workflow.yml"; if python3 -I "${POLICY_CHECKER}" "${single_phase}.workflow.yml" >/dev/null 2>&1; then echo "Expected a lone CodeQL init step to fail without --require-codeql-pair" >&2; exit 1; fi
