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

in_jobs=0
in_steps=0
step_active=0
current_job=""
current_job_index=0
seen_jobs="|"
seen_jobs_root=0
seen_steps=0
seen_step_keys="|"
step_index=0
job_execution_controls="|"
step_execution_controls="|"
unsafe_step_inputs="|"
in_step_with=0
seen_with_keys="|"
line_number=0
block_scalar_indent=-1
init_count=0
analyze_count=0
global_init_count=0
global_analyze_count=0
invalid_ref=0
init_ref=""
analyze_ref=""
init_job=""
analyze_job=""
init_job_index=0
analyze_job_index=0
init_step=0
analyze_step=0

trim() {
	local value="$1"
	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"
	REPLY="${value}"
}

count_codeql_literals() {
	local original="$1"
	local value=""
	local marker=""
	original="$(printf '%s' "${original}" | LC_ALL=C tr '[:upper:]' '[:lower:]')"

	for marker in "github/codeql-action/init@" "github/codeql-action/analyze@"; do
		value="${original}"
		while [[ "${value}" == *"${marker}"* ]]; do
			if [[ "${marker}" == "github/codeql-action/init@" ]]; then
				global_init_count=$((global_init_count + 1))
			else
				global_analyze_count=$((global_analyze_count + 1))
			fi
			value="${value#*"${marker}"}"
		done
	done
}

record_step_use() {
	local value="$1"
	local action=""
	local ref=""
	local lower_value=""

	if [[ "${value}" =~ ^(.*)[[:space:]]+#.*$ ]]; then
		value="${BASH_REMATCH[1]}"
	fi
	trim "${value}"
	value="${REPLY}"
	if [[ "${value}" =~ ^[\|\>][0-9+-]*$ ]]; then
		echo "CodeQL workflow uses values must not use block scalars" >&2
		exit 1
	fi

	if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
		value="${value:1:${#value}-2}"
		if [[ "${value}" == *\\* ]]; then
			echo "CodeQL workflow uses values must not contain YAML escapes" >&2
			exit 1
		fi
	elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
		value="${value:1:${#value}-2}"
	fi
	lower_value="$(printf '%s' "${value}" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
	case "${lower_value}" in
	github/codeql-action/init@* | github/codeql-action/analyze@*)
		if [[ "${value}" != "${lower_value}" ]]; then
			echo "CodeQL action names must use canonical lowercase spelling" >&2
			exit 1
		fi
		;;
	esac

	case "${value}" in
	github/codeql-action/init@*)
		action="init"
		ref="${value#github/codeql-action/init@}"
		init_count=$((init_count + 1))
		;;
	github/codeql-action/analyze@*)
		action="analyze"
		ref="${value#github/codeql-action/analyze@}"
		analyze_count=$((analyze_count + 1))
		;;
	*)
		return
		;;
	esac

	if [[ "${#ref}" -ne 40 || ! "${ref}" =~ ^[0-9a-f]+$ ]]; then
		invalid_ref=1
		return
	fi

	if [[ "${action}" == "init" ]]; then
		init_ref="${ref}"
		init_job="${current_job}"
		init_job_index="${current_job_index}"
		init_step="${step_index}"
	else
		analyze_ref="${ref}"
		analyze_job="${current_job}"
		analyze_job_index="${current_job_index}"
		analyze_step="${step_index}"
	fi
}

