#!/usr/bin/env bash

set -euo pipefail

# Run one apt-get command with a bounded retry for transient mirror errors.
#
# The Debian snapshot server can drop connections for minutes at a time.
# The apt in Debian 13 handles its own delayed retries in a loop that can
# spin while the download pipeline is full. Each turn of that loop stores
# a "Tried to start delayed item" warning, and apt prints all of them at
# exit (Debian bug #1111554). One CI job wrote gigabytes of these lines.
#
# Thus apt makes no retry of its own here, and an index download failure
# is an error. This script retries the full command with backoff instead.
# Each attempt is idempotent: apt keeps the package files that it already
# downloaded. The snapshot pin and the InRelease digest check stay as they
# are, so a retry cannot change the package set.
#
# Each attempt has a time limit, and each distinct output line shows at
# most three times. A stuck or noisy attempt cannot flood the CI log.
#
# Run as root, the script first adds a fallback to other official Ubuntu
# mirrors for the Ubuntu archive sources (see use_ubuntu_mirror_fallback).
# Set APT_UBUNTU_MIRROR_FALLBACK=0 to skip that step.

attempts="${APT_RETRY_ATTEMPTS:-5}"
attempt_timeout="${APT_RETRY_TIMEOUT:-1200}"
max_repeats=3

if [[ $# -eq 0 ]]; then
	echo "Usage: $0 <apt-get arguments>" >&2
	exit 1
fi

if [[ ! "${attempts}" =~ ^[1-9][0-9]*$ ]]; then
	echo "APT_RETRY_ATTEMPTS must be a positive integer" >&2
	exit 1
fi

if [[ ! "${attempt_timeout}" =~ ^[1-9][0-9]*$ ]]; then
	echo "APT_RETRY_TIMEOUT must be a positive integer" >&2
	exit 1
fi

# Ubuntu's own archive hosts all live under ubuntu.com, so one DNS fault
# takes every one of them down at once. On 2026-11-11 GitHub runners
# could not resolve *.ubuntu.com for hours, and each job that ran apt in
# an Ubuntu container failed.
#
# use_ubuntu_mirror_fallback points the Ubuntu archive sources at a
# mirror list that adds other official Ubuntu mirrors (from Launchpad's
# mirror registry) on other domains. apt tries the list in order and
# moves to the next mirror when one fails. Mirrors whose host does not
# resolve now go last. The sources keep their Signed-By key, and apt
# still checks each InRelease signature, so a mirror can only serve
# files that the Ubuntu archive key signed. Other sources (Debian,
# snapshot pins, PPAs) are left as they are.
ubuntu_mirror_list=/etc/apt/ubuntu-mirrors.list
ubuntu_archive_re='https?://(([a-z0-9-]+\.)?archive|security|([a-z0-9-]+\.)?ports)\.ubuntu\.com/ubuntu(-ports)?/?'

use_ubuntu_mirror_fallback() {
	[ "${APT_UBUNTU_MIRROR_FALLBACK:-1}" = 1 ] || return 0
	[ "$(id -u)" -eq 0 ] || return 0
	command -v dpkg >/dev/null 2>&1 || return 0

	fb_sources=
	fb_primaries=
	fb_lists=
	for fb_file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list \
		/etc/apt/sources.list.d/*.sources; do
		[ -f "${fb_file}" ] || continue
		# Already set up: apt falls back through the list on its own.
		if grep -qF "mirror+file:${ubuntu_mirror_list}" "${fb_file}"; then
			return 0
		fi
		fb_found=0
		fb_lines=$(grep -v '^[[:space:]]*#' "${fb_file}" || true)
		fb_uris=$(printf '%s\n' "${fb_lines}" |
			grep -oE "${ubuntu_archive_re}" || true)
		for fb_uri in ${fb_uris}; do
			fb_primaries="${fb_primaries} ${fb_uri%/}"
			fb_found=1
		done
		# A mirror list that holds only Ubuntu archive hosts (the GitHub
		# runner image has one) is merged into the new list.
		fb_refs=$(printf '%s\n' "${fb_lines}" |
			grep -oE 'mirror\+file:[^[:space:]]+' || true)
		for fb_ref in ${fb_refs}; do
			fb_path=${fb_ref#mirror+file:}
			[ -f "${fb_path}" ] || continue
			fb_entries=$(awk 'NF && $1 !~ /^#/ { print $1 }' "${fb_path}")
			[ -n "${fb_entries}" ] || continue
			if printf '%s\n' "${fb_entries}" |
				grep -qvxE "${ubuntu_archive_re}"; then
				continue
			fi
			for fb_uri in ${fb_entries}; do
				fb_primaries="${fb_primaries} ${fb_uri%/}"
			done
			fb_lists="${fb_lists} ${fb_path}"
			fb_found=1
		done
		[ "${fb_found}" -eq 0 ] || fb_sources="${fb_sources} ${fb_file}"
	done
	[ -n "${fb_sources}" ] || return 0

	case "$(dpkg --print-architecture)" in
	amd64 | i386)
		fb_fallbacks='http://mirrors.edge.kernel.org/ubuntu
http://mirrors.mit.edu/ubuntu
http://mirrors.ocf.berkeley.edu/ubuntu
http://mirror.math.princeton.edu/pub/ubuntu'
		;;
	*)
		fb_fallbacks='http://mirrors.ocf.berkeley.edu/ubuntu-ports
http://ftp.tu-chemnitz.de/pub/linux/ubuntu-ports
http://mirror.kumi.systems/ubuntu-ports'
		;;
	esac

	fb_up=
	fb_down=
	for fb_uri in ${fb_primaries} ${fb_fallbacks}; do
		case " ${fb_up} ${fb_down} " in
		*" ${fb_uri} "*) continue ;;
		esac
		fb_host=${fb_uri#*://}
		fb_host=${fb_host%%/*}
		if timeout 10 getent hosts "${fb_host}" >/dev/null 2>&1; then
			fb_up="${fb_up} ${fb_uri}"
		else
			fb_down="${fb_down} ${fb_uri}"
		fi
	done

	fb_tmp="${ubuntu_mirror_list}.tmp"
	fb_priority=1
	: >"${fb_tmp}"
	for fb_uri in ${fb_up} ${fb_down}; do
		printf '%s\tpriority:%s\n' "${fb_uri}" "${fb_priority}" >>"${fb_tmp}"
		fb_priority=$((fb_priority + 1))
	done
	chmod 0644 "${fb_tmp}"
	mv "${fb_tmp}" "${ubuntu_mirror_list}"

	for fb_file in ${fb_sources}; do
		sed -i -E "s#${ubuntu_archive_re}#mirror+file:${ubuntu_mirror_list}#g" "${fb_file}"
		for fb_path in ${fb_lists}; do
			sed -i "s#mirror+file:${fb_path}#mirror+file:${ubuntu_mirror_list}#g" "${fb_file}"
		done
	done
	echo "apt mirror order:${fb_up}${fb_down:+ (not resolving now:${fb_down})}" >&2
}

use_ubuntu_mirror_fallback

attempt=1
while true; do
	rc=0
	timeout --kill-after=30 "${attempt_timeout}" \
		apt-get \
		-o Acquire::Retries=0 \
		-o APT::Update::Error-Mode=any \
		"$@" 2>&1 |
		awk -v max="${max_repeats}" '
			++seen[$0] <= max { print; fflush() }
			seen[$0] == max + 1 { print "apt-get-retry: hiding more copies of: " $0; fflush() }
		' || rc=$?

	if [[ "${rc}" -eq 0 ]]; then
		exit 0
	fi

	if [[ "${attempt}" -ge "${attempts}" ]]; then
		echo "apt-get $1 failed with status ${rc} after ${attempt} attempts" >&2
		exit "${rc}"
	fi

	delay=$((attempt * 30))
	echo "apt-get $1 failed with status ${rc} (attempt ${attempt} of ${attempts}); retry in ${delay}s" >&2
	sleep "${delay}"
	attempt=$((attempt + 1))
done
