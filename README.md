# Agent Hotline

[**中文文档**](README_CN.md)

**Let your AI agent call you when it needs help.**

> Human-in-the-loop for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) via [Feishu / Lark](https://www.feishu.cn/) — vibe coding anytime, anywhere.

When Claude Code needs confirmation, context, or permission, it normally blocks and waits. Agent Hotline bridges that gap: it sends you a Feishu message, you reply from your phone, and Claude keeps going.

```
Claude Code ──Hook──> Agent Hotline ──API──> Feishu (thread + buttons)
             <──inject──              <──WS── (tap / reply)
```

## Features

- **Threaded conversations** — Each Claude Code session maps to a Feishu thread, keeping context organized
- **One-tap permissions** — Interactive cards with Allow / Deny / Always buttons for permission prompts
- **Text replies** — Reply in any thread to type directly into the correct terminal tab
- **Emoji receipts** — Random emoji reactions confirm delivery at a glance (no noisy text replies)
- **Multi-session** — Run multiple Claude Code instances; replies route to the right terminal automatically
- **Session persistence** — Survives server restarts; sessions resume with their Feishu threads intact
- **Zero config in Claude** — Just `install-hooks` once, then use `claude` as normal

## Quick Start

### 1. Create a Feishu App

1. Go to [Feishu Open Platform](https://open.feishu.cn/app) and create an enterprise app
2. **Add capability** > Bot
3. **Permissions** > Enable:
   - `im:message` — Read messages
   - `im:message:send_as_bot` — Send messages
   - `im:message.reactions:write_only` — Add emoji reactions
4. **Events & Callbacks** > Long connection mode > Add event `im.message.receive_v1`
5. **Version Management** > Create version > Publish

### 2. Install

```bash
# Install uv if needed
curl -LsSf https://astral.sh/uv/install.sh | sh

git clone https://github.com/0x5446/agent-hotline.git
cd agent-hotline
uv sync
cp .env.example .env
```

Edit `.env` with your Feishu App ID, Secret, and Verification Token.

### 3. Get Your open_id

Start the service, then send any message to your bot in Feishu:

```bash
uv run agent-hotline serve
# Log: Non-reply message from ou_xxxx (use this open_id for FEISHU_RECEIVE_ID)
```

Add `ou_xxxx` to `FEISHU_RECEIVE_ID` in `.env`, then restart.

### 4. Install Claude Code Hooks

```bash
uv run agent-hotline install-hooks
```

Restart your Claude Code session to activate.

> **macOS Accessibility**: System Settings > Privacy & Security > Accessibility > Add Terminal.app. Required for terminal injection.

That's it. Use `claude` as normal — no tmux, no wrapper, no special setup.

## How It Works

1. Claude Code [Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) fire on task stop / permission prompt / input needed
2. `agent-hotline hook` POSTs the event to the local server
3. Agent Hotline creates a **Feishu thread** (project name as title, content as first reply)
4. You tap a button or reply with text — delivered in real-time via Feishu WebSocket
5. Your response is injected into the correct Terminal.app tab via AppleScript

## Usage

| Scenario | What You See | What You Do |
|----------|-------------|-------------|
| Permission prompt | Card with buttons | Tap **Allow** / **Deny** / **Always** |
| Waiting for input | Text message in thread | Reply with text |
| Task complete | Text message in thread | Reply to continue, or ignore |

Delivery status is shown as an emoji reaction on your message — no extra noise in the thread.

## Multiple Sessions

Each Claude Code session auto-threads in Feishu. Reply to any message in a thread to inject into the correct terminal:

```
Terminal Tab 1 (project-a)  <-->  Feishu Thread "project-a | refact..."
Terminal Tab 2 (project-b)  <-->  Feishu Thread "project-b | add ne..."
```

One `agent-hotline` instance handles all sessions.

## CLI

```bash
agent-hotline start                          # Start as daemon
agent-hotline start --log /tmp/hotline.log   # Custom log path
agent-hotline stop                           # Stop daemon
agent-hotline restart                        # Restart daemon
agent-hotline status                         # Check if running
agent-hotline serve                          # Foreground (debug)
agent-hotline install-hooks                  # Install Claude Code hooks
agent-hotline test-inject /dev/ttys003 "hi"  # Test terminal injection
```

Runtime files in `~/.agent-hotline/`:

| File | Purpose |
|------|---------|
| `agent-hotline.pid` | Daemon PID |
| `agent-hotline.log` | Service log |
| `state.json` | Session persistence |

## Requirements

- macOS (AppleScript + Terminal.app)
- [uv](https://docs.astral.sh/uv/) (Python >= 3.13)
- Feishu enterprise app (free)

## Contributing

Issues and PRs are welcome. Please run `uv run pytest` before submitting.

## Disclaimer

This project is not affiliated with Anthropic. Claude is a trademark of Anthropic.

## License

[MIT](LICENSE)
