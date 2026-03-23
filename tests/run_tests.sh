#!/bin/sh
# Test suite for statusline-command.sh
# Usage: sh tests/run_tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$ROOT_DIR/statusline-command.sh"

pass=0
fail=0

# ── Helpers ──────────────────────────────────────────────────────────────────

# Strip ANSI escape codes for easier assertion
strip_ansi() {
  sed $'s/\033\\[[0-9;]*m//g'
}

assert_contains() {
  output="$1"
  expected="$2"
  test_name="$3"
  if printf '%s' "$output" | grep -qF -- "$expected"; then
    pass=$(( pass + 1 ))
    printf '  PASS: %s\n' "$test_name"
  else
    fail=$(( fail + 1 ))
    printf '  FAIL: %s\n' "$test_name"
    printf '    expected to contain: %s\n' "$expected"
    printf '    got: %s\n' "$(printf '%s' "$output" | strip_ansi)"
  fi
}

assert_not_contains() {
  output="$1"
  unexpected="$2"
  test_name="$3"
  if printf '%s' "$output" | grep -qF -- "$unexpected"; then
    fail=$(( fail + 1 ))
    printf '  FAIL: %s\n' "$test_name"
    printf '    expected NOT to contain: %s\n' "$unexpected"
    printf '    got: %s\n' "$(printf '%s' "$output" | strip_ansi)"
  else
    pass=$(( pass + 1 ))
    printf '  PASS: %s\n' "$test_name"
  fi
}

assert_equals() {
  actual="$1"
  expected="$2"
  test_name="$3"
  if [ "$actual" = "$expected" ]; then
    pass=$(( pass + 1 ))
    printf '  PASS: %s\n' "$test_name"
  else
    fail=$(( fail + 1 ))
    printf '  FAIL: %s\n' "$test_name"
    printf '    expected: %s\n' "$expected"
    printf '    got: %s\n' "$actual"
  fi
}

assert_empty() {
  actual="$1"
  test_name="$2"
  if [ -z "$actual" ]; then
    pass=$(( pass + 1 ))
    printf '  PASS: %s\n' "$test_name"
  else
    fail=$(( fail + 1 ))
    printf '  FAIL: %s\n' "$test_name"
    printf '    expected empty, got: %s\n' "$(printf '%s' "$actual" | strip_ansi)"
  fi
}

assert_not_empty() {
  actual="$1"
  test_name="$2"
  if [ -n "$actual" ]; then
    pass=$(( pass + 1 ))
    printf '  PASS: %s\n' "$test_name"
  else
    fail=$(( fail + 1 ))
    printf '  FAIL: %s\n' "$test_name"
    printf '    expected non-empty output\n'
  fi
}

# ANSI color codes for assertion
GREEN_CODE=$(printf '\033[32m')
YELLOW_CODE=$(printf '\033[33m')
RED_CODE=$(printf '\033[31m')

# ── JSON fixtures ────────────────────────────────────────────────────────────

minimal_json='{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"/tmp","context_window":{"used_percentage":35,"current_usage":{"input_tokens":7000},"context_window_size":200000}}'

full_json='{"model":{"display_name":"claude-opus-4-6"},"cwd":"/tmp","context_window":{"used_percentage":75,"current_usage":{"input_tokens":150000},"context_window_size":200000}}'

high_usage_json='{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"/tmp","context_window":{"used_percentage":92,"current_usage":{"input_tokens":184000},"context_window_size":200000}}'

zero_usage_json='{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"/tmp","context_window":{"used_percentage":0,"current_usage":{"input_tokens":0},"context_window_size":200000}}'

no_context_json='{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"/tmp"}'

no_window_size_json='{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"/tmp","context_window":{"used_percentage":50}}'

million_json='{"model":{"display_name":"claude-opus-4-6"},"cwd":"/tmp","context_window":{"used_percentage":9,"context_window_size":1000000}}'

million_half_json='{"model":{"display_name":"claude-opus-4-6"},"cwd":"/tmp","context_window":{"used_percentage":50,"context_window_size":1500000}}'

# ══════════════════════════════════════════════════════════════════════════════
printf '\n=== statusline-command.sh test suite ===\n'
printf 'OS: %s\n\n' "$(uname -s)"

# ── 1. Empty / invalid input ────────────────────────────────────────────────
printf '1. Empty and invalid input handling\n'

