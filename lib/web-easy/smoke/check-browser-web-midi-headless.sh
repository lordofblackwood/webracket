#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SMOKE_WEB_MIDI_FAKE=1 \
  "$SCRIPT_DIR/check-single-headless.sh" \
  run-browser-web-midi-compile.sh \
  test-browser-web-midi.html
