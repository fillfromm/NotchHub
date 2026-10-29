#!/usr/bin/env python3
"""Claude Code status line: how much of the usage limit is left and when it resets.

Claude Code pipes a JSON document to this script on stdin; for Pro/Max plans it
contains `rate_limits.five_hour` and `rate_limits.seven_day` with `used_percentage`
(0-100) and `resets_at` (Unix seconds). Output is a single line, e.g.

    5h: 72% left, resets in 2h 10m | 7d: 40% left, resets in 3d 4h
"""
import json
import sys
import time


def left_text(window):
    """'72% left, resets in 2h 10m' for one rate-limit window, or None if absent."""
    if not isinstance(window, dict) or "used_percentage" not in window:
        return None
    left = max(0, min(100, round(100 - float(window["used_percentage"]))))
    text = f"{left}% left"
    resets_at = window.get("resets_at")
    if resets_at:
        minutes = max(0, int((float(resets_at) - time.time()) // 60))
        days, rest = divmod(minutes, 1440)
        hours, mins = divmod(rest, 60)
        if days:
            text += f", resets in {days}d {hours}h"
        else:
            text += f", resets in {hours}h {mins:02d}m"
    return text


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return
    limits = data.get("rate_limits") or {}
    parts = []
    for key, label in (("five_hour", "5h"), ("seven_day", "7d")):
        text = left_text(limits.get(key))
        if text:
            parts.append(f"{label}: {text}")
    # The limits only exist for Pro/Max plans and after the first response.
    print(" | ".join(parts) if parts else "limits: waiting for first response")


if __name__ == "__main__":
    main()