out=$(printf '' | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
assert_empty "$out" "empty input produces no output"

out=$(printf 'not json' | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
assert_empty "$out" "invalid JSON produces no output"

# ── 2. Basic output with minimal JSON ────────────────────────────────────────
printf '\n2. Basic output\n'

out=$(printf '%s' "$minimal_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
assert_not_empty "$out" "produces output from minimal JSON"

clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "sonnet-4-6" "contains model name"
assert_contains "$clean" "35%" "contains usage percentage"
assert_contains "$clean" "70k/200k" "contains token counts"

# ── 3. Context bar color thresholds ──────────────────────────────────────────
printf '\n3. Context bar color thresholds\n'

# Green (< 50%)
out=$(printf '%s' "$minimal_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
assert_contains "$out" "$GREEN_CODE" "green color for 35%"

# Yellow (50-79%)
out=$(printf '%s' "$full_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
assert_contains "$out" "$YELLOW_CODE" "yellow color for 75%"

# Red (>= 80%)
out=$(printf '%s' "$high_usage_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
assert_contains "$out" "$RED_CODE" "red color for 92%"

# ── 4. Zero percentage ──────────────────────────────────────────────────────
printf '\n4. Edge case: zero usage\n'

out=$(printf '%s' "$zero_usage_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "0%" "shows 0% usage"

# ── 5. Missing context window ────────────────────────────────────────────────
printf '\n5. Missing context window data\n'

out=$(printf '%s' "$no_context_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "sonnet-4-6" "still shows model without context"
assert_contains "$clean" " -%" "shows dash for missing percentage"

# ── 6. Context window size fallback ──────────────────────────────────────────
printf '\n6. Context window size fallback\n'

out=$(printf '%s' "$no_window_size_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "200k" "falls back to 200k default"

out=$(printf '%s' "$no_window_size_json" | CLAUDE_CONTEXT_WINDOW_SIZE=300000 CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "300k" "uses env var for window size"

out=$(printf '%s' "$million_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "90k/1M" "1M window shows as 1M not 1000k"

out=$(printf '%s' "$million_half_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "1.5M" "1.5M window shows decimal"

out=$(printf '%s' "$minimal_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "200k" "sub-million stays as k"

# ── 7. Segment toggling ─────────────────────────────────────────────────────
printf '\n7. Segment toggling\n'

out=$(printf '%s' "$minimal_json" | CLAUDE_STATUSLINE_HIDE_GIT=1 CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "sonnet-4-6" "model visible when git hidden"

out=$(printf '%s' "$minimal_json" | CLAUDE_STATUSLINE_HIDE_MODEL=1 CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_not_contains "$clean" "sonnet-4-6" "model hidden when HIDE_MODEL=1"
assert_contains "$clean" "35%" "context visible when model hidden"

out=$(printf '%s' "$minimal_json" | CLAUDE_STATUSLINE_HIDE_CONTEXT=1 CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "sonnet-4-6" "model visible when context hidden"
assert_not_contains "$clean" "35%" "context hidden when HIDE_CONTEXT=1"

# ── 8. Configurable bar width ───────────────────────────────────────────────
printf '\n8. Configurable bar width\n'

# Use empty bar (ASCII dashes) for portable char counting across macOS/Linux
out=$(printf '%s' "$no_context_json" | CLAUDE_STATUSLINE_BAR_WIDTH=5 CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
bar=$(printf '%s' "$clean" | sed 's/.*\[//' | sed 's/\].*//')
bar_len=$(printf '%s' "$bar" | awk '{print length}')
assert_equals "$bar_len" "5" "bar width is 5 characters"

out=$(printf '%s' "$no_context_json" | CLAUDE_STATUSLINE_BAR_WIDTH=20 CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
bar=$(printf '%s' "$clean" | sed 's/.*\[//' | sed 's/\].*//')
bar_len=$(printf '%s' "$bar" | awk '{print length}')
assert_equals "$bar_len" "20" "bar width is 20 characters"

# ── 9. Custom color thresholds ───────────────────────────────────────────────
printf '\n9. Custom color thresholds\n'

out=$(printf '%s' "$minimal_json" | CLAUDE_STATUSLINE_WARN_PCT=30 CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
assert_contains "$out" "$YELLOW_CODE" "35% is yellow when WARN_PCT=30"

out=$(printf '%s' "$full_json" | CLAUDE_STATUSLINE_CRIT_PCT=70 CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
assert_contains "$out" "$RED_CODE" "75% is red when CRIT_PCT=70"

# ── 10. Plan badge ──────────────────────────────────────────────────────────
printf '\n10. Plan badge via CLAUDE_PLAN\n'

out=$(printf '%s' "$minimal_json" | CLAUDE_PLAN=max CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "(Max)" "shows Max badge"

out=$(printf '%s' "$minimal_json" | CLAUDE_PLAN=pro CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "(Pro)" "shows Pro badge"

out=$(printf '%s' "$minimal_json" | CLAUDE_PLAN=team CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "(Team)" "shows Team badge"

out=$(printf '%s' "$minimal_json" | CLAUDE_PLAN=enterprise CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "(Ent)" "shows Ent badge"

out=$(printf '%s' "$no_window_size_json" | CLAUDE_PLAN=max CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "500k" "Max plan defaults to 500k window"

# ── 11. Git branch display ──────────────────────────────────────────────────
printf '\n11. Git branch display\n'

# Get the actual branch name (may differ in CI vs local)
# Use || true to prevent set -e from killing the script in detached HEAD
current_branch=$(git -C "$ROOT_DIR" symbolic-ref --short HEAD 2>/dev/null || true)
if [ -n "$current_branch" ]; then
  git_json='{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"'"$ROOT_DIR"'","context_window":{"used_percentage":35,"current_usage":{"input_tokens":7000},"context_window_size":200000}}'
  out=$(printf '%s' "$git_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
  clean=$(printf '%s' "$out" | strip_ansi)
  assert_contains "$clean" "$current_branch" "shows branch name for git repo"
else
  # CI detached HEAD — skip branch name test, just verify no crash
  git_json='{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"'"$ROOT_DIR"'","context_window":{"used_percentage":35,"current_usage":{"input_tokens":7000},"context_window_size":200000}}'
  out=$(printf '%s' "$git_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
  assert_not_empty "$out" "produces output in detached HEAD (no branch)"
fi

out=$(printf '%s' "$minimal_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
assert_not_empty "$out" "produces output for non-git cwd"

# ── 12. Empty bar when no percentage ─────────────────────────────────────────
printf '\n12. Empty bar rendering\n'

out=$(printf '%s' "$no_context_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "----------" "10-char empty bar with dashes"

out=$(printf '%s' "$no_context_json" | CLAUDE_STATUSLINE_BAR_WIDTH=5 CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
assert_contains "$clean" "-----" "5-char empty bar with dashes"

# ── 13. OS detection ─────────────────────────────────────────────────────────
printf '\n13. OS detection\n'

out=$(printf '%s' "$minimal_json" | CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
assert_not_empty "$out" "script runs successfully on $(uname -s)"

# ── 14. jq dependency check ─────────────────────────────────────────────────
printf '\n14. Dependency check\n'

out=$(printf '%s' "$minimal_json" | PATH=/usr/bin:/bin sh -c '
  tmpdir=$(mktemp -d)
  for cmd in sh cat echo printf sed awk date stat wc tr mkdir; do
    for p in /usr/bin /bin; do
      [ -x "$p/$cmd" ] && ln -sf "$p/$cmd" "$tmpdir/$cmd" 2>/dev/null
    done
  done
  PATH="$tmpdir" sh "'"$SCRIPT"'"
  rm -rf "$tmpdir"
' 2>/dev/null)
assert_contains "$out" "jq required" "shows jq required message"

# ── 15. Full output format ──────────────────────────────────────────────────
printf '\n15. Full output format integration\n'

git_json='{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"'"$ROOT_DIR"'","context_window":{"used_percentage":42,"current_usage":{"input_tokens":8400},"context_window_size":200000}}'
out=$(printf '%s' "$git_json" | CLAUDE_PLAN=pro CLAUDE_STATUSLINE_HIDE_USAGE=1 sh "$SCRIPT" 2>/dev/null)
clean=$(printf '%s' "$out" | strip_ansi)
if [ -n "$current_branch" ]; then
  assert_contains "$clean" "$current_branch" "integration: has branch"
else
  assert_not_empty "$out" "integration: runs in detached HEAD"
fi
assert_contains "$clean" "sonnet-4-6" "integration: has model"
assert_contains "$clean" "(Pro)" "integration: has plan badge"
assert_contains "$clean" "42%" "integration: has percentage"
assert_contains "$clean" "|" "integration: has separators"

# ══════════════════════════════════════════════════════════════════════════════
printf '\n=== Results ===\n'
printf 'Passed: %d\n' "$pass"
printf 'Failed: %d\n' "$fail"
printf 'Total:  %d\n' "$(( pass + fail ))"

if [ "$fail" -gt 0 ]; then
  printf '\nSOME TESTS FAILED\n'
  exit 1
else
  printf '\nALL TESTS PASSED\n'
  exit 0
fi
