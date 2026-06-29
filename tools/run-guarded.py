#!/usr/bin/env python3
"""Run a command with timeout and RSS guardrails.

This helper is meant for long-running local compiler/test commands on macOS
where `ulimit`/`setrlimit` memory caps are unreliable. It polls the child RSS
with `ps` and kills the process if it exceeds a configured threshold.
"""

from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
import time


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a command with timeout and RSS guardrails."
    )
    parser.add_argument(
        "--timeout-sec",
        type=float,
        default=300.0,
        help="Kill the command if it runs longer than this many seconds.",
    )
    parser.add_argument(
        "--rss-limit-mb",
        type=float,
        default=None,
        help="Kill the command if resident memory exceeds this many MB.",
    )
    parser.add_argument(
        "--poll-sec",
        type=float,
        default=1.0,
        help="How often to poll the process.",
    )
    parser.add_argument(
        "cmd",
        nargs=argparse.REMAINDER,
        help="Command to run. Prefix with -- to stop option parsing.",
    )
    args = parser.parse_args()
    if args.cmd and args.cmd[0] == "--":
        args.cmd = args.cmd[1:]
    if not args.cmd:
        parser.error("missing command; pass it after --")
    return args


def process_rss_mb(pid: int) -> float | None:
    try:
        proc = subprocess.run(
            ["ps", "-o", "rss=", "-p", str(pid)],
            check=True,
            capture_output=True,
            text=True,
        )
    except Exception:
        return None
    text = proc.stdout.strip()
    if not text:
        return None
    try:
        rss_kb = int(text.splitlines()[-1].strip())
    except ValueError:
        return None
    return rss_kb / 1024.0


def process_group_rss_mb(pgid: int) -> float | None:
    try:
        proc = subprocess.run(
            ["ps", "-axo", "pgid=,rss="],
            check=True,
            capture_output=True,
            text=True,
        )
    except Exception:
        return None
    total_kb = 0
    found = False
    for line in proc.stdout.splitlines():
        fields = line.split()
        if len(fields) != 2:
            continue
        try:
            row_pgid = int(fields[0])
            row_rss_kb = int(fields[1])
        except ValueError:
            continue
        if row_pgid == pgid:
            found = True
            total_kb += row_rss_kb
    if not found:
        return None
    return total_kb / 1024.0


def rss_mb(pid: int) -> float | None:
    return process_group_rss_mb(pid) or process_rss_mb(pid)


def terminate_process_group(proc: subprocess.Popen[bytes], reason: str) -> int:
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        return proc.wait(timeout=5.0)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        return proc.wait()
    finally:
        print(reason, file=sys.stderr)


def main() -> int:
    args = parse_args()
    start = time.monotonic()
    proc = subprocess.Popen(args.cmd, preexec_fn=os.setsid)
    peak_rss = 0.0
    rss_probe_failed = False
    while True:
        status = proc.poll()
        if status is not None:
            if args.rss_limit_mb is not None:
                if rss_probe_failed:
                    print(
                        "guarded-run: RSS polling unavailable; timeout guard only",
                        file=sys.stderr,
                    )
                print(f"guarded-run: peak-rss={peak_rss:.1f}MB", file=sys.stderr)
            return status

        elapsed = time.monotonic() - start
        current_rss = rss_mb(proc.pid)
        if current_rss is None and args.rss_limit_mb is not None:
            rss_probe_failed = True
        if current_rss is not None:
            peak_rss = max(peak_rss, current_rss)
            if args.rss_limit_mb is not None and current_rss > args.rss_limit_mb:
                return terminate_process_group(
                    proc,
                    (
                        "guarded-run: killed for RSS limit "
                        f"({current_rss:.1f}MB > {args.rss_limit_mb:.1f}MB)"
                    ),
                )

        if elapsed > args.timeout_sec:
            return terminate_process_group(
                proc,
                f"guarded-run: killed for timeout ({elapsed:.1f}s > {args.timeout_sec:.1f}s)",
            )

        time.sleep(args.poll_sec)


if __name__ == "__main__":
    raise SystemExit(main())
