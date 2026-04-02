#!/bin/sh
# claude-code-statusline — universal, zero-dependency statusline for Claude Code
# Works on macOS, Linux, and WSL.
# Required: jq  |  Optional: curl (usage stats), git (branch display)

# ── Dependency check ─────────────────────────────────────────────────────────
command -v jq >/dev/null 2>&1 || { printf 'statusline: jq required'; exit 0; }

input=$(cat)

# Exit early if input is empty or not valid JSON
[ -z "$input" ] && exit 0
echo "$input" | jq empty 2>/dev/null || exit 0

# ── Configurable thresholds via env vars ─────────────────────────────────────
CACHE_TTL="${CLAUDE_STATUSLINE_CACHE_TTL:-180}"       # seconds
BAR_WIDTH="${CLAUDE_STATUSLINE_BAR_WIDTH:-10}"         # characters
WARN_PCT="${CLAUDE_STATUSLINE_WARN_PCT:-50}"           # green → yellow
CRIT_PCT="${CLAUDE_STATUSLINE_CRIT_PCT:-80}"           # yellow → red
STALE_TTL="${CLAUDE_STATUSLINE_STALE_TTL:-600}"        # seconds before showing stale indicator

# Segment toggles (set to 1 to hide)
HIDE_GIT="${CLAUDE_STATUSLINE_HIDE_GIT:-0}"
HIDE_USAGE="${CLAUDE_STATUSLINE_HIDE_USAGE:-0}"
HIDE_CONTEXT="${CLAUDE_STATUSLINE_HIDE_CONTEXT:-0}"
HIDE_MODEL="${CLAUDE_STATUSLINE_HIDE_MODEL:-0}"
HIDE_MODEL_SPLIT="${CLAUDE_STATUSLINE_HIDE_MODEL_SPLIT:-0}"
HIDE_COST="${CLAUDE_STATUSLINE_HIDE_COST:-0}"

# Pet (set to 1 to enable — off by default)
SHOW_PET="${CLAUDE_STATUSLINE_PET:-0}"
# Pet type: cat (default), dog, squirrel, fish, mouse, parrot, octopus, unicorn
PET_TYPE="${CLAUDE_STATUSLINE_PET_TYPE:-cat}"

# Colors — real ESC bytes via printf, safe in any output context
cyan=$(printf '\033[36m')
yellow=$(printf '\033[33m')
green=$(printf '\033[32m')
red=$(printf '\033[31m')
magenta=$(printf '\033[35m')
dim=$(printf '\033[2m')
reset=$(printf '\033[0m')

# ── OS detection ─────────────────────────────────────────────────────────────
os=$(uname -s)
is_wsl=0
if [ "$os" = "Linux" ] && [ -f /proc/version ]; then
  case $(cat /proc/version) in
    *[Mm]icrosoft*) is_wsl=1 ;;
  esac
fi

# ── Portable file mtime (seconds since epoch) ────────────────────────────────
_file_mtime() {
  if [ "$os" = "Darwin" ]; then
    stat -f %m "$1" 2>/dev/null || echo 0
  else
    stat -c %Y "$1" 2>/dev/null || echo 0
  fi
}

# ── Portable ISO-8601 timestamp → epoch ──────────────────────────────────────
_iso_to_epoch() {
  ts="$1"
  if [ "$os" = "Darwin" ]; then
    # Strip fractional seconds, normalize timezone for macOS date
    ts_clean=$(echo "$ts" \
      | sed 's/\.[0-9]*//' \
      | sed 's/+\([0-9][0-9]\):\([0-9][0-9]\)$/+\1\2/' \
      | sed 's/Z$/+0000/')
    date -j -f "%Y-%m-%dT%H:%M:%S%z" "$ts_clean" +%s 2>/dev/null
  else
    # GNU date handles ISO-8601 natively
    date -d "$ts" +%s 2>/dev/null
  fi
}

