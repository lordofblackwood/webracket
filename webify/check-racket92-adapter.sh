#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_PARENT="$(dirname "$REPO_ROOT")"

RACKET92_BIN="${RACKET92_BIN:-$REPO_ROOT/../racket/racket/bin/racket}"
PLTCOMPILEDROOTS="${PLTCOMPILEDROOTS:-/tmp/webracket-racket92-compiled}"
PLTCOLLECTS_PREFIX="${PLTCOLLECTS_PREFIX:-$REPO_PARENT}"
WEBIFY_RACKET92_CLI_SMOKE="${WEBIFY_RACKET92_CLI_SMOKE:-0}"

if [[ ! -x "$RACKET92_BIN" ]]; then
  echo "Racket executable not found: $RACKET92_BIN" >&2
  echo "Set RACKET92_BIN=/path/to/racket to use a different checkout." >&2
  exit 1
fi

if [[ "$WEBIFY_RACKET92_CLI_SMOKE" == "1" ]]; then
  unset WEBIFY_SKIP_CLI_SMOKE
else
  export WEBIFY_SKIP_CLI_SMOKE=1
fi

PLTCOMPILEDROOTS="$PLTCOMPILEDROOTS" \
PLTCOLLECTS="$PLTCOLLECTS_PREFIX:" \
"$RACKET92_BIN" "$SCRIPT_DIR/test-module-adapter.rkt" \
                "$SCRIPT_DIR/test-module-instance.rkt" \
                "$SCRIPT_DIR/test-module-composer.rkt" \
                "$SCRIPT_DIR/test-module-registry.rkt" \
                "$SCRIPT_DIR/test-module-protocol-racket92.rkt" \
                "$SCRIPT_DIR/test-module-extractor-racket92.rkt"
