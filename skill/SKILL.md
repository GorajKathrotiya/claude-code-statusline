---
name: statusline
description: Sets up a Claude Code statusline showing model, git branch, context window bar, session usage %, reset countdown, weekly usage %, per-model usage split (Opus/Sonnet), and cost tracking — without any third-party tools. Works on macOS, Linux, and WSL. Uses Anthropic's OAuth usage API (free, no tokens consumed) with a configurable local cache. Use when a teammate asks to set up the statusline, add session/weekly usage to their statusline, or runs /statusline.
---

# Statusline Setup

Installs `~/.claude/statusline-command.sh` and wires it into `~/.claude/settings.json`.

**What it shows:**
```
main (3) | claude-sonnet-4-6 (Pro) | [████░░░░░░] 42% (84k/200k) | Session: 22.0% | Reset: 2h17m | Weekly: 7.0% | [Sonnet:4%] | Cost: $0
```

- **Branch** (yellow) + uncommitted file count
- **Model** (cyan) + plan badge (dimmed)
- **Context bar** — green/yellow/red by usage %, token counts dimmed
- **Session %** — 5-hour block utilization, color-coded
- **Reset** — countdown to 5-hour block reset (magenta)
- **Weekly %** — 7-day utilization, color-coded
- **Model split** — per-model 7-day usage (Opus/Sonnet), color-coded
- **Cost** — extra usage spend, green/$0, yellow/any spend, red/>=75% of limit
- **Stale indicator** (`*`) — shown when cached data is older than 10 minutes

**Requirements:** `jq` installed. Works on macOS, Linux, and WSL. Claude Code Pro/Max/Team (OAuth login) needed for usage stats; context bar and model work for all users.

---

## Setup Flow

When the user runs `/statusline`, follow these steps in order:

### Step 1 — Ask about preferences

Ask the user ONE question with these options:

> **How would you like your statusline?**
>
> 1. **Full** (default) — all segments: git branch, model, context bar, session %, reset, weekly %
> 2. **Minimal** — context bar + model only (hides git and usage stats)
> 3. **Custom** — choose which segments to show and configure thresholds
>
> Just press Enter or say "full" for the default setup.

**If they choose Custom**, ask which segments to hide and if they want to change:
- Bar width (default: 10)
- Warning threshold (default: 50%)
- Critical threshold (default: 80%)

Keep it quick — one follow-up message max.

### Step 2 — Copy the script

```bash
cp ~/.claude/skills/statusline/assets/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

### Step 3 — Update settings.json

Read `~/.claude/settings.json` and add or update the `statusLine` key. **Preserve all existing keys.**

Build the command string based on the user's preference:

**Full (default):**
```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

**Minimal:**
```json
"statusLine": {
  "type": "command",
  "command": "CLAUDE_STATUSLINE_HIDE_GIT=1 CLAUDE_STATUSLINE_HIDE_USAGE=1 bash ~/.claude/statusline-command.sh"
}
```

**Custom — example with all options:**
```json
"statusLine": {
  "type": "command",
  "command": "CLAUDE_STATUSLINE_BAR_WIDTH=15 CLAUDE_STATUSLINE_WARN_PCT=40 CLAUDE_STATUSLINE_CRIT_PCT=70 CLAUDE_STATUSLINE_HIDE_GIT=1 bash ~/.claude/statusline-command.sh"
}
```

Only include env vars that differ from defaults. No env var prefix needed for default values.

### Step 4 — Verify

```bash
echo '{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"'$(pwd)'","context_window":{"used_percentage":35,"current_usage":{"input_tokens":7000},"context_window_size":200000}}' \
  | bash ~/.claude/statusline-command.sh
```

Show the user the output and confirm the statusline is working. Tell them to restart Claude Code to see it live.

### Step 5 — Reconfigure anytime

Tell the user: *"Run `/statusline` again anytime to change your preferences."*

---

## Customization Reference

All settings are env vars prefixed before the `bash` command in settings.json:

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_STATUSLINE_CACHE_TTL` | `180` | Cache duration (seconds) |
| `CLAUDE_STATUSLINE_BAR_WIDTH` | `10` | Context bar width (characters) |
| `CLAUDE_STATUSLINE_WARN_PCT` | `50` | Green → yellow threshold |
| `CLAUDE_STATUSLINE_CRIT_PCT` | `80` | Yellow → red threshold |
| `CLAUDE_STATUSLINE_STALE_TTL` | `600` | Seconds before stale `*` appears |
| `CLAUDE_STATUSLINE_HIDE_GIT` | `0` | `1` to hide git branch |
| `CLAUDE_STATUSLINE_HIDE_USAGE` | `0` | `1` to hide session/reset/weekly |
| `CLAUDE_STATUSLINE_HIDE_CONTEXT` | `0` | `1` to hide context bar |
| `CLAUDE_STATUSLINE_HIDE_MODEL` | `0` | `1` to hide model name |
| `CLAUDE_PLAN` | auto | Override: `pro`, `max`, `team`, `enterprise` |
| `CLAUDE_CONTEXT_WINDOW_SIZE` | auto | Override window size in tokens |

## How It Works

- Reads OAuth token from macOS keychain, Linux `secret-tool`, WSL credential files, or `~/.claude/credentials.json`
- Calls `https://api.anthropic.com/api/oauth/usage` — free metadata endpoint, no AI inference, no token cost
- Caches to `~/.claude/.usage_cache.json` (configurable TTL)
- Falls back to stale cache on network failure — statusline never breaks

## Color Coding

| Value     | Color   |
|-----------|---------|
| < 50%     | Green   |
| 50–79%    | Yellow  |
| >= 80%    | Red     |
| Reset time | Magenta |
