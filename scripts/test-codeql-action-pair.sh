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
	local workflow="${path}.workflow.yml"

	wrap_fixture "${path}" "${workflow}"
	expect_workflow_pass "${name}" "${workflow}"
}

expect_fail() {
	local name="$1"
	local path="$2"
	local workflow="${path}.workflow.yml"

	wrap_fixture "${path}" "${workflow}"
	expect_workflow_fail "${name}" "${workflow}"
}

expect_workflow_pass() {
	local name="$1"
	local workflow="$2"

	if ! actionlint "${workflow}"; then
		echo "Expected ${name} to be a valid workflow fixture" >&2
		exit 1
	fi
	if ! "${CHECKER}" "${workflow}"; then
		echo "Expected ${name} to pass" >&2
		exit 1
	fi
}

expect_workflow_fail() {
	local name="$1"
	local workflow="$2"

	if ! actionlint "${workflow}"; then
		echo "Expected ${name} to be a valid workflow fixture" >&2
		exit 1
	fi
	if "${CHECKER}" "${workflow}" >/dev/null 2>&1; then
		echo "Expected ${name} to fail" >&2
		exit 1
	fi
}

wrap_fixture() {
	local steps="$1"
	local workflow="$2"

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

fixture_counter=0
expect_steps() {
	local expectation="$1"
	local name="$2"
	shift 2
	local path="${TMP_DIR}/case-${fixture_counter}.yml"
	fixture_counter=$((fixture_counter + 1))
	printf '%s\n' "$@" >"${path}"
	"expect_${expectation}" "${name}" "${path}"
}

valid="${TMP_DIR}/valid.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	"run: go build ./..." \
	"uses: github/codeql-action/analyze@${sha_one}" >"${valid}"
expect_pass "one ordered matching pair" "${valid}"

shadow_checker_dir="${TMP_DIR}/shadow-checker"
mkdir -p "${shadow_checker_dir}"
cp \
	"${CHECKER}" \
	"${SCRIPT_DIR}/check-workflow-action-policy.py" \
	"${shadow_checker_dir}/"
printf '%s\n' 'raise RuntimeError("repository yaml.py was imported")' \
	>"${shadow_checker_dir}/yaml.py"
if ! "${shadow_checker_dir}/check-codeql-action-pair.sh" "${valid}.workflow.yml"; then
	echo "Expected repository Python modules not to affect the checker" >&2
	exit 1
fi

expect_steps pass "an immutable revision with a YAML comment" \
	"uses: github/codeql-action/init@${sha_one} # pinned init" \
	"uses: github/codeql-action/analyze@${sha_one} # pinned analyze"

expect_steps pass "ordinary text that contains the word uses" \
	"uses: github/codeql-action/init@${sha_one}" \
	'run: echo "This workflow uses immutable action revisions."' \
	'# This workflow uses immutable action revisions.' \
	"uses: github/codeql-action/analyze@${sha_one}"

valid_shell_escape="${TMP_DIR}/valid-shell-escape.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	"run: printf '\\x41\\n'" \
	"uses: github/codeql-action/analyze@${sha_one}" >"${valid_shell_escape}"
expect_pass "a shell escape in an ordinary run step" "${valid_shell_escape}"

valid_quoted_action="${TMP_DIR}/valid-quoted-action.yml"
printf '%s\n' \
	"- uses: \"actions/checkout@${sha_one}\"" \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}" >"${valid_quoted_action}"
expect_pass "an immutable quoted remote action" "${valid_quoted_action}"

valid_local_action="${TMP_DIR}/valid-local-action.yml"
printf '%s\n' \
	'- uses: ./local-action' \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}" >"${valid_local_action}"
expect_pass "a local action from the checked-out revision" "${valid_local_action}"

traversing_local_action="${TMP_DIR}/traversing-local-action.yml"
printf '%s\n' \
	'- uses: ./local-action/../other-action' \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}" >"${traversing_local_action}"
expect_fail "a local action path with a parent segment" "${traversing_local_action}"

backslash_local_action="${TMP_DIR}/backslash-local-action.yml"
printf '%s\n' \
	'- uses: ./local-action\..\other-action' \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}" >"${backslash_local_action}"
expect_fail "a local action path with backslash separators" "${backslash_local_action}"

mutable_remote_action="${TMP_DIR}/mutable-remote-action.yml"
printf '%s\n' \
	'- uses: actions/checkout@main' \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}" >"${mutable_remote_action}"
expect_fail "a mutable remote action" "${mutable_remote_action}"

