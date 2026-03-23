# claude-code-statusline

[![CI](https://github.com/GorajKathrotiya/claude-code-statusline/actions/workflows/ci.yml/badge.svg)](https://github.com/GorajKathrotiya/claude-code-statusline/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS | Linux | WSL](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20WSL-brightgreen.svg)](#platform-support)
[![Shell: POSIX sh](https://img.shields.io/badge/Shell-POSIX%20sh-lightgrey.svg)](statusline-command.sh)

A zero-dependency Claude Code statusline that shows **model**, **git branch**, **context window usage**, **session %**, **reset countdown**, **weekly %**, **per-model usage split**, and **cost tracking** — all in your terminal, without any third-party tools.

### Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/GorajKathrotiya/claude-code-statusline/main/install.sh | sh
```

### What it looks like

```
main (3) | claude-sonnet-4-6 (Pro) | [███░░░░░░░] 34% (68k/200k) | Session: 22.0% | Reset: 2h1m | Weekly: 7.0% | [Sonnet:4%] | Cost: $0
```

**Max plan with Opus + Sonnet split and cost tracking:**
```
main | claude-opus-4-6 (Max) | [██████░░░░] 65% (650k/1M) | Session: 45.0% | Reset: 2h1m | Weekly: 62.0% | [Opus:30% Sonnet:55%] | Cost: $18.50/$100
```

**Minimal mode** (context + model only):
```
claude-sonnet-4-6 (Pro) | [███░░░░░░░] 34% (68k/200k)
```

**High usage** (bar turns red at 80%+):
```
main | claude-opus-4-6 (Max) | [█████████░] 92% (460k/500k) | Session: 85.2% | Reset: 43m | Weekly: 61.0%
```

> **Inspired by** [ccstatusline](https://github.com/sirmalloc/ccstatusline) — but with zero npm, zero installs, pure shell.

---

## What it shows

| Segment | Description |
|---|---|
| `main (3)` | Current git branch + count of uncommitted files (yellow) |
| `claude-sonnet-4-6` | Active model name (cyan) |
| `(Pro)` | Plan badge — Pro, Max, Team, or Ent (dimmed) |
| `[███░░░░░░░] 34%` | Context window bar — green/yellow/red by usage |
| `(68k/200k)` | Tokens used / total window size (dimmed) |
| `Session: 22.0%` | 5-hour block utilization — color-coded |
| `Reset: 2h1m` | Countdown to 5-hour block reset (magenta) |
| `Weekly: 7.0%` | 7-day utilization — color-coded |
| `[Opus:30% Sonnet:55%]` | Per-model 7-day usage split — color-coded |
| `Cost: $18.50/$100` | Extra usage spend / monthly limit — green/yellow/red |
| `*` | Stale cache indicator (dimmed, shown when cache > 10 min old) |

### Color coding

| Usage | Color |
|---|---|
| < 50% | Green |
| 50–79% | Yellow |
| >= 80% | Red |
| Reset countdown | Magenta |
| Cost: $0 | Green |
| Cost: any spend | Yellow |
| Cost: >= 75% of limit | Red |

---

## Requirements

- **macOS**, **Linux**, or **WSL** (Windows Subsystem for Linux)
- **`jq`** — `brew install jq` (macOS) / `sudo apt install jq` (Linux)
- **Claude Code** with a **Pro / Max / Team** plan (OAuth login — not API key)

**Optional dependencies** (script degrades gracefully without them):
- **`curl`** — needed for usage stats (Session/Reset/Weekly)
- **`git`** — needed for branch display

> **API key users:** Session/Reset/Weekly stats won't appear, but the context bar and model still work.

---

## Installation

### One-liner (fastest)

```bash
curl -fsSL https://raw.githubusercontent.com/GorajKathrotiya/claude-code-statusline/main/install.sh | sh
```

Downloads the script, updates `settings.json`, and verifies it works — all in one command.

---

### Option 0 — Plugin marketplace

```
/plugin marketplace add GorajKathrotiya/claude-code-statusline
/plugin install claude-code-statusline
```

Then type `/statusline` in Claude Code — it will set everything up and ask how you'd like it configured.

---

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
Claude will ask your preference, copy the script, and update `settings.json` — all automatically.

---

### Option B — Manual setup

See the [Manual Setup](#manual-setup) section below.

---

## Using `/statusline`

After installing the skill or plugin, type `/statusline` in Claude Code. It will ask you to choose a preset:

### Presets

#### Full (default)

Shows everything — git branch, model, plan badge, context bar, session %, reset countdown, weekly %, per-model split, and cost.

```
main (3) | claude-sonnet-4-6 (Pro) | [███░░░░░░░] 34% (68k/200k) | Session: 22.0% | Reset: 2h1m | Weekly: 7.0% | [Sonnet:4%] | Cost: $0
```

#### Minimal

Shows only model + context bar. Hides git branch and usage stats. Great for a clean, focused view.

```
claude-sonnet-4-6 (Pro) | [███░░░░░░░] 34% (68k/200k)
```

#### Custom

Pick exactly which segments to show and configure thresholds. Claude will ask you:

- Which segments to **hide** (git, model, context bar, usage stats)
- **Bar width** — how many characters wide (default: 10)
- **Warning threshold** — when the bar turns yellow (default: 50%)
- **Critical threshold** — when the bar turns red (default: 80%)

Example custom output with wider bar, no git, lower thresholds:

```
claude-sonnet-4-6 (Pro) | [███████░░░░░░░░░░░░░] 34% (68k/200k) | Session: 22.0% | Reset: 2h1m | Weekly: 7.0%
```

### Reconfiguring

Run `/statusline` again anytime to change your preferences. Claude will update your `settings.json` automatically.

---

## Manual setup

If you prefer to set things up yourself instead of using `/statusline`:

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

To customize, prefix environment variables before the `bash` command:

```json
{
  "statusLine": {
    "type": "command",
    "command": "CLAUDE_STATUSLINE_HIDE_GIT=1 CLAUDE_STATUSLINE_BAR_WIDTH=15 bash ~/.claude/statusline-command.sh"
  }
}
```

**Step 3 — Restart Claude Code**

Close and reopen Claude Code. The statusline appears at the bottom immediately.

---

## Customization reference

All behavior is configurable via environment variables — no script editing needed. These are prefixed before `bash` in the `command` string in `settings.json`.

### Segment toggles

| Variable | Default | What it does |
|---|---|---|
| `CLAUDE_STATUSLINE_HIDE_GIT` | `0` | `1` = hide git branch + change count |
| `CLAUDE_STATUSLINE_HIDE_MODEL` | `0` | `1` = hide model name + plan badge |
| `CLAUDE_STATUSLINE_HIDE_CONTEXT` | `0` | `1` = hide context window bar |
| `CLAUDE_STATUSLINE_HIDE_USAGE` | `0` | `1` = hide session %, reset, weekly % |

### Appearance

| Variable | Default | What it does |
|---|---|---|
| `CLAUDE_STATUSLINE_BAR_WIDTH` | `10` | Context bar width in characters |
| `CLAUDE_STATUSLINE_WARN_PCT` | `50` | % threshold where bar turns yellow |
| `CLAUDE_STATUSLINE_CRIT_PCT` | `80` | % threshold where bar turns red |

### Caching

| Variable | Default | What it does |
|---|---|---|
| `CLAUDE_STATUSLINE_CACHE_TTL` | `180` | Seconds between API calls |
| `CLAUDE_STATUSLINE_STALE_TTL` | `600` | Seconds before `*` stale indicator appears |

### Overrides

| Variable | Default | What it does |
|---|---|---|
| `CLAUDE_PLAN` | auto-detected | Force plan tier: `pro`, `max`, `team`, `enterprise` |
| `CLAUDE_CONTEXT_WINDOW_SIZE` | auto-detected | Force context window size in tokens |

### Preset examples

**Full (default):**
```json
"command": "bash ~/.claude/statusline-command.sh"
```

**Minimal (context + model only):**
```json
"command": "CLAUDE_STATUSLINE_HIDE_GIT=1 CLAUDE_STATUSLINE_HIDE_USAGE=1 bash ~/.claude/statusline-command.sh"
```

**Custom — wide bar, aggressive thresholds, no git:**
```json
"command": "CLAUDE_STATUSLINE_HIDE_GIT=1 CLAUDE_STATUSLINE_BAR_WIDTH=20 CLAUDE_STATUSLINE_WARN_PCT=30 CLAUDE_STATUSLINE_CRIT_PCT=60 bash ~/.claude/statusline-command.sh"
```

**Custom — usage stats only, no context bar:**
```json
"command": "CLAUDE_STATUSLINE_HIDE_GIT=1 CLAUDE_STATUSLINE_HIDE_CONTEXT=1 bash ~/.claude/statusline-command.sh"
```

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
   - OAuth token read from macOS keychain, Linux secret-tool, or credential files
   - Response cached to `~/.claude/.usage_cache.json` (3 minutes by default)
   - Falls back to stale cache on network failure — statusline never breaks
   - Stale indicator (`*`) shown when cache is older than 10 minutes
3. **Per-model split** — Opus and Sonnet 7-day usage parsed from `seven_day_opus` / `seven_day_sonnet` fields
4. **Cost tracking** — Extra usage spend from `extra_usage.used_credits` with optional monthly limit display

---

## Verify it works

```bash
echo '{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"'$(pwd)'","context_window":{"used_percentage":35,"current_usage":{"input_tokens":7000},"context_window_size":200000}}' \
  | bash ~/.claude/statusline-command.sh
```

You should see a colored statusline printed to your terminal.

---

## Platform support

| Platform | Token source | Status |
|---|---|---|
| macOS | Keychain (`security`) | Fully supported |
| Linux (native) | `secret-tool` or credential files | Fully supported |
| WSL | Windows credential files via `wslpath` | Supported |

---

## Running tests

```bash
make test
# or
sh tests/run_tests.sh
```

Tests run on both macOS and Linux (CI runs on both).

---

## Troubleshooting

**Session/Weekly/Reset not showing**
- Confirm you're logged in via OAuth (Pro/Max/Team), not an API key
- macOS: `security find-generic-password -s "Claude Code-credentials" -w | jq keys`
- Linux: check `~/.config/Claude/` or `~/.claude/` for credential files
- Should return `["claudeAiOauth"]` — if empty, log in via `claude login`

**`jq: command not found`**
```bash
brew install jq        # macOS
sudo apt install jq    # Ubuntu/Debian
sudo dnf install jq    # Fedora
```

**Colors not rendering**
- Make sure your terminal supports ANSI colors (iTerm2, Terminal.app, Warp, GNOME Terminal, Alacritty all work)

**Stale data**
- Cache TTL is 3 minutes by default. Delete to force refresh:
  ```bash
  rm ~/.claude/.usage_cache.json
  ```
- If you see `*` after the weekly percentage, the cache is older than 10 minutes

**Want to reconfigure?**
- Run `/statusline` again in Claude Code, or
- Edit `~/.claude/settings.json` directly (see [Customization reference](#customization-reference))

---

## License

MIT — see [LICENSE](LICENSE)
