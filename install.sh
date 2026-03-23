#!/bin/sh
# claude-code-statusline installer
# Usage: curl -fsSL https://raw.githubusercontent.com/GorajKathrotiya/claude-code-statusline/main/install.sh | sh
set -e

REPO="GorajKathrotiya/claude-code-statusline"
BRANCH="main"
SCRIPT_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/statusline-command.sh"
DEST="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"

printf 'claude-code-statusline installer\n\n'

# ── Check dependencies ───────────────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  printf 'Error: jq is required but not installed.\n'
  printf '  macOS:  brew install jq\n'
  printf '  Ubuntu: sudo apt install jq\n'
  printf '  Fedora: sudo dnf install jq\n'
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  printf 'Error: curl is required but not installed.\n'
  exit 1
fi

# ── Download script ──────────────────────────────────────────────────────────
printf '1. Downloading statusline-command.sh...\n'
mkdir -p "$HOME/.claude"
curl -fsSL "$SCRIPT_URL" -o "$DEST"
chmod +x "$DEST"
printf '   Saved to %s\n' "$DEST"

# ── Update settings.json ────────────────────────────────────────────────────
printf '2. Updating settings.json...\n'

statusline_entry='{"type":"command","command":"bash '"$DEST"'"}'

if [ -f "$SETTINGS" ]; then
  # Merge statusLine into existing settings, preserving all other keys
  tmp=$(mktemp)
  jq --argjson sl "$statusline_entry" '.statusLine = $sl' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  printf '   Updated %s\n' "$SETTINGS"
else
  # Create new settings.json
  printf '{"statusLine":%s}\n' "$statusline_entry" | jq . > "$SETTINGS"
  printf '   Created %s\n' "$SETTINGS"
fi

# ── Verify ───────────────────────────────────────────────────────────────────
printf '3. Verifying...\n'
test_output=$(printf '{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"/tmp","context_window":{"used_percentage":35,"context_window_size":200000}}' \
  | CLAUDE_STATUSLINE_HIDE_USAGE=1 bash "$DEST" 2>/dev/null || true)

if [ -n "$test_output" ]; then
  printf '   OK — statusline is working\n'
else
  printf '   Warning: statusline produced no output. Check jq is installed.\n'
fi

printf '\nDone! Restart Claude Code to see your statusline.\n'
printf 'Run /statusline in Claude Code anytime to customize.\n'
