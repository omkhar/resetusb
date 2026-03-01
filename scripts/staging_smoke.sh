#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "resetusb staging smoke is Linux-only"
  exit 0
fi

if [[ ! -x ./resetusb ]]; then
  make
fi

if [[ "$EUID" -ne 0 ]]; then
  sudo ./resetusb
else
  ./resetusb
fi
