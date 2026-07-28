#!/usr/bin/env python3
"""Read the authenticated Codex plan quota through its local app-server API."""

import json
import math
import os
import select
import subprocess
import sys
import time


TIMEOUT_SECONDS = 15


def send(process, payload):
    process.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
    process.stdin.flush()


def response_for(process, request_id, deadline):
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("Codex app-server response timed out")

        ready, _, _ = select.select([process.stdout], [], [], remaining)
        if not ready:
            raise TimeoutError("Codex app-server response timed out")

        line = process.stdout.readline()
        if not line:
            raise RuntimeError("Codex app-server closed stdout")

        message = json.loads(line)
        if message.get("id") != request_id:
            continue
        if "error" in message:
            raise RuntimeError(str(message["error"]))
        return message["result"]


def main():
    process = subprocess.Popen(
        [os.environ.get("CODEX_BIN", "codex"), "app-server", "--stdio"],
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
                "params": {"clientInfo": {"name": "sketchybar-usage", "version": "1"}},
            },
        )
        response_for(process, 1, deadline)
        send(process, {"method": "initialized", "params": {}})
        send(process, {"id": 2, "method": "account/rateLimits/read", "params": None})
        result = response_for(process, 2, deadline)

        rate_limits = result["rateLimits"]
        five_hour = rate_limits["primary"]["usedPercent"]
        weekly = rate_limits["secondary"]["usedPercent"]
        for value in (five_hour, weekly):
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                raise ValueError("Codex usage is not numeric")
            if not math.isfinite(value) or value < 0 or value > 100:
                raise ValueError("Codex usage is outside 0-100")
        print(f"{round(five_hour)} {round(weekly)}")
    finally:
        process.terminate()
        try:
            process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        sys.exit(1)
