from __future__ import annotations

import importlib
import json
import os
import stat
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock


def import_callback_module():
    custom_logger_module = types.ModuleType("litellm.integrations.custom_logger")

    class CustomLogger:
        pass

    custom_logger_module.CustomLogger = CustomLogger
    integrations_module = types.ModuleType("litellm.integrations")
    litellm_module = types.ModuleType("litellm")
    with mock.patch.dict(
        sys.modules,
        {
            "litellm": litellm_module,
            "litellm.integrations": integrations_module,
            "litellm.integrations.custom_logger": custom_logger_module,
        },
    ):
        sys.modules.pop("rate_limit_callback", None)
        return importlib.import_module("rate_limit_callback")


rate_limit_callback = import_callback_module()
import statusline_adapter


class RateLimitNormalizationTests(unittest.TestCase):
    def test_classifies_windows_by_duration_instead_of_position(self):
        snapshot = rate_limit_callback.quota_snapshot(
            {
                "x-codex-primary-used-percent": "48",
                "x-codex-primary-window-minutes": "10080",
                "x-codex-primary-reset-at": "2000000000",
                "x-codex-secondary-used-percent": "12.5",
                "x-codex-secondary-window-minutes": "300",
                "x-codex-secondary-reset-at": "1900000000",
            },
            now=1800000000,
        )

        self.assertEqual(
            snapshot,
            {
                "source": "codex",
                "updated_at": 1800000000,
                "rate_limits": {
                    "seven_day": {"used_percentage": 48.0, "resets_at": 2000000000},
                    "five_hour": {"used_percentage": 12.5, "resets_at": 1900000000},
                },
            },
        )

    def test_extracts_litellm_prefixed_provider_headers(self):
        response = types.SimpleNamespace(
            _hidden_params={
                "additional_headers": {
                    "llm_provider-x-codex-primary-used-percent": "7",
                    "llm_provider-x-codex-primary-window-minutes": "300",
                    "llm_provider-x-codex-primary-reset-at": "1900000000",
                }
            }
        )
        headers = rate_limit_callback._response_headers(response)
        snapshot = rate_limit_callback.quota_snapshot(headers, now=1800000000)

        self.assertEqual(
            snapshot["rate_limits"],
            {"five_hour": {"used_percentage": 7.0, "resets_at": 1900000000}},
        )

    def test_ignores_unknown_window_duration(self):
        snapshot = rate_limit_callback.quota_snapshot(
            {
                "x-codex-primary-used-percent": "10",
                "x-codex-primary-window-minutes": "1440",
                "x-codex-primary-reset-at": "1900000000",
            }
        )
        self.assertIsNone(snapshot)

    def test_normalizes_codex_usage_endpoint_response(self):
        snapshot = rate_limit_callback.usage_snapshot(
            {
                "rate_limit": {
                    "primary_window": {
                        "used_percent": 59,
                        "limit_window_seconds": 604800,
                        "reset_at": 2000000000,
                    },
                    "secondary_window": None,
                }
            },
            now=1800000000,
        )

        self.assertEqual(
            snapshot,
            {
                "source": "codex",
                "updated_at": 1800000000,
                "rate_limits": {
                    "seven_day": {"used_percentage": 59.0, "resets_at": 2000000000}
                },
            },
        )


class RateLimitCallbackTests(unittest.IsolatedAsyncioTestCase):
    async def test_callback_writes_private_atomic_snapshot(self):
        response = types.SimpleNamespace(
            _hidden_params={
                "additional_headers": {
                    "llm_provider-x-codex-primary-used-percent": "48",
                    "llm_provider-x-codex-primary-window-minutes": "10080",
                    "llm_provider-x-codex-primary-reset-at": "2000000000",
                }
            }
        )
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.dict(os.environ, {"CLAUDE_CODEX_DATA_DIR": directory}):
                await rate_limit_callback.codex_rate_limit_callback.async_post_call_response_headers_hook(
                    {}, None, response
                )

            path = Path(directory) / "rate-limits.json"
            data = json.loads(path.read_text(encoding="utf-8"))
            mode = stat.S_IMODE(path.stat().st_mode)

        self.assertEqual(data["rate_limits"]["seven_day"]["used_percentage"], 48.0)
        self.assertEqual(mode, 0o600)

    async def test_callback_fetches_usage_when_headers_are_absent(self):
        fetched = {
            "source": "codex",
            "updated_at": 1800000000,
            "rate_limits": {
                "seven_day": {"used_percentage": 59.0, "resets_at": 2000000000}
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            with (
                mock.patch.dict(os.environ, {"CLAUDE_CODEX_DATA_DIR": directory}),
                mock.patch.object(
                    rate_limit_callback,
                    "_fetch_usage_snapshot",
                    mock.AsyncMock(return_value=fetched),
                ) as fetch,
            ):
                await rate_limit_callback.codex_rate_limit_callback.async_post_call_response_headers_hook(
                    {}, None, types.SimpleNamespace(_hidden_params={})
                )

            data = json.loads((Path(directory) / "rate-limits.json").read_text(encoding="utf-8"))

        fetch.assert_awaited_once()
        self.assertEqual(data, fetched)


class StatusLineAdapterTests(unittest.TestCase):
    def test_override_preserves_status_line_options(self):
        with tempfile.TemporaryDirectory() as directory:
            settings = Path(directory) / "settings.json"
            settings.write_text(
                json.dumps(
                    {
                        "statusLine": {
                            "type": "command",
                            "command": "node ~/.claude/statusline.js",
                            "padding": 2,
                            "refreshInterval": 5,
                        }
                    }
                ),
                encoding="utf-8",
            )
            override = json.loads(
                statusline_adapter.settings_override(settings, Path("/tmp/statusline adapter.py"))
            )
            command = statusline_adapter.configured_command(settings)

        self.assertEqual(command, "node ~/.claude/statusline.js")
        self.assertEqual(override["statusLine"]["padding"], 2)
        self.assertEqual(override["statusLine"]["refreshInterval"], 5)
        self.assertIn("statusline adapter.py", override["statusLine"]["command"])

    def test_injects_live_windows_and_omits_expired_ones(self):
        with tempfile.TemporaryDirectory() as directory:
            snapshot_path = Path(directory) / "rate-limits.json"
            snapshot_path.write_text(
                json.dumps(
                    {
                        "source": "codex",
                        "updated_at": 100,
                        "rate_limits": {
                            "five_hour": {"used_percentage": 25, "resets_at": 90},
                            "seven_day": {"used_percentage": 48, "resets_at": 200},
                        },
                    }
                ),
                encoding="utf-8",
            )
            payload: dict[str, object] = {}
            statusline_adapter.inject_snapshot(payload, snapshot_path, now=100)

        self.assertEqual(
            payload,
            {"rate_limits": {"seven_day": {"used_percentage": 48.0, "resets_at": 200}}},
        )


if __name__ == "__main__":
    unittest.main()
