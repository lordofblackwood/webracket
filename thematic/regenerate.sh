#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT_DIR="$ROOT_DIR/thematic/generated"
SMOKE_OUT_DIR="$ROOT_DIR/lib/web-easy/smoke/generated"
TEST_OUT_DIR="$ROOT_DIR/pkgs/thematic/test/generated"
RACKET=${RACKET:-racket}
NORMAL_THEMES="superhero sketchy lux sandstone vapor brite quartz morph materia flatly zephyr cyborg"
BOOST_THEMES="lux sandstone"
THEME_FILTER_RAW=${THEMATIC_REGENERATE_THEMES:-${THEMATIC_COMPARE_THEMES:-}}
THEME_FILTER=$(printf '%s\n' "$THEME_FILTER_RAW" | tr ',' ' ')

run_racket_tool() {
  tool=$1
  shift
  "$RACKET" -e '(use-compiled-file-paths null)' -t "$tool" -- "$@"
}

theme_requested() {
  candidate=$1

  if [ -z "$THEME_FILTER" ]; then
    return 0
  fi

  for requested in $THEME_FILTER
  do
    if [ "$requested" = "$candidate" ]; then
      return 0
    fi
  done

  return 1
}

base_theme_for() {
  case "$1" in
    lux-boost)
      printf '%s\n' "lux"
      ;;
    sandstone-boost)
      printf '%s\n' "sandstone"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

bootstrap_theme_requested() {
  candidate=$1

  if [ -z "$THEME_FILTER" ]; then
    return 0
  fi

  for requested in $THEME_FILTER
  do
    if [ "$(base_theme_for "$requested")" = "$candidate" ]; then
      return 0
    fi
  done

  return 1
}

known_regenerate_theme() {
  candidate=$1

  for theme in $NORMAL_THEMES
  do
    if [ "$theme" = "$candidate" ]; then
      return 0
    fi
  done

  for theme in $BOOST_THEMES
  do
    if [ "$theme-boost" = "$candidate" ]; then
      return 0
    fi
  done

  return 1
}

validate_theme_filter() {
  if [ -z "$THEME_FILTER" ]; then
    return 0
  fi

  for requested in $THEME_FILTER
  do
    if ! known_regenerate_theme "$requested"; then
      echo "Unsupported committed Thematic fixture: $requested" >&2
      echo "Use THEMATIC_COMPARE_SKIP_REGENERATE=1 for locally generated external fixtures." >&2
      exit 2
    fi
  done
}

mkdir -p "$OUT_DIR"
mkdir -p "$SMOKE_OUT_DIR"
mkdir -p "$TEST_OUT_DIR"

validate_theme_filter

if [ -n "$THEME_FILTER" ]; then
  echo "Regenerating selected Thematic fixtures: $THEME_FILTER"
else
  echo "Regenerating all committed Thematic fixtures."
fi

for theme in $NORMAL_THEMES
do
  if theme_requested "$theme"; then
    run_racket_tool "$ROOT_DIR/tools/thematic" \
      --input "$ROOT_DIR/thematic/original/$theme/bootstrap.css" \
      --output "$OUT_DIR/$theme.css" \
      --theme-class "we-theme-$theme" \
      --selector ':root'
    cp "$OUT_DIR/$theme.css" "$SMOKE_OUT_DIR/thematic-$theme.css"
    cp "$OUT_DIR/$theme.css" "$TEST_OUT_DIR/thematic-$theme.css"
  fi

  if bootstrap_theme_requested "$theme"; then
    run_racket_tool "$ROOT_DIR/tools/thematic-scope" \
      --input "$ROOT_DIR/thematic/original/$theme/bootstrap.css" \
      --output "$OUT_DIR/bootstrap-$theme-scoped.css" \
      --scope '.bs-preview'
    cp "$OUT_DIR/bootstrap-$theme-scoped.css" "$SMOKE_OUT_DIR/bootstrap-$theme-scoped.css"
    cp "$OUT_DIR/bootstrap-$theme-scoped.css" "$TEST_OUT_DIR/bootstrap-$theme-scoped.css"
  fi
done

for theme in $BOOST_THEMES
do
  if theme_requested "$theme-boost"; then
    run_racket_tool "$ROOT_DIR/tools/thematic" \
      --input "$ROOT_DIR/thematic/original/$theme/bootstrap.css" \
      --output "$OUT_DIR/$theme-boost.css" \
      --theme-class "we-theme-$theme-boost" \
      --selector ':root' \
      --accent-boost
    cp "$OUT_DIR/$theme-boost.css" "$SMOKE_OUT_DIR/thematic-$theme-boost.css"
    cp "$OUT_DIR/$theme-boost.css" "$TEST_OUT_DIR/thematic-$theme-boost.css"
  fi
done