mutable_popular_action="${TMP_DIR}/mutable-popular-action.yml"
printf '%s\n' \
	'- uses: actions/checkout@v4' \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}" >"${mutable_popular_action}"
expect_fail "a mutable action in actionlint's popular action data" "${mutable_popular_action}"

block_scalar_decoy="${TMP_DIR}/block-scalar-decoy.yml"
printf '%s\n' \
	'- run: |' \
	"    uses: github/codeql-action/init@${sha_one}" \
	"    uses: github/codeql-action/analyze@${sha_one}" >"${block_scalar_decoy}"
expect_fail "CodeQL text in a block scalar without CodeQL action steps" "${block_scalar_decoy}"

valid_docker_action="${TMP_DIR}/valid-docker-action.yml"
printf '%s\n' \
	'- uses: docker://alpine@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}" >"${valid_docker_action}"
expect_pass "a digest-pinned Docker action" "${valid_docker_action}"

mutable_docker_action="${TMP_DIR}/mutable-docker-action.yml"
printf '%s\n' \
	'- uses: docker://alpine:latest' \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}" >"${mutable_docker_action}"
expect_fail "a tag-pinned Docker action" "${mutable_docker_action}"

merge_alias="${TMP_DIR}/merge-alias.yml"
printf '%s\n' \
	'- &pinned_init' \
	"  uses: github/codeql-action/init@${sha_one}" \
	'- <<: *pinned_init' \
	"uses: github/codeql-action/analyze@${sha_one}" >"${merge_alias}"
wrap_fixture "${merge_alias}" "${merge_alias}.workflow.yml"
if "${CHECKER}" "${merge_alias}.workflow.yml" >/dev/null 2>&1; then
	echo "Expected a merge-key duplicate init phase to fail" >&2
	exit 1
fi

immutable_reusable="${TMP_DIR}/immutable-reusable.yml"
printf '%s\n' \
	'name: immutable reusable workflow' \
	'on: workflow_dispatch' \
	'permissions: {}' \
	'jobs:' \
	'  analyze:' \
	'    runs-on: ubuntu-latest' \
	'    steps:' \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" \
	'  reusable:' \
	"    uses: actions/starter-workflows/.github/workflows/codeql.yml@${sha_one}" >"${immutable_reusable}"
expect_workflow_pass "an immutable reusable workflow call" "${immutable_reusable}"

mutable_reusable="${TMP_DIR}/mutable-reusable.yml"
printf '%s\n' \
	'name: mutable reusable workflow' \
	'on: workflow_dispatch' \
	'permissions: {}' \
	'jobs:' \
	'  analyze:' \
	'    runs-on: ubuntu-latest' \
	'    steps:' \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" \
	'  reusable:' \
	'    uses: actions/starter-workflows/.github/workflows/codeql.yml@main' >"${mutable_reusable}"
expect_workflow_fail "a mutable reusable workflow call" "${mutable_reusable}"

split_jobs="${TMP_DIR}/split-jobs.yml"
printf '%s\n' \
	'name: split CodeQL phases' \
	'on: workflow_dispatch' \
	'permissions: {}' \
	'jobs:' \
	'  initialize:' \
	'    runs-on: ubuntu-latest' \
	'    steps:' \
	"      - uses: github/codeql-action/init@${sha_one}" \
	'  analyze:' \
	'    runs-on: ubuntu-latest' \
	'    steps:' \
	"      - run: ':'" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${split_jobs}"
expect_workflow_fail "CodeQL phases in different jobs" "${split_jobs}"

conditional_job="${TMP_DIR}/conditional-job.yml"
printf '%s\n' \
	'name: conditional CodeQL job' \
	'on: workflow_dispatch' \
	'permissions: {}' \
	'jobs:' \
	'  analyze:' \
	"    if: github.repository == 'never/matches'" \
	'    runs-on: ubuntu-latest' \
	'    steps:' \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${conditional_job}"
expect_workflow_fail "a conditional CodeQL job" "${conditional_job}"

dependent_job="${TMP_DIR}/dependent-job.yml"
printf '%s\n' \
	'name: dependent CodeQL job' \
	'on: workflow_dispatch' \
	'permissions: {}' \
	'jobs:' \
	'  prerequisite:' \
	"    if: github.repository == 'never/matches'" \
	'    runs-on: ubuntu-latest' \
	'    steps:' \
	"      - run: ':'" \
	'  analyze:' \
	'    needs: prerequisite' \
	'    runs-on: ubuntu-latest' \
	'    steps:' \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${dependent_job}"
expect_workflow_fail "a CodeQL job with a prerequisite" "${dependent_job}"