# ── OAuth token: keychain (macOS) / secret-tool (Linux) / config files ───────
_read_token() {
  if [ "$os" = "Darwin" ]; then
    security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
      | jq -r '.claudeAiOauth.accessToken // .accessToken // empty' 2>/dev/null
    return
  fi

  # WSL: try reading from Windows-side Claude Code credential files
  if [ "$is_wsl" = "1" ]; then
    _win_appdata=$(wslpath "$(cmd.exe /C "echo %APPDATA%" 2>/dev/null | tr -d '\r')" 2>/dev/null)
    if [ -n "$_win_appdata" ]; then
      for _wf in \
        "$_win_appdata/Claude/claude_code_credentials.json" \
        "$_win_appdata/claude-code/credentials.json"
      do
        if [ -f "$_wf" ]; then
          jq -r '.claudeAiOauth.accessToken // .accessToken // empty' "$_wf" 2>/dev/null
          return
        fi
      done
    fi
  fi

  # Linux: try secret-tool (libsecret / GNOME keyring / KWallet bridge)
  if command -v secret-tool >/dev/null 2>&1; then
    _st=$(secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
    if [ -n "$_st" ]; then
      echo "$_st" \
        | jq -r '.claudeAiOauth.accessToken // .accessToken // empty' 2>/dev/null
      return
    fi
  fi

  # Linux/WSL fallback: read from credential files Claude Code may write
  for _f in \
    "$HOME/.config/Claude/claude_code_credentials.json" \
    "$HOME/.config/claude-code/credentials.json" \
    "$HOME/.claude/credentials.json"
  do
    if [ -f "$_f" ]; then
      jq -r '.claudeAiOauth.accessToken // .accessToken // empty' "$_f" 2>/dev/null
      return
    fi
  done
}

# ── Usage API (5-hour session + 7-day weekly) ────────────────────────────────
CACHE_FILE="$HOME/.claude/.usage_cache.json"
COST_BASELINE_FILE="$HOME/.claude/.cost_baseline.json"

_fetch_usage() {
  now=$(date +%s)

  if [ -f "$CACHE_FILE" ]; then
    cache_mtime=$(_file_mtime "$CACHE_FILE")
    age=$(( now - cache_mtime ))
    if [ "$age" -lt "$CACHE_TTL" ]; then
      cat "$CACHE_FILE"
      return 0
    fi
  fi

  token=$(_read_token)

  if [ -z "$token" ]; then
    [ -f "$CACHE_FILE" ] && cat "$CACHE_FILE"
    return 1
  fi

  # curl is optional — skip API call if not available
  if ! command -v curl >/dev/null 2>&1; then
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

# ── Session cost baseline ────────────────────────────────────────────────────
# Stores the used_credits value at session start so we can show the delta.
# A "session" resets if the baseline file is older than 6 hours or missing.
SESSION_COST_TTL="${CLAUDE_STATUSLINE_SESSION_COST_TTL:-21600}"  # 6h default

_session_cost() {
  current_credits="$1"
  [ -z "$current_credits" ] && echo "" && return

  now=$(date +%s)
  baseline_credits=""

  if [ -f "$COST_BASELINE_FILE" ]; then
    baseline_mtime=$(_file_mtime "$COST_BASELINE_FILE")
    age=$(( now - baseline_mtime ))
    if [ "$age" -lt "$SESSION_COST_TTL" ]; then
      baseline_credits=$(cat "$COST_BASELINE_FILE")
    fi
  fi

  # No baseline or expired — set it now
  if [ -z "$baseline_credits" ]; then
    mkdir -p "$(dirname "$COST_BASELINE_FILE")"
    echo "$current_credits" > "$COST_BASELINE_FILE"
    echo "0"
    return
  fi

  # Compute delta
  echo "$current_credits $baseline_credits" | awk '{d=$1-$2; if(d<0)d=0; printf "%.2f", d}'
}

# ── Stale cache detection ────────────────────────────────────────────────────
_is_cache_stale() {
  [ -f "$CACHE_FILE" ] || return 1
  cache_mtime=$(_file_mtime "$CACHE_FILE")
  now=$(date +%s)
  age=$(( now - cache_mtime ))
  [ "$age" -ge "$STALE_TTL" ]
}

# ── Color helper for percentages ─────────────────────────────────────────────
_pct_color() {
  pct="$1"
  echo "$pct" | awk -v g="$green" -v y="$yellow" -v r="$red" \
    -v wp="$WARN_PCT" -v cp="$CRIT_PCT" \
    '{if($1+0<wp) printf g; else if($1+0<cp) printf y; else printf r}'
}

# ── Fetch usage data ─────────────────────────────────────────────────────────
usage_data=""
if [ "$HIDE_USAGE" != "1" ]; then
  usage_data=$(_fetch_usage 2>/dev/null)
fi

session_pct=""
weekly_pct=""
session_reset_part=""
plan_tier=""
stale_marker=""

# Plan tier: CLAUDE_PLAN env var takes priority, then infer from API response
if [ -n "$CLAUDE_PLAN" ]; then
  plan_tier=$(echo "$CLAUDE_PLAN" | tr '[:upper:]' '[:lower:]')
elif [ -n "$usage_data" ]; then
  _opus=$(echo "$usage_data" | jq -r '.seven_day_opus // empty')
  _cowork=$(echo "$usage_data" | jq -r '.seven_day_cowork // empty')
  if [ -n "$_opus" ]; then
    plan_tier="max"
  elif [ -n "$_cowork" ]; then
    plan_tier="team"
  else
    plan_tier="pro"
  fi
fi

if [ -n "$usage_data" ]; then
  session_raw=$(echo "$usage_data" | jq -r '.five_hour.utilization // empty')
  weekly_raw=$(echo "$usage_data"  | jq -r '.seven_day.utilization // empty')
  session_reset_at=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')

  if [ -n "$session_raw" ]; then
    session_pct=$(echo "$session_raw" | awk '{v=$1+0; if(v>100)v=100; printf "%.1f", v}')
  fi
  if [ -n "$weekly_raw" ]; then
    weekly_pct=$(echo "$weekly_raw" | awk '{v=$1+0; if(v>100)v=100; printf "%.1f", v}')
  fi

  # Format reset countdown
  _fmt_reset() {
    ts="$1"
    [ -z "$ts" ] && return
    reset_epoch=$(_iso_to_epoch "$ts")
    [ -z "$reset_epoch" ] && return
    now_epoch=$(date +%s)
    diff=$(( reset_epoch - now_epoch ))
    [ "$diff" -le 0 ] && echo "soon" && return
    hrs=$(( diff / 3600 ))
    mins=$(( (diff % 3600) / 60 ))
    [ "$hrs" -gt 0 ] && echo "${hrs}h${mins}m" || echo "${mins}m"
  }

  [ -n "$session_reset_at" ] && session_reset_part=$(_fmt_reset "$session_reset_at")

  # Stale cache indicator
  if _is_cache_stale; then
    stale_marker=" ${dim}*${reset}"
  fi

  # ── Extra usage / cost tracking ──────────────────────────────────────────
  extra_credits=$(echo "$usage_data" | jq -r '.extra_usage.used_credits // empty')
  extra_limit=$(echo "$usage_data" | jq -r '.extra_usage.monthly_limit // empty')
  extra_enabled=$(echo "$usage_data" | jq -r '.extra_usage.is_enabled // empty')

  # ── Per-model usage split (Opus / Sonnet) ────────────────────────────────
  opus_pct=$(echo "$usage_data" | jq -r '.seven_day_opus.utilization // empty')
  sonnet_pct=$(echo "$usage_data" | jq -r '.seven_day_sonnet.utilization // empty')
fi

# ── Model name (strip redundant context size — already shown in the bar) ──────
model_raw=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')
model=$(echo "$model_raw" | sed 's/ ([0-9.]*[KMkm] context)//' | sed 's/^claude-//')

# ── Git branch + change count (optional — skipped if git not available) ──────
cwd=$(echo "$input" | jq -r '.cwd // empty')
branch=""
branch_part=""
if [ "$HIDE_GIT" != "1" ] && [ -n "$cwd" ] && [ -d "$cwd" ] && command -v git >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  change_count=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  if [ -n "$branch" ]; then
    if [ -n "$change_count" ] && [ "$change_count" -gt 0 ]; then
      branch_part="${yellow}${branch} (${change_count})${reset} | "
    else
      branch_part="${yellow}${branch}${reset} | "
    fi
  fi
fi

# ── Plan badge ───────────────────────────────────────────────────────────────
case "$plan_tier" in
  *max*)        plan_badge="Max" ;;
  *pro*)        plan_badge="Pro" ;;
  *team*)       plan_badge="Team" ;;
  *enterprise*) plan_badge="Ent" ;;
  *)            plan_badge="" ;;
