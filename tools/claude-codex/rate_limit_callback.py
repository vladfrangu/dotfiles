"""Persist ChatGPT/Codex quota windows for the Claude Code status line."""

from __future__ import annotations

import json
import math
import os
import tempfile
import time
from pathlib import Path
from typing import Any, Mapping, Optional

from litellm.integrations.custom_logger import CustomLogger


DATA_DIR_ENV = "CLAUDE_CODEX_DATA_DIR"
SNAPSHOT_NAME = "rate-limits.json"
HEADER_PREFIX = "x-codex-"
PROVIDER_PREFIX = "llm_provider-"
USAGE_REFRESH_SECONDS = 30


def _hidden_params(response: Any) -> Mapping[str, Any]:
    if isinstance(response, Mapping):
        value = response.get("_hidden_params", {})
    else:
        value = getattr(response, "_hidden_params", {})
    return value if isinstance(value, Mapping) else {}


def _response_headers(response: Any) -> dict[str, Any]:
    """Return upstream response headers with LiteLLM's provider prefix removed."""
    hidden = _hidden_params(response)
    combined: dict[str, Any] = {}
    for source_name in ("headers", "additional_headers"):
        source = hidden.get(source_name, {})
        if not isinstance(source, Mapping):
            continue
        for raw_key, value in source.items():
            key = str(raw_key).lower()
            if key.startswith(PROVIDER_PREFIX):
                key = key[len(PROVIDER_PREFIX) :]
            combined[key] = value
    return combined


def _number(value: Any) -> Optional[float]:
    try:
        result = float(value)
    except (TypeError, ValueError):
        return None
    return result if math.isfinite(result) else None


def _window_name(minutes: float) -> Optional[str]:
    # Codex can expose only one window and can put the weekly window in
    # `primary`, so the position is not meaningful. Allow small rounding
    # differences while still refusing to mislabel an unknown quota window.
    if 240 <= minutes <= 360:
        return "five_hour"
    if 9_900 <= minutes <= 10_200:
        return "seven_day"
    return None


def quota_snapshot(headers: Mapping[str, Any], now: Optional[int] = None) -> Optional[dict[str, Any]]:
    """Normalize x-codex quota headers into Claude status-line-shaped data."""
    normalized = {str(key).lower(): value for key, value in headers.items()}
    windows: dict[str, dict[str, Any]] = {}

    for position in ("primary", "secondary"):
        prefix = f"{HEADER_PREFIX}{position}-"
        used = _number(normalized.get(f"{prefix}used-percent"))
        minutes = _number(normalized.get(f"{prefix}window-minutes"))
        resets_at = _number(normalized.get(f"{prefix}reset-at"))
        if used is None or minutes is None or resets_at is None:
            continue

        name = _window_name(minutes)
        if name is None or resets_at <= 0:
            continue

        window = {
            "used_percentage": min(100.0, max(0.0, used)),
            "resets_at": int(resets_at),
        }
        existing = windows.get(name)
        if existing is None or window["used_percentage"] > existing["used_percentage"]:
            windows[name] = window

    if not windows:
        return None
    return {
        "source": "codex",
        "updated_at": int(time.time()) if now is None else now,
        "rate_limits": windows,
    }


def usage_snapshot(payload: Mapping[str, Any], now: Optional[int] = None) -> Optional[dict[str, Any]]:
    """Normalize the response from ChatGPT's read-only Codex usage endpoint."""
    rate_limit = payload.get("rate_limit", {})
    if not isinstance(rate_limit, Mapping):
        return None

    headers: dict[str, Any] = {}
    for position in ("primary", "secondary"):
        window = rate_limit.get(f"{position}_window")
        if not isinstance(window, Mapping):
            continue
        seconds = _number(window.get("limit_window_seconds"))
        if seconds is None:
            continue
        prefix = f"{HEADER_PREFIX}{position}-"
        headers[f"{prefix}used-percent"] = window.get("used_percent")
        headers[f"{prefix}window-minutes"] = seconds / 60
        headers[f"{prefix}reset-at"] = window.get("reset_at")
    return quota_snapshot(headers, now=now)


def _fresh_snapshot_exists(data_dir: Path, now: Optional[int] = None) -> bool:
    try:
        snapshot = json.loads((data_dir / SNAPSHOT_NAME).read_text(encoding="utf-8"))
        updated_at = float(snapshot["updated_at"])
    except (FileNotFoundError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        return False
    current_time = time.time() if now is None else now
    return 0 <= current_time - updated_at < USAGE_REFRESH_SECONDS


async def _fetch_usage_snapshot() -> Optional[dict[str, Any]]:
    # Import lazily so this callback remains usable for non-ChatGPT deployments
    # and straightforward to unit-test without initializing all of LiteLLM.
    import httpx

    from litellm.llms.chatgpt.authenticator import Authenticator
    from litellm.llms.chatgpt.common_utils import get_chatgpt_default_headers

    authenticator = Authenticator()
    access_token = authenticator.get_access_token()
    account_id = authenticator.get_account_id()
    headers = get_chatgpt_default_headers(access_token, account_id)
    headers["accept"] = "application/json"
    async with httpx.AsyncClient(timeout=5) as client:
        response = await client.get(f"{authenticator.get_api_base().rstrip('/')}/usage", headers=headers)
        response.raise_for_status()
        payload = response.json()
    return usage_snapshot(payload) if isinstance(payload, Mapping) else None


def _write_snapshot(snapshot: Mapping[str, Any], data_dir: Path) -> None:
    data_dir.mkdir(parents=True, exist_ok=True)
    destination = data_dir / SNAPSHOT_NAME
    fd, temporary_name = tempfile.mkstemp(prefix=f".{SNAPSHOT_NAME}.", dir=data_dir, text=True)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as temporary:
            json.dump(snapshot, temporary, separators=(",", ":"), sort_keys=True)
            temporary.write("\n")
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_name, destination)
        os.chmod(destination, 0o600)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


class CodexRateLimitCallback(CustomLogger):
    async def async_post_call_response_headers_hook(
        self,
        data: dict,
        user_api_key_dict: Any,
        response: Any,
        request_headers: Optional[dict[str, str]] = None,
        litellm_call_info: Optional[dict[str, Any]] = None,
    ) -> None:
        del data, user_api_key_dict, request_headers, litellm_call_info
        data_dir_value = os.environ.get(DATA_DIR_ENV)
        if response is None or not data_dir_value:
            return None
        data_dir = Path(data_dir_value)
        snapshot = quota_snapshot(_response_headers(response))
        if snapshot is None and not _fresh_snapshot_exists(data_dir):
            try:
                snapshot = await _fetch_usage_snapshot()
            except Exception:
                # Quota display is optional and must never fail an LLM request.
                return None
        if snapshot is not None:
            _write_snapshot(snapshot, data_dir)
        return None


codex_rate_limit_callback = CodexRateLimitCallback()