tolerated_job="${TMP_DIR}/tolerated-job.yml"
printf '%s\n' \
	'name: tolerated CodeQL job failure' \
	'on: workflow_dispatch' \
	'permissions: {}' \
	'jobs:' \
	'  analyze:' \
	'    continue-on-error: true' \
	'    runs-on: ubuntu-latest' \
	'    steps:' \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${tolerated_job}"
expect_workflow_fail "a tolerated CodeQL job failure" "${tolerated_job}"

boolean_job_ids="${TMP_DIR}/boolean-job-ids.yml"
printf '%s\n' \
	'name: YAML boolean-like job identifiers' \
	'on: workflow_dispatch' \
	'permissions: {}' \
	'jobs:' \
	'  yes:' \
	'    runs-on: ubuntu-latest' \
	'    steps:' \
	'      - uses: actions/checkout@main' \
	'  true:' \
	'    runs-on: ubuntu-latest' \
	'    steps:' \
	"      - uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" >"${boolean_job_ids}"
expect_workflow_fail "distinct YAML boolean-like job identifiers" "${boolean_job_ids}"

invalid_workflow="${TMP_DIR}/invalid-workflow.yml"
printf '%s\n' \
	'name: invalid workflow' \
	'on: workflow_dispatch' \
	'jobs:' \
	'  analyze:' \
	'    runs-on: ubuntu-latest' \
	'    steps: [' >"${invalid_workflow}"
if "${CHECKER}" "${invalid_workflow}" >/dev/null 2>&1; then
	echo "Expected an invalid workflow to fail" >&2
	exit 1
fi

ignored_actionlint_repo="${TMP_DIR}/ignored-actionlint-repo"
mkdir -p \
	"${ignored_actionlint_repo}/.github/workflows" \
	"${ignored_actionlint_repo}/.github"
git init -q "${ignored_actionlint_repo}"
printf '%s\n' \
	'paths:' \
	'  .github/workflows/**/*.{yml,yaml}:' \
	'    ignore:' \
	'      - ".*"' >"${ignored_actionlint_repo}/.github/actionlint.yaml"
printf '%s\n' \
	'name: ignored duplicate key' \
	'on: workflow_dispatch' \
	'jobs:' \
	'  analyze:' \
	'    runs-on: ubuntu-latest' \
	'    steps:' \
	'      - uses: actions/checkout@main' \
	"        uses: github/codeql-action/init@${sha_one}" \
	"      - uses: github/codeql-action/analyze@${sha_one}" \
	>"${ignored_actionlint_repo}/.github/workflows/codeql.yml"
(
	cd "${ignored_actionlint_repo}"
	if ! actionlint .github/workflows/codeql.yml >/dev/null; then
		echo "Expected the fixture actionlint configuration to suppress its error" >&2
		exit 1
	fi
	if "${CHECKER}" .github/workflows/codeql.yml >/dev/null 2>&1; then
		echo "Expected repository actionlint ignores not to affect the checker" >&2
		exit 1
	fi
)

expect_steps fail "a missing analyze phase" \
	"uses: github/codeql-action/init@${sha_one}"

expect_steps fail "a missing init phase" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a conditional CodeQL init phase" \
	"- if: github.repository == 'never/matches'" \
	"  uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a conditional CodeQL analyze phase" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- if: github.repository == 'never/matches'" \
	"  uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a tolerated CodeQL init failure" \
	'- continue-on-error: true' \
	"  uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a tolerated CodeQL analyze failure" \
	"uses: github/codeql-action/init@${sha_one}" \
	'- continue-on-error: true' \
	"  uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a CodeQL analyze step that disables upload" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: github/codeql-action/analyze@${sha_one}" \
	'  with:' \
	'    upload: never'

expect_steps fail "a case-varied CodeQL analyze upload input" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: github/codeql-action/analyze@${sha_one}" \
	'  with:' \
	'    UPLOAD: never'

expect_steps fail "a CodeQL analyze step that skips queries" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: github/codeql-action/analyze@${sha_one}" \
	'  with:' \
	'    skip-queries: true'

expect_steps fail "a CodeQL analyze step that expects an error" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: github/codeql-action/analyze@${sha_one}" \
	'  with:' \
	'    expect-error: true'

expect_steps fail "a commented analyze phase" \
	"uses: github/codeql-action/init@${sha_one}" \
	"# uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a duplicate init phase" \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a duplicate analyze phase" \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "swapped phases" \
	"uses: github/codeql-action/analyze@${sha_one}" \
	"run: go build ./..." \
	"uses: github/codeql-action/init@${sha_one}"