esac

model_part=""
if [ "$HIDE_MODEL" != "1" ]; then
  if [ -n "$plan_badge" ]; then
    model_part="${cyan}${model}${reset} ${dim}(${plan_badge})${reset}"
  else
    model_part="${cyan}${model}${reset}"
  fi
fi

# ── Context window ───────────────────────────────────────────────────────────
used=$(echo "$input"        | jq -r '.context_window.used_percentage // empty')
window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Fallback: env var → plan-based default
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

# ── Context bar ──────────────────────────────────────────────────────────────
ctx_part=""
if [ "$HIDE_CONTEXT" != "1" ]; then
  if [ -z "$used" ]; then
    # Build empty bar dynamically based on BAR_WIDTH
    empty_bar=""
    i=0
    while [ "$i" -lt "$BAR_WIDTH" ]; do empty_bar="${empty_bar}-"; i=$(( i + 1 )); done
    ctx_part="[${empty_bar}] -%"
  else
    used_int=$(printf "%.0f" "$used")

    if [ "$used_int" -lt "$WARN_PCT" ]; then
      bar_color="$green"
    elif [ "$used_int" -lt "$CRIT_PCT" ]; then
      bar_color="$yellow"
    else
      bar_color="$red"
    fi

    filled=$(( used_int * BAR_WIDTH / 100 ))
    empty=$(( BAR_WIDTH - filled ))

    bar=""
    i=0
    while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$(( i + 1 )); done
    i=0
    while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$(( i + 1 )); done

    if [ -n "$window_size" ]; then
      token_part=$(awk -v p="$used_int" -v w="$window_size" 'BEGIN{
        u=p*w/100
        if(u>=1000000) uf=sprintf("%.1fM",u/1000000); else uf=sprintf("%dk",u/1000)
        if(w>=1000000) wf=sprintf("%.1fM",w/1000000); else wf=sprintf("%dk",w/1000)
        # Clean up trailing .0 on M values (1.0M → 1M)
        gsub(/\.0M/,"M",uf); gsub(/\.0M/,"M",wf)
        printf "(%s/%s)", uf, wf
      }')
      token_part=" ${dim}${token_part}${reset}"
    else
      token_part=""
    fi

    ctx_part="${bar_color}[${bar}]${reset} ${bar_color}${used_int}%${reset}${token_part}"
  fi
