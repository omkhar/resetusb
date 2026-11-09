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
