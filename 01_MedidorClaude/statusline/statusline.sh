#!/bin/bash
# Claude Code status line: 5h window, weekly limit, context and session health.
in=$(cat)
STATE_DIR="${MEDIDOR_STATE_DIR:-$HOME/.claude/medidor}"
mkdir -p "$STATE_DIR"
now=$(date +%s)
echo "$in" > "$STATE_DIR"/usage.json.tmp && mv "$STATE_DIR"/usage.json.tmp "$STATE_DIR"/usage.json
sid=$(echo "$in" | jq -r '.session_id // empty')
if [ -n "$sid" ]; then
  mkdir -p "$STATE_DIR"/sessions
  echo "$in" > "$STATE_DIR"/sessions/$sid.tmp && mv "$STATE_DIR"/sessions/$sid.tmp "$STATE_DIR"/sessions/$sid.json
fi

h=$(echo "$in" | jq -r '.rate_limits.five_hour.used_percentage // empty')
hr=$(echo "$in" | jq -r '.rate_limits.five_hour.resets_at // empty')
w=$(echo "$in" | jq -r '.rate_limits.seven_day.used_percentage // empty')
wr=$(echo "$in" | jq -r '.rate_limits.seven_day.resets_at // empty')
c=$(echo "$in" | jq -r '.context_window.used_percentage // empty')
tp=$(echo "$in" | jq -r '.transcript_path // empty')
cs=$(echo "$in" | jq -r '.context_window.context_window_size // empty')

G=$'\033[32m'; Y=$'\033[33m'; O=$'\033[38;5;208m'; R=$'\033[31m'; D=$'\033[2m'; N=$'\033[0m'

tok() { awk -v n="$1" 'BEGIN{ if(n>=1000000) printf "%.1fM", n/1000000; else printf "%.0fk", n/1000 }'; }
int() { printf '%.0f' "${1:-0}"; }
left() { # epoch -> "2h13m" / "3d4h"
  local s=$(( $1 - now )); [ "$s" -lt 0 ] && s=0
  if [ "$s" -ge 86400 ]; then echo "$((s/86400))d$(((s%86400)/3600))h"
  else echo "$((s/3600))h$(((s%3600)/60))m"; fi
}
bar() { # pct -> barra de 10
  local p=$1 n i out=""; n=$(( p/10 )); [ $n -gt 10 ] && n=10
  for ((i=0;i<10;i++)); do [ $i -lt $n ] && out+="█" || out+="░"; done; echo "$out"
}
col() { local p=$1; if [ "$p" -ge 96 ]; then echo "$R"; elif [ "$p" -ge 80 ]; then echo "$O"; elif [ "$p" -ge 50 ]; then echo "$Y"; else echo "$G"; fi; }

out=""
worst=0
if [ -n "$h" ]; then
  hp=$(int "$h"); worst=$hp
  t=""; [ -n "$hr" ] && t=" ↻$(left "$hr")"
  out+="5h $(col $hp)$(bar $hp) ${hp}%${N}${D}${t}${N}"
fi
if [ -n "$w" ]; then
  wp=$(int "$w")
  t=""; [ -n "$wr" ] && t=" ↻$(left "$wr")"
  [ -n "$out" ] && out+="  │  "
  out+="Sem $(col $wp)$(bar $wp) ${wp}%${N}${D}${t}${N}"
  [ "$wp" -gt "$worst" ] && worst=$wp
fi
if [ -n "$c" ]; then
  cp=$(int "$c")
  [ -n "$out" ] && out+="  │  "
  det=""
  [ -n "$cs" ] && det="${D} $(tok $(awk -v p="$c" -v s="$cs" 'BEGIN{printf "%d", p*s/100}'))/$(tok "$cs")${N}"
  out+="Ctx $(col $cp)${cp}%${N}${det}"
  [ "$cp" -gt "$worst" ] && worst=$cp
fi

# Prompt caching: assumes a 1h TTL counted from the last real activity (transcript mtime).
TTL=3600
if [ -n "$tp" ] && [ -f "$tp" ]; then
  idle=$(( now - $(stat -f %m "$tp") )); rest=$(( TTL - idle ))
  [ -n "$out" ] && out+="  │  "
  m=$(( (rest+59)/60 ))
  if   [ "$rest" -gt 1800 ]; then out+="${O}🔥 ativo ${m} min${N}"
  elif [ "$rest" -gt 600 ];  then out+="${D}💨 esfriando ${m} min${N}"
  elif [ "$rest" -gt 0 ];    then out+="${R}💀 acabando ${m} min${N}"
  else out+="${R}💀 expirado${N}"; fi
fi

# Session health: worst of 5h window, weekly limit and context.
if   [ "$worst" -ge 96 ]; then s="${R}● NOVA SESSÃO${N}"
elif [ "$worst" -ge 80 ]; then s="${O}● pesada${N}"
elif [ "$worst" -ge 50 ]; then s="${Y}● atenção${N}"
else s="${G}● saudável${N}"; fi

[ -z "$out" ] && out="${D}sem dados de limite ainda${N}"
echo "$out  │  $s"
