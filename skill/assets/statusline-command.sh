#!/bin/sh
input=$(cat)

# Exit early if input is empty or not valid JSON
echo "$input" | jq empty 2>/dev/null || exit 0

# Colors — real ESC bytes via printf, safe in any output context
cyan=$(printf '\033[36m')
yellow=$(printf '\033[33m')
green=$(printf '\033[32m')
red=$(printf '\033[31m')
magenta=$(printf '\033[35m')
dim=$(printf '\033[2m')
reset=$(printf '\033[0m')

# ── Usage API (5-hour session + 7-day weekly) ────────────────────────────────
CACHE_FILE="$HOME/.claude/.usage_cache.json"
CACHE_TTL=180  # seconds

_fetch_usage() {
  if [ -f "$CACHE_FILE" ]; then
    cache_mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    now=$(date +%s)
    age=$(( now - cache_mtime ))
    if [ "$age" -lt "$CACHE_TTL" ]; then
      cat "$CACHE_FILE"
      return 0
    fi
  fi

  token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
    | jq -r '.claudeAiOauth.accessToken // .accessToken // empty' 2>/dev/null)

  if [ -z "$token" ]; then
    [ -f "$CACHE_FILE" ] && cat "$CACHE_FILE"
    return 1
  fi

  result=$(curl -sf --max-time 5 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

  if [ -n "$result" ]; then
    mkdir -p "$(dirname "$CACHE_FILE")"
    echo "$result" > "$CACHE_FILE"
    echo "$result"
  else
    [ -f "$CACHE_FILE" ] && cat "$CACHE_FILE"
  fi
}

usage_data=$(_fetch_usage 2>/dev/null)

session_pct=""
weekly_pct=""
session_reset_part=""
plan_tier=""

if [ -n "$usage_data" ]; then
  session_raw=$(echo "$usage_data" | jq -r '.five_hour.utilization // empty')
  weekly_raw=$(echo "$usage_data"  | jq -r '.seven_day.utilization // empty')
  session_reset_at=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')
  plan_tier=$(echo "$usage_data" | jq -r \
    '.plan // .plan_tier // .plan_name // .subscription_type // .tier // empty' 2>/dev/null \
    | tr '[:upper:]' '[:lower:]')

  if [ -n "$session_raw" ]; then
    session_pct=$(echo "$session_raw" | awk '{v=$1+0; if(v>100)v=100; printf "%.1f", v}')
  fi
  if [ -n "$weekly_raw" ]; then
    weekly_pct=$(echo "$weekly_raw" | awk '{v=$1+0; if(v>100)v=100; printf "%.1f", v}')
  fi

  # Format reset countdown (macOS date)
  _fmt_reset() {
    ts="$1"
    [ -z "$ts" ] && return
    # Strip sub-seconds, normalize +HH:MM → +HHMM for macOS date -j
    ts_clean=$(echo "$ts" \
      | sed 's/\.[0-9]*//' \
      | sed 's/+\([0-9][0-9]\):\([0-9][0-9]\)$/+\1\2/' \
      | sed 's/Z$/+0000/')
    reset_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$ts_clean" +%s 2>/dev/null)
    [ -z "$reset_epoch" ] && return
    now_epoch=$(date +%s)
    diff=$(( reset_epoch - now_epoch ))
    [ "$diff" -le 0 ] && echo "soon" && return
    hrs=$(( diff / 3600 ))
    mins=$(( (diff % 3600) / 60 ))
    [ "$hrs" -gt 0 ] && echo "${hrs}h${mins}m" || echo "${mins}m"
  }

  [ -n "$session_reset_at" ] && session_reset_part=$(_fmt_reset "$session_reset_at")
fi

# ── Model name ───────────────────────────────────────────────────────────────
model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')

# ── Git branch + change count ────────────────────────────────────────────────
cwd=$(echo "$input" | jq -r '.cwd // empty')
branch=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  change_count=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')
fi
if [ -n "$branch" ]; then
  if [ -n "$change_count" ] && [ "$change_count" -gt 0 ]; then
    branch_part="${yellow}${branch} (${change_count})${reset} | "
  else
    branch_part="${yellow}${branch}${reset} | "
  fi
else
  branch_part=""
fi

# ── Plan badge ───────────────────────────────────────────────────────────────
case "$plan_tier" in
  *max*)        plan_badge="Max" ;;
  *pro*)        plan_badge="Pro" ;;
  *team*)       plan_badge="Team" ;;
  *enterprise*) plan_badge="Ent" ;;
  *)            plan_badge="" ;;
esac

if [ -n "$plan_badge" ]; then
  model_part="${cyan}${model}${reset} ${dim}(${plan_badge})${reset}"
else
  model_part="${cyan}${model}${reset}"
fi

# ── Context window ───────────────────────────────────────────────────────────
used=$(echo "$input"        | jq -r '.context_window.used_percentage // empty')
window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# When Claude Code does not report context_window_size, fall back to plan-based
# default. Override anytime with CLAUDE_CONTEXT_WINDOW_SIZE=<tokens>.
if [ -z "$window_size" ]; then
  if [ -n "$CLAUDE_CONTEXT_WINDOW_SIZE" ]; then
    window_size="$CLAUDE_CONTEXT_WINDOW_SIZE"
  else
    case "$plan_badge" in
      Max)  window_size=500000 ;;
      *)    window_size=200000 ;;
    esac
  fi
fi

# ── Context bar (thresholds: <50 green, <80 yellow, ≥80 red) ────────────────
if [ -z "$used" ]; then
  ctx_part="[----------] -%"
else
  used_int=$(printf "%.0f" "$used")

  if [ "$used_int" -lt 50 ]; then
    bar_color=$(printf '\033[32m')
  elif [ "$used_int" -lt 80 ]; then
    bar_color=$(printf '\033[33m')
  else
    bar_color=$(printf '\033[31m')
  fi

  bar_width=10
  filled=$(( used_int * bar_width / 100 ))
  empty=$(( bar_width - filled ))

  bar=""
  i=0
  while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$(( i + 1 )); done
  i=0
  while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$(( i + 1 )); done

  if [ -n "$window_size" ]; then
    token_part=$(awk -v p="$used_int" -v w="$window_size" 'BEGIN{
      u=p*w/100
      printf "(%dk/%dk)", u/1000, w/1000
    }')
    token_part=" ${dim}${token_part}${reset}"
  else
    token_part=""
  fi

  ctx_part="${bar_color}[${bar}]${reset} ${bar_color}${used_int}%${reset}${token_part}"
fi

# ── Usage (session + reset + weekly) ─────────────────────────────────────────
_pct_color() {
  pct="$1"
  echo "$pct" | awk -v g="$green" -v y="$yellow" -v r="$red" \
    '{if($1+0<50) printf g; else if($1+0<80) printf y; else printf r}'
}

usage_part=""
if [ -n "$session_pct" ] || [ -n "$weekly_pct" ]; then
  if [ -n "$session_pct" ]; then
    sc=$(_pct_color "$session_pct")
    usage_part="${usage_part} | Session: ${sc}${session_pct}%${reset}"
  fi
  if [ -n "$session_reset_part" ]; then
    usage_part="${usage_part} | Reset: ${magenta}${session_reset_part}${reset}"
  fi
  if [ -n "$weekly_pct" ]; then
    wc=$(_pct_color "$weekly_pct")
    usage_part="${usage_part} | Weekly: ${wc}${weekly_pct}%${reset}"
  fi
fi

# ── Final output — printf '%s' avoids format string injection from variable content
printf '%s' "${branch_part}${model_part} | ${ctx_part}${usage_part}"