expect_steps fail "different immutable revisions" \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_two}"

expect_steps fail "a movable init suffix after an immutable revision" \
	"uses: github/codeql-action/init@${sha_one}-moving" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a movable analyze suffix after an immutable revision" \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}-moving"

expect_steps fail "an init suffix that looks like a YAML comment" \
	"uses: github/codeql-action/init@${sha_one}#moving" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "an analyze suffix that looks like a YAML comment" \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}#moving"

short_sha="${sha_one%?}"
expect_steps fail "an init revision that is not 40 hexadecimal characters" \
	"uses: github/codeql-action/init@${short_sha}" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "an analyze revision that is not 40 hexadecimal characters" \
	"uses: github/codeql-action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${short_sha}"

expect_steps fail "a matching pair that is not 40 hexadecimal characters" \
	"uses: github/codeql-action/init@${short_sha}" \
	"uses: github/codeql-action/analyze@${short_sha}"

expect_steps fail "an extra list-item CodeQL phase" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: github/codeql-action/init@main" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "an extra list-item CodeQL analyze phase" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: github/codeql-action/analyze@main" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a case-varied extra CodeQL phase" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: GitHub/CodeQL-Action/init@main" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a case-varied extra CodeQL analyze phase" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: GitHub/CodeQL-Action/analyze@main" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a case-varied pinned extra CodeQL init phase" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: GitHub/CodeQL-Action/init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a case-varied pinned extra CodeQL analyze phase" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: GitHub/CodeQL-Action/analyze@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a GitHub action path with a dot segment" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: github/codeql-action/init/.@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}"

expect_steps fail "a GitHub action path with a parent segment" \
	"uses: github/codeql-action/init@${sha_one}" \
	"- uses: github/codeql-action/unused/../init@${sha_one}" \
	"uses: github/codeql-action/analyze@${sha_one}"

escaped_owner="${TMP_DIR}/escaped-owner.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	'- uses: "\x67ithub/codeql-action/init@main"' \
	"uses: github/codeql-action/analyze@${sha_one}" >"${escaped_owner}"
expect_fail "an escaped extra CodeQL phase" "${escaped_owner}"

escaped_key_owner="${TMP_DIR}/escaped-key-owner.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	'- "\x75ses": "\x67ithub/codeql-action/init@main"' \
	"uses: github/codeql-action/analyze@${sha_one}" >"${escaped_key_owner}"
expect_fail "an escaped uses key and action owner" "${escaped_key_owner}"

continued_key_init="${TMP_DIR}/continued-key-init.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	"- ? \"us\\" \
	'    es"' \
	"  : \"git\\" \
	'    hub/codeql-action/init@main"' \
	"uses: github/codeql-action/analyze@${sha_one}" >"${continued_key_init}"
expect_fail "a continued uses key and CodeQL init owner" "${continued_key_init}"

continued_key_analyze="${TMP_DIR}/continued-key-analyze.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	"- ? \"us\\" \
	'    es"' \
	"  : \"git\\" \
	'    hub/codeql-action/analyze@main"' \
	"uses: github/codeql-action/analyze@${sha_one}" >"${continued_key_analyze}"
expect_fail "a continued uses key and CodeQL analyze owner" "${continued_key_analyze}"

double_quoted_key="${TMP_DIR}/double-quoted-key.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	'- "uses": github/codeql-action/init@main' \
	"uses: github/codeql-action/analyze@${sha_one}" >"${double_quoted_key}"
expect_fail "a double-quoted uses key" "${double_quoted_key}"

single_quoted_key="${TMP_DIR}/single-quoted-key.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	"- 'uses': github/codeql-action/init@main" \
	"uses: github/codeql-action/analyze@${sha_one}" >"${single_quoted_key}"
expect_fail "a single-quoted uses key" "${single_quoted_key}"

aliased_init="${TMP_DIR}/aliased-init.yml"
printf '%s\n' \
	'- &pinned_init' \
	"  uses: github/codeql-action/init@${sha_one}" \
	'- *pinned_init' \
	"uses: github/codeql-action/analyze@${sha_one}" >"${aliased_init}"
expect_fail "an aliased duplicate init phase" "${aliased_init}"

aliased_analyze="${TMP_DIR}/aliased-analyze.yml"
printf '%s\n' \
	"uses: github/codeql-action/init@${sha_one}" \
	'- &pinned_analyze' \
	"  uses: github/codeql-action/analyze@${sha_one}" \
	'- *pinned_analyze' >"${aliased_analyze}"
expect_fail "an aliased duplicate analyze phase" "${aliased_analyze}"
