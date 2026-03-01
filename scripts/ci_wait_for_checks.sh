#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <sha> <timeout_minutes> [contexts_csv]" >&2
  exit 2
fi

sha="$1"
timeout_minutes="$2"
contexts_csv="${3:-}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

repo="${GITHUB_REPOSITORY:-}"
if [[ -z "$repo" ]]; then
  remote_url="$(git config --get remote.origin.url || true)"
  if [[ "$remote_url" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  else
    echo "Unable to determine GitHub repository" >&2
    exit 2
  fi
fi

declare -a wanted_contexts=()
if [[ -n "$contexts_csv" ]]; then
  IFS=',' read -r -a wanted_contexts <<<"$contexts_csv"
fi

deadline=$((SECONDS + timeout_minutes * 60))

echo "Waiting for check runs on $repo@$sha (timeout=${timeout_minutes}m)"
if [[ ${#wanted_contexts[@]} -gt 0 ]]; then
  echo "Required contexts: ${wanted_contexts[*]}"
fi

while true; do
  json="$(gh api -H 'Accept: application/vnd.github+json' "repos/$repo/commits/$sha/check-runs?per_page=100")"

  if [[ ${#wanted_contexts[@]} -gt 0 ]]; then
    filter='[.check_runs[] | select(.name as $n | ($wanted | index($n) != null))]'
    checks="$(jq -c --argjson wanted "$(printf '%s\n' "${wanted_contexts[@]}" | jq -R . | jq -s .)" "$filter" <<<"$json")"
  else
    checks="$(jq -c '[.check_runs[]]' <<<"$json")"
  fi

  total="$(jq 'length' <<<"$checks")"
  completed="$(jq '[.[] | select(.status == "completed")] | length' <<<"$checks")"
  pending="$(jq '[.[] | select(.status != "completed")] | length' <<<"$checks")"
  failed="$(jq '[.[] | select(.status == "completed" and (.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out" or .conclusion == "action_required" or .conclusion == "startup_failure"))] | length' <<<"$checks")"

  if [[ "$failed" -gt 0 ]]; then
    echo "Detected failed check runs:" >&2
    jq -r '.[] | select(.status == "completed" and (.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out" or .conclusion == "action_required" or .conclusion == "startup_failure")) | "- \(.name): \(.conclusion)"' <<<"$checks" >&2
    exit 1
  fi

  if [[ "$total" -gt 0 && "$pending" -eq 0 && "$completed" -eq "$total" ]]; then
    echo "All required checks completed successfully."
    exit 0
  fi

  if (( SECONDS >= deadline )); then
    echo "Timed out waiting for checks (completed=$completed total=$total pending=$pending)" >&2
    exit 1
  fi

  echo "Still waiting... completed=$completed total=$total pending=$pending"
  sleep 20
done
