#!/usr/bin/env python3
"""Inject captured Codex quota data into a configured Claude status line."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Mapping, Optional


COMMAND_ENV = "CLAUDE_CODEX_STATUSLINE_COMMAND"
SNAPSHOT_ENV = "CLAUDE_CODEX_RATE_LIMITS_FILE"


def _statusline(settings_path: Path) -> Optional[dict[str, Any]]:
    try:
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return None
    value = settings.get("statusLine")
    if not isinstance(value, dict) or value.get("type") != "command":
        return None
    if not isinstance(value.get("command"), str) or not value["command"].strip():
        return None
    return value


def configured_command(settings_path: Path) -> str:
    statusline = _statusline(settings_path)
    return "" if statusline is None else statusline["command"]


def settings_override(settings_path: Path, adapter_path: Path) -> str:
    statusline = _statusline(settings_path)
    if statusline is None:
        return ""
    wrapped = dict(statusline)
    wrapped["command"] = shlex.join(["python3", str(adapter_path.resolve())])
    return json.dumps({"statusLine": wrapped}, separators=(",", ":"))


def _valid_windows(snapshot: Mapping[str, Any], now: Optional[int] = None) -> dict[str, Any]:
    current_time = int(time.time()) if now is None else now
    raw_windows = snapshot.get("rate_limits")
    if not isinstance(raw_windows, Mapping):
        return {}

    windows: dict[str, Any] = {}
    for name in ("five_hour", "seven_day"):
        value = raw_windows.get(name)
        if not isinstance(value, Mapping):
            continue
        used = value.get("used_percentage")
        resets_at = value.get("resets_at")
        if not isinstance(used, (int, float)) or isinstance(used, bool):
            continue
        if not isinstance(resets_at, (int, float)) or isinstance(resets_at, bool):
            continue
        if resets_at <= current_time:
            continue
        windows[name] = {
            "used_percentage": min(100.0, max(0.0, float(used))),
            "resets_at": int(resets_at),
        }
    return windows


def inject_snapshot(payload: dict[str, Any], snapshot_path: Optional[Path], now: Optional[int] = None) -> None:
    if snapshot_path is None:
        return
    try:
        snapshot = json.loads(snapshot_path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return
    if not isinstance(snapshot, Mapping):
        return
    windows = _valid_windows(snapshot, now=now)
    if windows:
        payload["rate_limits"] = windows


def run_adapter() -> int:
    command = os.environ.get(COMMAND_ENV, "")
    if not command:
        print(f"Error: {COMMAND_ENV} is not set", file=sys.stderr)
        return 2
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(f"Error: invalid status-line JSON: {exc}", file=sys.stderr)
        return 2
    if not isinstance(payload, dict):
        print("Error: status-line input must be a JSON object", file=sys.stderr)
        return 2

    snapshot_value = os.environ.get(SNAPSHOT_ENV)
    inject_snapshot(payload, Path(snapshot_value) if snapshot_value else None)
    result = subprocess.run(
        command,
        shell=True,
        executable=os.environ.get("SHELL") or "/bin/sh",
        input=json.dumps(payload, separators=(",", ":")),
        text=True,
        check=False,
    )
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--command", type=Path, metavar="SETTINGS")
    group.add_argument("--override", type=Path, metavar="SETTINGS")
    args = parser.parse_args()

    if args.command is not None:
        sys.stdout.write(configured_command(args.command))
        return 0
    if args.override is not None:
        sys.stdout.write(settings_override(args.override, Path(__file__)))
        return 0
    return run_adapter()


if __name__ == "__main__":
    raise SystemExit(main())
