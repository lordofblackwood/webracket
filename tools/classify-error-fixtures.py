#!/usr/bin/env python3
"""Run WebRacket error fixtures and classify generated-output failures.

The focused `test/test-*-errors.rkt` fixtures are meant to prove that bad user
inputs raise catchable Racket exceptions instead of escaping as raw Wasm/JS
traps. This harness compiles and runs those fixtures through `webracket.rkt`,
using `tools/run-guarded.py` for timeout/RSS protection, and then classifies the
result for audit work.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


REPO = Path(__file__).resolve().parents[1]
DEFAULT_TMP_ROOT = Path("/tmp")
DEFAULT_FIXTURE_GLOB = "test/test-*-errors.rkt"


def existing_racket() -> str:
    configured = os.environ.get("WEBRACKET_RACKET")
    if configured:
        return configured
    app_racket = Path("/Applications/Racket v9.2.0.2/bin/racket")
    if app_racket.exists():
        return str(app_racket)
    return shutil.which("racket") or "racket"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compile/run WebRacket error fixtures and classify failures."
    )
    parser.add_argument(
        "fixtures",
        nargs="*",
        help="Fixture files to run. Defaults to test/test-*-errors.rkt.",
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=1,
        help="Number of fixtures to run in parallel.",
    )
    parser.add_argument(
        "--timeout-sec",
        type=float,
        default=720.0,
        help="Per-fixture timeout passed to tools/run-guarded.py.",
    )
    parser.add_argument(
        "--rss-limit-mb",
        type=float,
        default=4096.0,
        help="Per-fixture RSS limit passed to tools/run-guarded.py.",
    )
    parser.add_argument(
        "--tmp-root",
        type=Path,
        default=DEFAULT_TMP_ROOT,
        help="Root directory for generated outputs and logs.",
    )
    parser.add_argument(
        "--racket",
        default=existing_racket(),
        help="Racket executable to use. Defaults to WEBRACKET_RACKET, the local app Racket if present, then racket on PATH.",
    )
    parser.add_argument(
        "--webracket",
        type=Path,
        default=REPO / "webracket.rkt",
        help="Path to webracket.rkt.",
    )
    parser.add_argument(
        "--stdlib",
        dest="no_stdlib",
        action="store_false",
        default=True,
        help="Do not pass --no-stdlib to webracket.rkt.",
    )
    parser.add_argument(
        "--extra-flag",
        action="append",
        default=[],
        help="Additional flag to pass to webracket.rkt; repeatable.",
    )
    parser.add_argument(
        "--list-fixtures",
        action="store_true",
        help="Print selected fixtures and exit.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands without running them.",
    )
    return parser.parse_args()


def selected_fixtures(args: argparse.Namespace) -> list[Path]:
    if args.fixtures:
        fixtures = [Path(f) for f in args.fixtures]
    else:
        fixtures = sorted(REPO.glob(DEFAULT_FIXTURE_GLOB))
    result: list[Path] = []
    for fixture in fixtures:
        path = fixture if fixture.is_absolute() else REPO / fixture
        result.append(path.resolve())
    return result


def fixture_id(path: Path) -> str:
    rel = path.relative_to(REPO) if path.is_relative_to(REPO) else path
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", str(rel))


def command_for(
    args: argparse.Namespace, fixture: Path, run_root: Path
) -> tuple[list[str], Path, Path]:
    name = fixture_id(fixture)
    dest = run_root / "out" / name
    compiled = run_root / "compiled" / name
    cmd = [
        sys.executable,
        str(REPO / "tools" / "run-guarded.py"),
        "--timeout-sec",
        str(args.timeout_sec),
        "--rss-limit-mb",
        str(args.rss_limit_mb),
        "--",
        "/usr/bin/env",
        f"PLTCOMPILEDROOTS={compiled}",
        args.racket,
        str(args.webracket),
    ]
    if args.no_stdlib:
        cmd.append("--no-stdlib")
    cmd.extend(args.extra_flag)
    cmd.extend(["--dest", str(dest), "-r", str(fixture)])
    return cmd, dest, compiled


def classify(returncode: int, stdout: str, stderr: str) -> tuple[str, str]:
    text = stdout + "\n" + stderr
    lowered = text.lower()
    if returncode == 0:
        if re.search(r"\([^()]*\s#f\)", stdout):
            return "fixture-failure", "fixture printed at least one failing #f row"
        return "pass", "all fixture rows passed"
    if "guarded-run: killed for timeout" in lowered:
        return "guard-timeout", "guarded runner stopped the command for timeout"
    if "guarded-run: killed for rss limit" in lowered:
        return "guard-memory", "guarded runner stopped the command for RSS limit"
    if "exn:fail:unsupported" in lowered or "unsupported" in lowered:
        return "uncaught-unsupported", "unsupported exception escaped the fixture"
    if (
        "runtimeerror" in lowered
        or "unreachable" in lowered
        or "illegal cast" in lowered
        or "null function" in lowered
        or "wasm trap" in lowered
        or "trap" in lowered
    ):
        return "raw-wasm-js-trap", "raw Wasm/JS runtime failure escaped"
    if (
        "compileerror" in lowered
        or "linkerror" in lowered
        or "wasm validation" in lowered
        or "validation failed" in lowered
        or "assembler" in lowered
    ):
        return "compile-or-link-failure", "compile, validation, or link failure"
    if "exn:fail" in lowered or "contract violation" in lowered:
        return "uncaught-racket-exn", "Racket exception escaped the fixture"
    return "process-failure", f"process exited with status {returncode}"


def run_fixture(args: argparse.Namespace, fixture: Path, run_root: Path) -> dict[str, str]:
    cmd, _dest, _compiled = command_for(args, fixture, run_root)
    rel = str(fixture.relative_to(REPO) if fixture.is_relative_to(REPO) else fixture)
    if args.dry_run:
        return {
            "fixture": rel,
            "status": "dry-run",
            "detail": " ".join(cmd),
            "log": "",
        }
    proc = subprocess.run(
        cmd,
        cwd=REPO,
        capture_output=True,
        text=True,
        timeout=args.timeout_sec + 60.0,
    )
    status, detail = classify(proc.returncode, proc.stdout, proc.stderr)
    log_dir = run_root / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / f"{fixture_id(fixture)}.log"
    log_path.write_text(
        "COMMAND\n"
        + " ".join(cmd)
        + "\n\nSTDOUT\n"
        + proc.stdout
        + "\n\nSTDERR\n"
        + proc.stderr,
        encoding="utf-8",
    )
    return {
        "fixture": rel,
        "status": status,
        "detail": detail,
        "log": str(log_path),
    }


def print_markdown(rows: list[dict[str, str]]) -> None:
    print("| fixture | status | detail | log |")
    print("| --- | --- | --- | --- |")
    for row in rows:
        log = row["log"] if row["log"] else ""
        print(
            f"| `{row['fixture']}` | `{row['status']}` | {row['detail']} | `{log}` |"
        )


def main() -> int:
    args = parse_args()
    if args.jobs < 1:
        raise SystemExit("--jobs must be at least 1")
    fixtures = selected_fixtures(args)
    if args.list_fixtures:
        for fixture in fixtures:
            print(fixture.relative_to(REPO) if fixture.is_relative_to(REPO) else fixture)
        return 0
    stamp = time.strftime("%Y%m%d-%H%M%S")
    run_root = args.tmp_root / f"webracket-error-fixture-audit-{stamp}"
    run_root.mkdir(parents=True, exist_ok=True)
    if args.dry_run:
        rows = [run_fixture(args, fixture, run_root) for fixture in fixtures]
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = [pool.submit(run_fixture, args, fixture, run_root) for fixture in fixtures]
            rows = [future.result() for future in futures]
    rows.sort(key=lambda row: row["fixture"])
    print(f"run-root: `{run_root}`")
    print()
    print_markdown(rows)
    failing = [row for row in rows if row["status"] not in {"pass", "dry-run"}]
    return 1 if failing and not args.dry_run else 0


if __name__ == "__main__":
    raise SystemExit(main())
