#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "resetusb perf benchmark is Linux-only"
  exit 0
fi

make
/usr/bin/time -p ./resetusb || true