fi

# ── Usage (session + reset + weekly) ─────────────────────────────────────────
usage_part=""
if [ "$HIDE_USAGE" != "1" ] && { [ -n "$session_pct" ] || [ -n "$weekly_pct" ]; }; then
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
  # Per-model split (show when available and not hidden)
  model_split=""
  if [ "$HIDE_MODEL_SPLIT" != "1" ] && [ -n "$opus_pct" ]; then
    _oc=$(_pct_color "$opus_pct")
    opus_fmt=$(echo "$opus_pct" | awk '{v=$1+0; if(v>100)v=100; printf "%.0f", v}')
    model_split="${model_split}Opus:${_oc}${opus_fmt}%${reset}"
  fi
  if [ "$HIDE_MODEL_SPLIT" != "1" ] && [ -n "$sonnet_pct" ]; then
    _snc=$(_pct_color "$sonnet_pct")
    sonnet_fmt=$(echo "$sonnet_pct" | awk '{v=$1+0; if(v>100)v=100; printf "%.0f", v}')
    [ -n "$model_split" ] && model_split="${model_split} "
    model_split="${model_split}Sonnet:${_snc}${sonnet_fmt}%${reset}"
  fi
  if [ -n "$model_split" ]; then
    usage_part="${usage_part} | ${dim}[${reset}${model_split}${dim}]${reset}"
  fi

  # Extra usage cost — shows session delta (how much spent since session start)
  if [ "$HIDE_COST" != "1" ] && [ "$extra_enabled" = "true" ] && [ -n "$extra_credits" ]; then
    session_cost=$(_session_cost "$extra_credits")
    # Only show cost segment if there's actual session spend
    if [ -n "$session_cost" ] && echo "$session_cost" | awk '{exit ($1+0 > 0) ? 0 : 1}'; then
      cost_val=$(printf '$%.2f' "$session_cost")
      if [ -n "$extra_limit" ] && [ "$extra_limit" != "null" ]; then
        total_val=$(echo "$extra_credits" | awk '{printf "$%.2f", $1+0}')
        limit_val=$(echo "$extra_limit" | awk '{printf "$%.0f", $1+0}')
        cost_display="${cost_val} (${total_val}/${limit_val})"
      else
        cost_display="${cost_val}"
      fi
      if [ -n "$extra_limit" ] && [ "$extra_limit" != "null" ]; then
        cost_color=$(echo "$extra_credits $extra_limit" | awk -v y="$yellow" -v r="$red" \
          '{if($2+0>0 && ($1/$2)*100>=75) printf r; else printf y}')
      else
        cost_color="$yellow"
      fi
      usage_part="${usage_part} | Cost: ${cost_color}${cost_display}${reset}"
    fi
  fi

  # Append stale marker if cache is old
  usage_part="${usage_part}${stale_marker}"