while IFS= read -r line || [[ -n "${line}" ]]; do
	line_number=$((line_number + 1))

	if [[ "${line}" == *$'\t'* ]]; then
		echo "CodeQL workflow must use spaces for indentation (line ${line_number})" >&2
		exit 1
	fi
	leading="${line%%[^ ]*}"
	indent="${#leading}"
	content="${line:${indent}}"
	if [[ "${block_scalar_indent}" -ge 0 ]]; then
		if [[ "${line}" =~ ^[[:space:]]*$ || "${indent}" -gt "${block_scalar_indent}" ]]; then
			continue
		fi
		block_scalar_indent=-1
	fi
	if [[ "${line}" =~ ^[[:space:]]*$ ]]; then
		continue
	fi
	if [[ "${content}" == \#* ]]; then
		continue
	fi
	if [[ "${content}" == *\\* ]]; then
		echo "CodeQL workflow must not use YAML escapes in structural content (line ${line_number})" >&2
		exit 1
	fi

	count_codeql_literals "${content}"
	anchor_alias_pattern='(^|[[:space:]:,]|\{|\[)[&*][^][&*[:space:]{},][^][[:space:]{},]*'
	if [[ "${content}" =~ ${anchor_alias_pattern} ]]; then
		echo "CodeQL workflow must not use YAML anchors or aliases (line ${line_number})" >&2
		exit 1
	fi
	if [[ "${content}" =~ ^(-[[:space:]]+)?[A-Za-z_][A-Za-z0-9_-]*:[[:space:]]*[\|\>][0-9+-]*[[:space:]]*(#.*)?$ ]]; then
		block_scalar_indent="${indent}"
	fi

	if [[ "${indent}" -eq 0 ]]; then
		in_steps=0
		step_active=0
		in_step_with=0
		current_job=""
		if [[ "${content}" =~ ^jobs:[[:space:]]*(#.*)?$ ]]; then
			seen_jobs_root=$((seen_jobs_root + 1))
			if [[ "${seen_jobs_root}" -ne 1 ]]; then
				echo "CodeQL workflow contains duplicate top-level jobs mappings" >&2
				exit 1
			fi
			in_jobs=1
		else
			in_jobs=0
		fi
		continue
	fi

	if [[ "${in_jobs}" -ne 1 ]]; then
		continue
	fi

	if [[ "${indent}" -eq 2 ]]; then
		in_steps=0
		step_active=0
		in_step_with=0
		current_job=""
		seen_steps=0
		if [[ ! "${content}" =~ ^([A-Za-z_][A-Za-z0-9_-]*):[[:space:]]*(#.*)?$ ]]; then
			echo "CodeQL workflow contains an unsupported job declaration on line ${line_number}" >&2
			exit 1
		fi
		current_job="${BASH_REMATCH[1]}"
		if [[ "${seen_jobs}" == *"|${current_job}|"* ]]; then
			echo "CodeQL workflow contains duplicate job ${current_job}" >&2
			exit 1
		fi
		seen_jobs+="${current_job}|"
		current_job_index=$((current_job_index + 1))
		continue
	fi

	if [[ -z "${current_job}" ]]; then
		continue
	fi

	if [[ "${indent}" -eq 4 ]]; then
		step_active=0
		in_step_with=0
		if [[ ! "${content}" =~ ^([A-Za-z_][A-Za-z0-9_-]*):[[:space:]]*.*$ ]]; then
			echo "CodeQL workflow contains an unsupported job key on line ${line_number}" >&2
			exit 1
		fi
		job_key="${BASH_REMATCH[1]}"
		if [[ "${job_key}" == "if" || "${job_key}" == "continue-on-error" || "${job_key}" == "needs" ]]; then
			job_execution_controls+="${current_job_index}|"
		fi
		if [[ "${content}" =~ ^steps:[[:space:]]*(#.*)?$ ]]; then
			if [[ "${seen_steps}" -ne 0 ]]; then
				echo "CodeQL workflow contains duplicate steps mappings in job ${current_job}" >&2
				exit 1
			fi
			seen_steps=1
			in_steps=1
			step_index=0
		else
			in_steps=0
		fi
		continue
	fi

	if [[ "${in_steps}" -ne 1 ]]; then
		continue
	fi
	if [[ "${content}" =~ ^-[[:space:]]+ && "${indent}" -ne 6 ]]; then
		echo "CodeQL workflow contains an unsupported step indentation on line ${line_number}" >&2
		exit 1
	fi

	if [[ "${indent}" -eq 6 ]]; then
		step_active=0
		in_step_with=0
		seen_step_keys="|"
		seen_with_keys="|"
		if [[ "${content}" =~ ^-[[:space:]]+(.+)$ ]]; then
			step_index=$((step_index + 1))
			step_active=1
			item="${BASH_REMATCH[1]}"
			if [[ ! "${item}" =~ ^([A-Za-z_][A-Za-z0-9_-]*):[[:space:]]*(.*)$ ]]; then
				echo "CodeQL workflow contains an unsupported step declaration on line ${line_number}" >&2
				exit 1
			fi
			step_key="${BASH_REMATCH[1]}"
			step_value="${BASH_REMATCH[2]}"
			seen_step_keys+="${step_key}|"
			if [[ "${step_key}" == "if" || "${step_key}" == "continue-on-error" ]]; then
				step_execution_controls+="${current_job_index}:${step_index}|"
			fi
			if [[ "${step_key}" == "uses" ]]; then
				record_step_use "${step_value}"
			elif [[ "${step_key}" == "with" ]]; then
				trim "${step_value}"
				if [[ -n "${REPLY}" && "${REPLY}" != \#* ]]; then
					echo "CodeQL step with values must use a block mapping" >&2
					exit 1
				fi
				in_step_with=1
			fi
		else
			echo "CodeQL workflow contains an unsupported steps entry on line ${line_number}" >&2
			exit 1
		fi
		continue
	fi

	if [[ "${indent}" -eq 8 && "${step_active}" -eq 1 ]]; then
		in_step_with=0
		seen_with_keys="|"
		if [[ ! "${content}" =~ ^([A-Za-z_][A-Za-z0-9_-]*):[[:space:]]*(.*)$ ]]; then
			echo "CodeQL workflow contains an unsupported step key on line ${line_number}" >&2
			exit 1
		fi
		step_key="${BASH_REMATCH[1]}"
		step_value="${BASH_REMATCH[2]}"
		if [[ "${seen_step_keys}" == *"|${step_key}|"* ]]; then
			echo "CodeQL workflow contains duplicate step key ${step_key} on line ${line_number}" >&2
			exit 1
		fi
		seen_step_keys+="${step_key}|"
		if [[ "${step_key}" == "if" || "${step_key}" == "continue-on-error" ]]; then
			step_execution_controls+="${current_job_index}:${step_index}|"
		fi
		if [[ "${step_key}" == "uses" ]]; then
			record_step_use "${step_value}"
		elif [[ "${step_key}" == "with" ]]; then
			trim "${step_value}"
			if [[ -n "${REPLY}" && "${REPLY}" != \#* ]]; then
				echo "CodeQL step with values must use a block mapping" >&2
				exit 1
			fi
			in_step_with=1
		fi
		continue
	fi

	if [[ "${indent}" -eq 10 && "${step_active}" -eq 1 && "${in_step_with}" -eq 1 ]]; then
		if [[ ! "${content}" =~ ^([A-Za-z_][A-Za-z0-9_-]*):[[:space:]]*(.*)$ ]]; then
			echo "CodeQL workflow contains an unsupported with key on line ${line_number}" >&2
			exit 1
		fi
		with_key="${BASH_REMATCH[1]}"
		with_value="${BASH_REMATCH[2]}"
		if [[ "${seen_with_keys}" == *"|${with_key}|"* ]]; then
			echo "CodeQL workflow contains duplicate with key ${with_key}" >&2
			exit 1
		fi
		seen_with_keys+="${with_key}|"
		if [[ "${with_value}" =~ ^(.*)[[:space:]]+#.*$ ]]; then
			with_value="${BASH_REMATCH[1]}"
		fi
		trim "${with_value}"
		with_value="${REPLY}"
		if [[ "${with_value}" == \"*\" && "${with_value}" == *\" ]] ||
			[[ "${with_value}" == \'*\' && "${with_value}" == *\' ]]; then
			with_value="${with_value:1:${#with_value}-2}"
		fi
		with_value_lower="$(printf '%s' "${with_value}" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
		if [[ ("${with_key}" == "skip-queries" && "${with_value_lower}" != "false") ||
			("${with_key}" == "upload" && "${with_value}" != "always") ]]; then
			unsafe_step_inputs+="${current_job_index}:${step_index}|"
		fi
	fi
done <"${workflow}"

if [[ "${global_init_count}" -ne "${init_count}" || "${global_analyze_count}" -ne "${analyze_count}" ]]; then
	echo "Every CodeQL init and analyze invocation must use a canonical executable uses step" >&2
	exit 1
fi

if [[ "${init_count}" -ne 1 || "${analyze_count}" -ne 1 ]]; then
	echo "CodeQL workflow must contain exactly one executable init step and one executable analyze step" >&2
	exit 1
fi

if [[ "${invalid_ref}" -ne 0 || -z "${init_ref}" || -z "${analyze_ref}" ]]; then
	echo "CodeQL init and analyze must use exact 40-character lowercase commit revisions" >&2
	exit 1
fi

if [[ "${init_ref}" != "${analyze_ref}" ]]; then
	echo "CodeQL init and analyze must use the same immutable revision" >&2
	exit 1
fi

if [[ "${init_job_index}" -ne "${analyze_job_index}" || "${init_job}" != "${analyze_job}" ]]; then
	echo "CodeQL init and analyze must be steps in the same job" >&2
	exit 1
fi

if [[ "${job_execution_controls}" == *"|${init_job_index}|"* ]]; then
	echo "The CodeQL job must not use conditions, ignored failures, or dependencies" >&2
	exit 1
fi

if [[ "${step_execution_controls}" == *"|${init_job_index}:${init_step}|"* ||
	"${step_execution_controls}" == *"|${analyze_job_index}:${analyze_step}|"* ]]; then
	echo "CodeQL init and analyze steps must not use if or continue-on-error" >&2
	exit 1
fi

if [[ "${unsafe_step_inputs}" == *"|${analyze_job_index}:${analyze_step}|"* ]]; then
	echo "CodeQL analyze must run queries and upload results" >&2
	exit 1
fi

if [[ "${init_step}" -ge "${analyze_step}" ]]; then
	echo "CodeQL init must occur before CodeQL analyze" >&2
	exit 1
fi
