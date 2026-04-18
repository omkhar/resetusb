#!/usr/bin/env bash

set -euo pipefail

max_changed_files="${MAX_PR_CHANGED_FILES:-20}"
max_total_lines="${MAX_PR_TOTAL_LINES:-750}"
changed_files="${PR_CHANGED_FILES:-}"
additions="${PR_ADDITIONS:-}"
deletions="${PR_DELETIONS:-}"

require_integer() {
	local name="$1"
	local value="$2"

	if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
		echo "${name} must be a non-negative integer, got: ${value}" >&2
		exit 1
	fi
}

require_integer "MAX_PR_CHANGED_FILES" "${max_changed_files}"
require_integer "MAX_PR_TOTAL_LINES" "${max_total_lines}"
require_integer "PR_CHANGED_FILES" "${changed_files}"
require_integer "PR_ADDITIONS" "${additions}"
require_integer "PR_DELETIONS" "${deletions}"

total_lines=$((additions + deletions))

if (( changed_files > max_changed_files || total_lines > max_total_lines )); then
	echo "Pull request is too large for the resetusb reviewability gate." >&2
	echo "Changed files: ${changed_files} (max ${max_changed_files})" >&2
	echo "Total changed lines: ${total_lines} (max ${max_total_lines})" >&2
	echo "Split the work into smaller, reviewable PRs before merging." >&2
	exit 1
fi