fi

# ── Pet (optional animated companion) ─────────────────────────────────────────
pet_part=""
if [ "$SHOW_PET" = "1" ]; then
  # Pick pet color based on session usage (mood)
  if [ -n "$session_pct" ]; then
    pet_mood=$(echo "$session_pct" | awk -v wp="$WARN_PCT" -v cp="$CRIT_PCT" \
      '{if($1+0<wp) print "happy"; else if($1+0<cp) print "busy"; else print "stressed"}')
  else
    pet_mood="happy"
  fi

  case "$pet_mood" in
    happy)    pet_color="$cyan" ;;
    busy)     pet_color="$yellow" ;;
    stressed) pet_color="$red" ;;
  esac

  # Pick emoticon based on pet type
  case "$PET_TYPE" in
    dog)      pet_icon="🐶" ;;
    squirrel) pet_icon="🐿️"  ;;
    fish)     pet_icon="🐟" ;;
    mouse)    pet_icon="🐭" ;;
    parrot)   pet_icon="🦜" ;;
    octopus)  pet_icon="🐙" ;;
    unicorn)  pet_icon="🦄" ;;
    *)        pet_icon="🐱" ;; # cat (default)
  esac

  pet_part=" | ${pet_color}${pet_icon}${reset}"
fi

# ── Assemble output ──────────────────────────────────────────────────────────
output=""
[ -n "$branch_part" ] && output="${output}${branch_part}"
if [ -n "$model_part" ] && [ -n "$ctx_part" ]; then
  output="${output}${model_part} | ${ctx_part}"
elif [ -n "$model_part" ]; then
  output="${output}${model_part}"
elif [ -n "$ctx_part" ]; then
  output="${output}${ctx_part}"
fi
output="${output}${usage_part}${pet_part}"

# printf '%s' avoids format string injection from variable content
printf '%s' "$output"
