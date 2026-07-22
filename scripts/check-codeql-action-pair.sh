#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 1 ]]; then
	echo "usage: check-codeql-action-pair.sh WORKFLOW" >&2
	exit 2
fi

workflow="$1"
if [[ ! -f "${workflow}" ]]; then
	echo "CodeQL workflow does not exist: ${workflow}" >&2
	exit 2
fi

init_use_count="$(grep -Ec '^[[:space:]]*uses:[[:space:]]*github/codeql-action/init@' "${workflow}" || true)"
analyze_use_count="$(grep -Ec '^[[:space:]]*uses:[[:space:]]*github/codeql-action/analyze@' "${workflow}" || true)"

if [[ "${init_use_count}" != 1 || "${analyze_use_count}" != 1 ]]; then
	echo "CodeQL workflow must contain exactly one init phase and one analyze phase" >&2
	exit 1
fi

init_ref="$(
	sed -nE \
		's#^[[:space:]]*uses:[[:space:]]*github/codeql-action/init@([0-9a-f]{40}).*#\1#p' \
		"${workflow}"
)"
analyze_ref="$(
	sed -nE \
		's#^[[:space:]]*uses:[[:space:]]*github/codeql-action/analyze@([0-9a-f]{40}).*#\1#p' \
		"${workflow}"
)"

if [[ -z "${init_ref}" || -z "${analyze_ref}" ]]; then
	echo "CodeQL init and analyze must use full immutable commit revisions" >&2
	exit 1
fi

if [[ "${init_ref}" != "${analyze_ref}" ]]; then
	echo "CodeQL init and analyze must use the same immutable revision" >&2
	exit 1
fi

init_line="$(awk '/^[[:space:]]*uses:[[:space:]]*github\/codeql-action\/init@/ { print NR }' "${workflow}")"
analyze_line="$(awk '/^[[:space:]]*uses:[[:space:]]*github\/codeql-action\/analyze@/ { print NR }' "${workflow}")"

if ((init_line >= analyze_line)); then
	echo "CodeQL init must occur before CodeQL analyze" >&2
	exit 1
fi
