# Claude Code through a ChatGPT subscription

This experiment adapts [Prabal Gupta's walkthrough](https://prabal.ca/posts/claude-code-chatgpt-subscription/) to this dotfiles repo. It runs Claude Code's harness against ChatGPT subscription models through a loopback-only LiteLLM proxy. The normal `claude` command and `~/.claude/settings.json` are not modified.

## Recommended: Docker

Requirements: Docker Desktop, Claude Code, Codex CLI logged in with ChatGPT, `curl`, and `openssl`.

```bash
cd tools/claude-codex
./install.sh --docker
claude-codex
```

The proxy reuses Codex's existing ChatGPT OAuth session from `~/.codex/auth.json`; LiteLLM's separate device-code flow is disabled. Only that single auth file is mounted into the container, read-write, so a LiteLLM token refresh is written back in Codex's native nested format. The default launcher starts the proxy for the Claude session and stops it when Claude exits; Docker auto-restart is disabled. Do not run Codex and `claude-codex` concurrently because both may attempt to rotate the same refresh token. The local proxy key lives at `~/.config/claude-codex/master-key`.

Codex quota windows are read from ChatGPT's read-only usage endpoint (or captured from upstream response headers when available) and written to `~/.local/share/claude-codex/rate-limits.json`. Usage reads are throttled to once every 30 seconds and reuse the model request's OAuth session. If `~/.claude/settings.json` configures a command-based status line, the launcher wraps that command for the session and injects the captured five-hour or weekly Codex windows into its normal `rate_limits` input. The settings file and original status-line command are not modified. Accounts can expose only one window, and the wrapper omits expired or unavailable windows rather than reporting them as zero.

Docker is the default because it keeps LiteLLM's large Python dependency tree out of the host environment. The image is pinned to the signed upstream `v1.91.2` release, then receives the walkthrough's Anthropic content-block compatibility patch during the local build. The proxy publishes only on `127.0.0.1:4000`.

## Native `uv` fallback

Requirements: `uv`, Python 3.12 (uv can obtain it), Claude Code, Codex CLI logged in with ChatGPT, `curl`, and `openssl`.

```bash
cd tools/claude-codex
./install.sh --native
claude-codex
```

This creates a repo-local `.venv` from the committed `uv.lock`, applies the same compatibility patch, and starts the proxy on demand. Re-running either install command switches runtimes.

## Commands

```bash
claude-codex                         # default: gpt-5.5
claude-codex --model gpt-5.6-terra # choose another configured model
claude-codex proxy-start            # start without launching Claude Code
claude-codex proxy-stop
claude-codex login                  # validate the shared Codex OAuth session
claude-codex models                 # list models visible to the Codex account
claude-codex models-sync            # regenerate routes from that model catalog
claude-codex status
claude-codex logs --follow
```

`models-sync` asks the installed Codex app-server for its authenticated `model/list` catalog and regenerates `litellm-config.yaml` from the visible models. It does not read or copy Codex's OAuth token. Run it whenever the Codex model picker changes; the command stops LiteLLM afterward so the next launch loads the new routes.

The current catalog includes GPT-5.6 Sol, Terra, and Luna. Sol is the most capable option, Terra balances intelligence and cost, and Luna is the fast/cost-efficient choice. Model availability remains account- and rollout-dependent, which is why the sync command uses your account's catalog rather than a global hardcoded list.

## Why this differs from the article

The article pins LiteLLM 1.83.0. That version is now covered by upstream security advisory [GHSA-r75f-5x8p-qvmc](https://github.com/BerriAI/litellm/security/advisories/GHSA-r75f-5x8p-qvmc), fixed in 1.83.7. This setup instead pins the current stable 1.91.2 release and never exposes the proxy beyond localhost.

This is an unofficial compatibility experiment. Claude Code's prompting and tool loop were designed for Claude models, so behavior can differ, especially for agentic tasks. ChatGPT OAuth through third-party software can also break when either service changes.

## Uninstall

```bash
claude-codex proxy-stop
rm ~/.local/bin/claude-codex
```

After checking that you no longer need the saved login, remove `~/.config/claude-codex` and `~/.local/share/claude-codex` manually.
