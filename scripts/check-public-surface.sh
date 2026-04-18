#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"
REPO_ROOT="$(
	cd -- "${SCRIPT_DIR}/.." && pwd
)"

cd "${REPO_ROOT}"

disallowed_literals=(
	"/Users/"
	"/private/tmp/"
	"omkharanarasaratnam"
	"src/workcell"
	"cloudflare-site-platform-ts"
	"security-validation/"
)

mapfile -d '' repo_paths < <(
	git ls-files --cached --others --exclude-standard -z \
		':(exclude)scripts/check-public-surface.sh'
)

for needle in "${disallowed_literals[@]}"; do
	if ((${#repo_paths[@]} > 0)) && grep -I -n -F -- "${needle}" "${repo_paths[@]}" >/dev/null; then
		echo "Repository surface contains an internal-only reference: ${needle}" >&2
		grep -I -n -F -- "${needle}" "${repo_paths[@]}" >&2
		exit 1
	fi
done

for path in "${repo_paths[@]}"; do
	case "${path}" in
		*.orig|*.rej|*.bak|*.tmp|*.temp|*.pyc|*~|.DS_Store|*/.DS_Store|__pycache__/*|security-validation|security-validation/*)
			echo "Tracked repository detritus is not allowed: ${path}" >&2
			exit 1
			;;
	esac
done
