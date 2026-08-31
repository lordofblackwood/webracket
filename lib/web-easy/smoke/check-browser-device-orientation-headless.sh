#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SMOKE_DEVICE_ORIENTATION_FAKE=1 \
  "$SCRIPT_DIR/check-single-headless.sh" \
  run-browser-device-orientation-compile.sh \
  test-browser-device-orientation.html
