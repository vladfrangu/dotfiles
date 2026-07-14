#!/usr/bin/env python3
"""Apply the local Claude/Codex compatibility fixes to pinned LiteLLM."""

from __future__ import annotations

import importlib.util
from pathlib import Path


PROMPT_PATCH_MARKER = "Handles strings and Anthropic-style content block lists."
PROMPT_REPLACEMENT = '''def map_system_message_pt(messages: list) -> list:
    """Convert system messages to user messages.

    Handles strings and Anthropic-style content block lists.
    """

    def _to_str(content):
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            return " ".join(
                block.get("text", "")
                for block in content
                if isinstance(block, dict) and block.get("type") == "text"
            )
        return str(content)

    new_messages = []
    for message in messages:
        if message["role"] == "system":
            system_text = _to_str(message["content"])
            if new_messages and new_messages[-1]["role"] == "user":
                previous_text = _to_str(new_messages[-1]["content"])
                new_messages[-1]["content"] = system_text + " " + previous_text
            else:
                new_messages.append({"role": "user", "content": system_text})
        else:
            new_messages.append(message)
    return new_messages


'''

AUTH_PATCH_MARKER = "Codex-compatible nested OAuth token store."
AUTH_READ_WRITE_REPLACEMENT = '''    def _read_auth_file(self) -> Optional[Dict[str, Any]]:
        """Read LiteLLM's flat format or Codex's nested OAuth token store."""
        try:
            with open(self.auth_file, "r") as f:
                auth_data = json.load(f)
            tokens = auth_data.get("tokens")
            if isinstance(tokens, dict):
                # Codex-compatible nested OAuth token store. Add expiry only to
                # the in-memory view; Codex owns the on-disk schema.
                result = dict(tokens)
                access_token = result.get("access_token")
                if access_token:
                    result["expires_at"] = self._get_expires_at(access_token)
                return result
            return auth_data
        except IOError:
            return None
        except json.JSONDecodeError as exc:
            verbose_logger.warning("Invalid ChatGPT auth file: %s", exc)
            return None

    def _write_auth_file(self, data: Dict[str, Any]) -> None:
        try:
            existing: Dict[str, Any] = {}
            try:
                with open(self.auth_file, "r") as f:
                    existing = json.load(f)
            except (IOError, json.JSONDecodeError):
                pass

            if isinstance(existing.get("tokens"), dict):
                token_store = existing["tokens"]
                for key in ("access_token", "refresh_token", "id_token", "account_id"):
                    if data.get(key) is not None:
                        token_store[key] = data[key]
                existing["last_refresh"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
                payload = existing
            else:
                payload = data

            with open(self.auth_file, "w") as f:
                json.dump(payload, f)
        except IOError as exc:
            verbose_logger.error("Failed to write ChatGPT auth file: %s", exc)

'''


def package_path() -> Path:
    spec = importlib.util.find_spec("litellm")
    if spec is None or spec.submodule_search_locations is None:
        raise SystemExit("LiteLLM is not installed in this Python environment")
    return Path(next(iter(spec.submodule_search_locations)))


def patch_prompt_handling(package_dir: Path) -> None:
    path = package_dir / "litellm_core_utils" / "prompt_templates" / "factory.py"
    source = path.read_text()
    if PROMPT_PATCH_MARKER in source:
        print(f"LiteLLM compatibility patch already present: {path}")
        return

    start = source.find("def map_system_message_pt(messages: list) -> list:")
    end = source.find("def alpaca_pt(messages):", start)
    if start < 0 or end < 0:
        raise SystemExit(f"Refusing to patch unexpected LiteLLM source: {path}")

    path.write_text(source[:start] + PROMPT_REPLACEMENT + source[end:])
    print(f"Patched LiteLLM Anthropic content-block handling: {path}")


def patch_codex_auth(package_dir: Path) -> None:
    path = package_dir / "llms" / "chatgpt" / "authenticator.py"
    source = path.read_text()
    if AUTH_PATCH_MARKER in source:
        print(f"LiteLLM Codex OAuth patch already present: {path}")
        return

    start = source.find("    def _read_auth_file(self) -> Optional[Dict[str, Any]]:")
    end = source.find("    def _is_token_expired(", start)
    if start < 0 or end < 0:
        raise SystemExit(f"Refusing to patch unexpected LiteLLM auth source: {path}")
    source = source[:start] + AUTH_READ_WRITE_REPLACEMENT + source[end:]

    device_login = '''        tokens = self._login_device_code()
        return tokens["access_token"]'''
    disabled_device_login = '''        if os.getenv("CHATGPT_DISABLE_DEVICE_AUTH", "").lower() in ("1", "true", "yes"):
            raise GetAccessTokenError(
                message="Codex OAuth is missing or expired; run `codex login` and restart the proxy",
                status_code=401,
            )
        tokens = self._login_device_code()
        return tokens["access_token"]'''
    if device_login not in source:
        raise SystemExit(f"Refusing to patch unexpected LiteLLM device auth source: {path}")
    source = source.replace(device_login, disabled_device_login, 1)

    path.write_text(source)
    print(f"Patched LiteLLM to share Codex OAuth: {path}")


def main() -> None:
    package_dir = package_path()
    patch_prompt_handling(package_dir)
    patch_codex_auth(package_dir)


if __name__ == "__main__":
    main()
