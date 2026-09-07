#!/usr/bin/env bash
# This file is sourced by other scripts/*.sh files. Do not execute it
# directly; it defines shared helper functions and has no side effects.

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "$1 not found" >&2
		exit 1
	}
}

resolve_source_date_epoch() {
	if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
		if [[ ! "${SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]]; then
			echo "SOURCE_DATE_EPOCH must be an integer" >&2
			exit 1
		fi
		printf '%s\n' "${SOURCE_DATE_EPOCH}"
		return
	fi

	if command -v git >/dev/null 2>&1 &&
		git -C "${SOURCE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "${SOURCE_ROOT}" log -1 --format=%ct HEAD
		return
	fi

	echo "SOURCE_DATE_EPOCH is required when git metadata is unavailable" >&2
	exit 1
}

validate_image_ref() {
	local name="$1"
	local value="$2"

	if [[ ! "${value}" =~ ^[A-Za-z0-9./:@_-]+$ ]]; then
		echo "Unexpected ${name}: ${value}" >&2
		exit 1
	fi
}
