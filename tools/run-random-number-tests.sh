#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CS_PATH="${WEBRACKET_RACKET_CS:-/Applications/Racket v9.3.0.2/bin/racket}"
WEBRACKET_RACKET_PATH="${WEBRACKET_RACKET:-}"
DURATION_SECONDS=$((6 * 60 * 60))
SEED=1
COMPLEX_COUNT=20
COMPLEX_CHUNK_SIZE=150
BIGNUM_LIMBS=""
RUN_COMPLEX=1
RUN_BIGNUM=1
LOG_PATH=""

usage() {
  cat <<'USAGE'
Usage: tools/run-random-number-tests.sh [options]

Run WebRacket's randomized number tests against a Racket CS oracle.
The default run lasts for 6 hours, checked between complete test rounds.

Options:
  --hours N              Run for N hours; defaults to 6.
  --seconds N            Run for N seconds instead of using --hours.
  --seed N               Initial exact nonnegative seed; defaults to 1.
  --complex-count N      Samples per complex input family; defaults to 20.
  --complex-chunk-size N Maximum complex cases per generated WebRacket program;
                         defaults to 150.
  --bignum-limbs CSV     Comma-separated bignum limb widths.
  --complex-only         Run only tools/check-complex-random-cs.rkt.
  --bignum-only          Run only tools/check-bignum-mul-random-cs.rkt.
  --cs PATH              Racket CS executable used as the oracle.
  --webracket-racket PATH
                         Racket executable used to compile/run WebRacket.
  --log PATH             Log file; defaults to tmp/random-number-tests-*.log.
  --help                 Show this help.

Examples:
  tools/run-random-number-tests.sh
  tools/run-random-number-tests.sh --hours 6 --complex-count 50
  tools/run-random-number-tests.sh --seconds 300 --seed 12345 --bignum-only
USAGE
}

require_value() {
  local option="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    echo "Missing value for $option" >&2
    exit 2
  fi
}

require_nonnegative_integer() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    echo "$name must be an exact nonnegative integer, got: $value" >&2
    exit 2
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hours)
      require_value "$1" "${2:-}"
      require_nonnegative_integer "$1" "$2"
      DURATION_SECONDS=$((10#$2 * 60 * 60))
      shift 2
      ;;
    --seconds)
      require_value "$1" "${2:-}"
      require_nonnegative_integer "$1" "$2"
      DURATION_SECONDS=$((10#$2))
      shift 2
      ;;
    --seed)
      require_value "$1" "${2:-}"
      require_nonnegative_integer "$1" "$2"
      SEED="$2"
      shift 2
      ;;
    --complex-count)
      require_value "$1" "${2:-}"
      require_nonnegative_integer "$1" "$2"
      COMPLEX_COUNT="$2"
      shift 2
      ;;
    --complex-chunk-size)
      require_value "$1" "${2:-}"
      require_nonnegative_integer "$1" "$2"
      if [ "$2" -eq 0 ]; then
        echo "--complex-chunk-size must be positive" >&2
        exit 2
      fi
      COMPLEX_CHUNK_SIZE="$2"
      shift 2
      ;;
    --bignum-limbs)
      require_value "$1" "${2:-}"
      BIGNUM_LIMBS="$2"
      shift 2
      ;;
    --complex-only)
      RUN_COMPLEX=1
      RUN_BIGNUM=0
      shift
      ;;
    --bignum-only)
      RUN_COMPLEX=0
      RUN_BIGNUM=1
      shift
      ;;
    --cs)
      require_value "$1" "${2:-}"
      CS_PATH="$2"
      shift 2
      ;;
    --webracket-racket)
      require_value "$1" "${2:-}"
      WEBRACKET_RACKET_PATH="$2"
      shift 2
      ;;
    --log)
      require_value "$1" "${2:-}"
      LOG_PATH="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$RUN_COMPLEX" -eq 0 ] && [ "$RUN_BIGNUM" -eq 0 ]; then
  echo "At least one randomized checker must be enabled." >&2
  exit 2
fi

mkdir -p "$ROOT_DIR/tmp"
if [ -z "$LOG_PATH" ]; then
  LOG_PATH="$ROOT_DIR/tmp/random-number-tests-$(date +%Y%m%d-%H%M%S)-$$.log"
fi

cd "$ROOT_DIR"

START_SECONDS="$(date +%s)"
DEADLINE_SECONDS=$((START_SECONDS + DURATION_SECONDS))
CURRENT_SEED="$SEED"
ROUND=1

{
  echo "start=$(date)"
  echo "duration-seconds=$DURATION_SECONDS"
  echo "initial-seed=$SEED"
  echo "cs=$CS_PATH"
  echo "webracket-racket=${WEBRACKET_RACKET_PATH:-auto}"
  echo "complex-count=$COMPLEX_COUNT"
  echo "complex-chunk-size=$COMPLEX_CHUNK_SIZE"
  echo "bignum-limbs=${BIGNUM_LIMBS:-default}"
  echo "log=$LOG_PATH"
  echo
} | tee -a "$LOG_PATH"

WEBRACKET_RACKET_ARGS=()
if [ -n "$WEBRACKET_RACKET_PATH" ]; then
  WEBRACKET_RACKET_ARGS=(--webracket-racket "$WEBRACKET_RACKET_PATH")
fi

run_logged() {
  local label="$1"
  shift
  if ! "$@" >>"$LOG_PATH" 2>&1; then
    echo "$label failed; see $LOG_PATH" | tee -a "$LOG_PATH"
    echo "Last log lines:" >&2
    tail -40 "$LOG_PATH" >&2
    exit 1
  fi
}

while [ "$(date +%s)" -lt "$DEADLINE_SECONDS" ]; do
  echo "round=$ROUND seed=$CURRENT_SEED start=$(date)" | tee -a "$LOG_PATH"

  if [ "$RUN_COMPLEX" -eq 1 ]; then
    run_logged "complex randomized checker" \
      racket tools/check-complex-random-cs.rkt \
      --cs "$CS_PATH" \
      "${WEBRACKET_RACKET_ARGS[@]}" \
      --seed "$CURRENT_SEED" \
      --count "$COMPLEX_COUNT" \
      --chunk-size "$COMPLEX_CHUNK_SIZE"
  fi

  if [ "$RUN_BIGNUM" -eq 1 ]; then
    if [ -n "$BIGNUM_LIMBS" ]; then
      run_logged "bignum multiplication randomized checker" \
        racket tools/check-bignum-mul-random-cs.rkt \
        --cs "$CS_PATH" \
        "${WEBRACKET_RACKET_ARGS[@]}" \
        --seed "$CURRENT_SEED" \
        --limbs "$BIGNUM_LIMBS"
    else
      run_logged "bignum multiplication randomized checker" \
        racket tools/check-bignum-mul-random-cs.rkt \
        --cs "$CS_PATH" \
        "${WEBRACKET_RACKET_ARGS[@]}" \
        --seed "$CURRENT_SEED"
    fi
  fi

  echo "round=$ROUND seed=$CURRENT_SEED pass=$(date)" | tee -a "$LOG_PATH"
  echo | tee -a "$LOG_PATH"

  CURRENT_SEED=$((CURRENT_SEED + 1))
  ROUND=$((ROUND + 1))
done

{
  echo "finished=$(date)"
  echo "rounds-completed=$((ROUND - 1))"
  echo "next-seed=$CURRENT_SEED"
  echo "log=$LOG_PATH"
} | tee -a "$LOG_PATH"
