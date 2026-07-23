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

if ! command -v actionlint >/dev/null 2>&1; then
	echo "actionlint is required to check the CodeQL workflow" >&2
	exit 2
fi
if ! actionlint -config-file /dev/null -shellcheck= -pyflakes= "${workflow}" >/dev/null; then
	echo "CodeQL workflow must be valid before its action references are checked" >&2
	exit 1
fi

if ! python3 -I -c 'import yaml' >/dev/null 2>&1; then
	echo "Python 3 and PyYAML are required to check workflow action references" >&2
	exit 2
fi

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
exec python3 -I "${SCRIPT_DIR}/check-workflow-action-policy.py" "${workflow}"
