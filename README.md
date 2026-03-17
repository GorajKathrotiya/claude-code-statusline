# claude-code-statusline

A zero-dependency Claude Code statusline that shows **model**, **git branch**, **context window usage**, **session %**, **reset countdown**, and **weekly %** — all in your terminal, without any third-party tools.

```
main (3) | claude-sonnet-4-6 | [███░░░░░░░] 34% (68k/200k) | Session: 22.0% | Reset: 2h1m | Weekly: 7.0%
```

> **Inspired by** [ccstatusline](https://github.com/sirmalloc/ccstatusline) — but with zero npm, zero installs, pure shell.

---

## What it shows

| Segment | Description |
|---|---|
| `main (3)` | Current git branch + count of uncommitted files (yellow) |
| `claude-sonnet-4-6` | Active model name (cyan) |
| `[███░░░░░░░] 34%` | Context window bar — green/yellow/red by usage |
| `(68k/200k)` | Tokens used / total window size (dimmed) |
| `Session: 22.0%` | 5-hour block utilization — color-coded |
| `Reset: 2h1m` | Countdown to 5-hour block reset (magenta) |
| `Weekly: 7.0%` | 7-day utilization — color-coded |

### Color coding

| Usage | Color |
|---|---|
| < 50% | 🟢 Green |
| 50–79% | 🟡 Yellow |
| ≥ 80% | 🔴 Red |
| Reset timer | 🟣 Magenta |

---

## Requirements

- **macOS** (uses `security` keychain and `date -j`)
- **Claude Code** with a **Pro / Max / Team** plan (OAuth login — not API key)
- **`jq`** — `brew install jq`
- **`curl`** — pre-installed on macOS

> **API key users:** Session/Reset/Weekly stats won't appear, but the context bar and git branch still work.

---

## Installation

### Option A — Claude Skill (recommended)

**Via skill directory (no build needed):**
```bash
git clone https://github.com/GorajKathrotiya/claude-code-statusline.git
claude skills install ./claude-code-statusline/skill
```

**Or build the `.skill` file first:**
```bash
git clone https://github.com/GorajKathrotiya/claude-code-statusline.git
cd claude-code-statusline
make build
claude skills install ./statusline.skill
```

Then open Claude Code and type:
```
/statusline
```
Claude will copy the script, make it executable, and update your `settings.json` automatically.

---

### Option B — Manual setup

**Step 1 — Copy the script**
```bash
curl -o ~/.claude/statusline-command.sh \
  https://raw.githubusercontent.com/GorajKathrotiya/claude-code-statusline/main/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

**Step 2 — Add to `~/.claude/settings.json`**

Open `~/.claude/settings.json` and add the `statusLine` key (preserve any existing keys):

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

**Step 3 — Restart Claude Code**

Close and reopen Claude Code. The statusline appears at the bottom immediately.

---

## How it works

```
Claude Code → pipes JSON → statusline-command.sh → prints formatted string
```

1. **Context/model/git** — parsed from the JSON Claude Code pipes to the script on every update
2. **Session % / Weekly % / Reset** — fetched from Anthropic's OAuth usage API:
   ```
   GET https://api.anthropic.com/api/oauth/usage
   ```
   - Free metadata endpoint — no AI inference, no token cost
   - OAuth token read from macOS keychain (`security find-generic-password -s "Claude Code-credentials"`)
   - Response cached to `~/.claude/.usage_cache.json` for **3 minutes** to avoid repeated requests
   - Falls back to stale cache on network failure — statusline never breaks

---

## Verify it works

```bash
echo '{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"'$(pwd)'","context_window":{"used_percentage":35,"current_usage":{"input_tokens":7000},"context_window_size":200000}}' \
  | bash ~/.claude/statusline-command.sh
```

You should see a colored statusline printed to your terminal.

---

## Troubleshooting

**Session/Weekly/Reset not showing**
- Confirm you're logged in via OAuth (Pro/Max/Team), not an API key
- Check keychain: `security find-generic-password -s "Claude Code-credentials" -w | jq keys`
- Should return `["claudeAiOauth"]` — if empty, log in via `claude login`

**`jq: command not found`**
```bash
brew install jq
```

**Colors not rendering**
- Make sure your terminal supports ANSI colors (iTerm2, Terminal.app, Warp all work)

**Stale data**
- Cache TTL is 3 minutes. Delete to force refresh:
  ```bash
  rm ~/.claude/.usage_cache.json
  ```

---

## Customisation

All display logic is in `statusline-command.sh` — it's plain shell, easy to edit.

| What to change | Where |
|---|---|
| Cache duration | `CACHE_TTL=180` (seconds) |
| Color thresholds | `_pct_color()` function |
| Reset color | `${magenta}` in `usage_part` block |
| Bar width | `bar_width=10` |

---

## License

MIT — see [LICENSE](LICENSE)
