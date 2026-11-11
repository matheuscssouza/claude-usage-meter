#!/bin/bash
# Claude Code status line: 5h window, weekly limit, context, prompt caching and session health.
# Reads the status line JSON payload on stdin, persists it for the menu bar app, prints one line.
in=$(cat)
umask 077   # state files hold project paths; keep them private to the user

STATE_DIR="${USAGE_METER_STATE_DIR:-$HOME/.claude/usage-meter}"
now=$(date +%s)

# --- persist state for the menu bar app (atomic writes) ----------------------------------------
mkdir -p "$STATE_DIR/sessions"
echo "$in" > "$STATE_DIR/usage.json.tmp" && mv "$STATE_DIR/usage.json.tmp" "$STATE_DIR/usage.json"
sid=$(echo "$in" | jq -r '.session_id // empty')
sid=${sid//[^A-Za-z0-9_-]/}   # defensive: ids become file names
if [ -n "$sid" ]; then
  echo "$in" > "$STATE_DIR/sessions/$sid.tmp" && mv "$STATE_DIR/sessions/$sid.tmp" "$STATE_DIR/sessions/$sid.json"
fi

# --- extract fields -----------------------------------------------------------------------------
field() { echo "$in" | jq -r "$1 // empty"; }
h=$(field .rate_limits.five_hour.used_percentage);  hr=$(field .rate_limits.five_hour.resets_at)
w=$(field .rate_limits.seven_day.used_percentage);  wr=$(field .rate_limits.seven_day.resets_at)
c=$(field .context_window.used_percentage);         cs=$(field .context_window.context_window_size)
tp=$(field .transcript_path)

G=$'\033[32m'; Y=$'\033[33m'; O=$'\033[38;5;208m'; R=$'\033[31m'; D=$'\033[2m'; N=$'\033[0m'

# --- helpers ------------------------------------------------------------------------------------
int()  { printf '%.0f' "${1:-0}"; }
tok()  { awk -v n="$1" 'BEGIN{ if (n >= 1000000) printf "%.1fM", n/1000000; else printf "%.0fk", n/1000 }'; }
left() { # epoch -> "2h13m" or "3d4h"
  local s=$(( $1 - now )); [ "$s" -lt 0 ] && s=0
  if [ "$s" -ge 86400 ]; then echo "$((s/86400))d$(((s%86400)/3600))h"
  else echo "$((s/3600))h$(((s%3600)/60))m"; fi
}
bar() { # percent -> 10-cell bar
  local n=$(( $1 / 10 )) i out=""; [ "$n" -gt 10 ] && n=10
  for ((i = 0; i < 10; i++)); do [ "$i" -lt "$n" ] && out+="█" || out+="░"; done
  echo "$out"
}
col() { # percent -> color
  if   [ "$1" -ge 96 ]; then echo "$R"
  elif [ "$1" -ge 80 ]; then echo "$O"
  elif [ "$1" -ge 50 ]; then echo "$Y"
  else echo "$G"; fi
}

# --- segments -----------------------------------------------------------------------------------
out=""; worst=0
sep() { [ -n "$out" ] && out+="  │  "; }

if [ -n "$h" ]; then
  hp=$(int "$h"); worst=$hp; t=""; [ -n "$hr" ] && t=" ↻$(left "$hr")"
  out+="5h $(col "$hp")$(bar "$hp") ${hp}%${N}${D}${t}${N}"
fi
if [ -n "$w" ]; then
  wp=$(int "$w"); t=""; [ -n "$wr" ] && t=" ↻$(left "$wr")"
  sep; out+="Wk $(col "$wp")$(bar "$wp") ${wp}%${N}${D}${t}${N}"
  [ "$wp" -gt "$worst" ] && worst=$wp
fi
if [ -n "$c" ]; then
  cp=$(int "$c"); det=""
  [ -n "$cs" ] && det="${D} $(tok "$(awk -v p="$c" -v s="$cs" 'BEGIN{printf "%d", p*s/100}')")/$(tok "$cs")${N}"
  sep; out+="Ctx $(col "$cp")${cp}%${N}${det}"
  [ "$cp" -gt "$worst" ] && worst=$cp
fi

# Prompt caching: assumes a 1h TTL counted from the last real activity (transcript mtime).
TTL=3600
if [ -n "$tp" ] && [ -f "$tp" ]; then
  rest=$(( TTL - (now - $(stat -f %m "$tp")) )); m=$(( (rest + 59) / 60 ))
  sep
  if   [ "$rest" -gt 1800 ]; then out+="${O}🔥 active ${m} min${N}"
  elif [ "$rest" -gt 600 ];  then out+="${D}💨 cooling ${m} min${N}"
  elif [ "$rest" -gt 0 ];    then out+="${R}💀 ending ${m} min${N}"
  else out+="${R}💀 expired${N}"; fi
fi

# Session health: worst of 5h window, weekly limit and context.
if   [ "$worst" -ge 96 ]; then s="${R}● NEW SESSION${N}"
elif [ "$worst" -ge 80 ]; then s="${O}● heavy${N}"
elif [ "$worst" -ge 50 ]; then s="${Y}● attention${N}"
else s="${G}● healthy${N}"; fi

[ -z "$out" ] && out="${D}no limit data yet${N}"
echo "$out  │  $s"
