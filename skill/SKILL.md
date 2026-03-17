---
name: statusline
description: Sets up a Claude Code statusline showing model, git branch, context window bar, session usage %, reset countdown, and weekly usage % — without any third-party tools. Uses Anthropic's OAuth usage API (free, no tokens consumed) with a 3-minute local cache. Use when a teammate asks to set up the statusline, add session/weekly usage to their statusline, or runs /statusline.
---

# Statusline Setup

Installs `~/.claude/statusline-command.sh` and wires it into `~/.claude/settings.json`.

**What it shows:**
```
main (3) | claude-sonnet-4-6 | [████░░░░░░] 42% (8400/200000) | Session: 22.0% | Reset: 2h17m | Weekly: 7.0%
```

- **Branch** (yellow) + uncommitted file count
- **Model** (cyan)
- **Context bar** — green/yellow/red by usage %, token counts dimmed
- **Session %** — 5-hour block utilization, color-coded
- **Reset** — countdown to 5-hour block reset (magenta)
- **Weekly %** — 7-day utilization, color-coded

**Requirements:** macOS, Claude Code Pro/Max/Team (OAuth login), `jq` installed.

---

## Setup Steps

### 1. Copy the script

```bash
cp ~/.claude/skills/statusline/assets/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

### 2. Update settings.json

Read `~/.claude/settings.json` and add or update the `statusLine` key. Preserve all existing keys.

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

### 3. Verify

```bash
echo '{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"'$(pwd)'","context_window":{"used_percentage":35,"current_usage":{"input_tokens":7000},"context_window_size":200000}}' \
  | bash ~/.claude/statusline-command.sh
```

Should print a colored statusline. If Session/Weekly/Reset are absent, the user is on an API key plan (not OAuth) — the rest still works fine.

---

## How It Works

- Reads OAuth token from macOS keychain: `security find-generic-password -s "Claude Code-credentials"`
- Calls `https://api.anthropic.com/api/oauth/usage` — free metadata endpoint, no AI inference, no token cost
- Caches to `~/.claude/.usage_cache.json` for 3 minutes to avoid repeated requests
- Falls back to stale cache on network failure — statusline never breaks

## Color Coding

| Value     | Color   |
|-----------|---------|
| < 50%     | Green   |
| 50–79%    | Yellow  |
| ≥ 80%     | Red     |
| Reset time | Magenta |
