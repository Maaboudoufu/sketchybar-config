#!/usr/bin/env python3
"""Read the authenticated Codex plan quota through its local app-server API."""

import json
import math
import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path


TIMEOUT_SECONDS = 15
FIVE_HOUR_WINDOW_MINS = 300
WEEKLY_WINDOW_MINS = 10080


def send(process, payload):
    process.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
    process.stdin.flush()


def _expire(*_):
    raise TimeoutError("Codex app-server response timed out")


def response_for(process, request_id, deadline):
    # The timeout has to bound the blocking readline itself, not a select() on
    # the fd: process.stdout is buffered, so one readline pulls the whole
    # pending chunk into memory. The real app-server does coalesce an async
    # notification and the result we want into a single write — select would
    # then see an empty fd and block out the full timeout with the answer
    # already sitting in the buffer.
    signal.signal(signal.SIGALRM, _expire)
    while True:
        signal.setitimer(signal.ITIMER_REAL, max(deadline - time.monotonic(), 0.001))
        try:
            line = process.stdout.readline()
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)

        if not line:
            raise RuntimeError("Codex app-server closed stdout")

        message = json.loads(line)
        if message.get("id") != request_id:
            continue
        if "error" in message:
            raise RuntimeError(str(message["error"]))
        return message["result"]


def is_percentage(value):
    return (
        not isinstance(value, bool)
        and isinstance(value, (int, float))
        and math.isfinite(value)
        and 0 <= value <= 100
    )


def usage_for_windows(rate_limits):
    values = {FIVE_HOUR_WINDOW_MINS: None, WEEKLY_WINDOW_MINS: None}
    for name in ("primary", "secondary"):
        window = rate_limits.get(name)
        if not isinstance(window, dict):
            continue

        minutes = window.get("windowDurationMins", window.get("window_minutes"))
        used = window.get("usedPercent", window.get("used_percent"))
        # An already-reset window carries a percentage that no longer applies.
        # The session fallback reads files up to weeks old, so without this a
        # long-expired 17% renders as if it were the current quota.
        resets = window.get("resetsAt", window.get("resets_at"))
        if minutes in values and is_percentage(used) and not (resets and resets < time.time()):
            values[minutes] = round(used)

    return values[FIVE_HOUR_WINDOW_MINS], values[WEEKLY_WINDOW_MINS]


def codex_bin():
    if configured := os.environ.get("CODEX_BIN"):
        return configured

    for candidate in (
        shutil.which("codex"),
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex",
    ):
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return "codex"


def live_usage():
    process = subprocess.Popen(
        [codex_bin(), "app-server", "--stdio"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )
    try:
        deadline = time.monotonic() + TIMEOUT_SECONDS
        send(
            process,
            {
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": {"name": "sketchybar-usage", "version": "1"},
                    "capabilities": {"experimentalApi": True},
                },
            },
        )
        response_for(process, 1, deadline)
        send(process, {"method": "initialized", "params": {}})
        send(process, {"id": 2, "method": "account/rateLimits/read", "params": None})
        result = response_for(process, 2, deadline)

        rate_limits = result.get("rateLimits") if isinstance(result, dict) else None
        if not isinstance(rate_limits, dict):
            return None
        return usage_for_windows(rate_limits)
    finally:
        process.terminate()
        try:
            process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def recent_session_usage():
    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    sessions_dir = codex_home / "sessions"
    try:
        sessions = sorted(
            sessions_dir.rglob("*.jsonl"),
            key=lambda path: path.stat().st_mtime,
            reverse=True,
        )
    except OSError:
        return None

    for path in sessions[:20]:
        newest = None
        try:
            with path.open(encoding="utf-8") as session:
                for line in session:
                    message = json.loads(line)
                    payload = message.get("payload")
                    rate_limits = payload.get("rate_limits") if isinstance(payload, dict) else None
                    if isinstance(rate_limits, dict):
                        values = usage_for_windows(rate_limits)
                        if any(value is not None for value in values):
                            newest = values
        except (OSError, json.JSONDecodeError):
            continue
        if newest is not None:
            return newest
    return None


def main():
    # Every realistic live failure *raises* — codex not on sketchybar's PATH,
    # an expired token coming back as a JSON-RPC error, a timeout. Testing the
    # return value alone let those escape to the top-level handler, so the
    # session fallback below only ever ran for the one case that returned None.
    # A (None, None) tuple is truthy too, which skipped it just as quietly.
    try:
        usage = live_usage()
    except Exception:
        usage = None
    if not usage or not any(value is not None for value in usage):
        usage = recent_session_usage()
    if usage is None:
        raise RuntimeError("Codex usage is unavailable")

    five_hour, weekly = usage
    print(f"{five_hour if five_hour is not None else '-'} {weekly if weekly is not None else '-'}")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        sys.exit(1)
