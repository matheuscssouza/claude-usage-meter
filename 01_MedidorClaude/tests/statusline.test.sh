#!/bin/bash
# Black-box tests for statusline/statusline.sh: feeds JSON on stdin, asserts on the rendered line.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/statusline/statusline.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export MEDIDOR_STATE_DIR="$TMP/state"
fail=0

# render <five_hour_pct> <context_pct> <minutes_since_activity>
render() {
  local transcript="$TMP/t.jsonl"; : > "$transcript"
  touch -t "$(date -v-"$3"M +%Y%m%d%H%M.%S)" "$transcript"
  jq -n --arg t "$transcript" --argjson h "$1" --argjson c "$2" --argjson r "$(( $(date +%s) + 3600 ))" '
    {session_id: "test", transcript_path: $t,
     rate_limits: {five_hour: {used_percentage: $h, resets_at: $r}, seven_day: {used_percentage: 10, resets_at: $r}},
     context_window: {used_percentage: $c, context_window_size: 200000}}' | "$SCRIPT" | sed $'s/\033\\[[0-9;]*m//g'
}

expect() { # expect <description> <needle> <haystack>
  if [[ "$3" == *"$2"* ]]; then echo "ok   $1"; else echo "FAIL $1 (wanted '$2' in: $3)"; fail=1; fi
}

expect "healthy under 50%"            "saudável"      "$(render 20 20 1)"
expect "attention from 50%"           "atenção"       "$(render 60 20 1)"
expect "heavy from 80%"               "pesada"        "$(render 85 20 1)"
expect "new session from 96%"         "NOVA SESSÃO"   "$(render 97 20 1)"
expect "context drives health"        "pesada"        "$(render 10 85 1)"
expect "cache active (>30 min left)"  "🔥 ativo"       "$(render 20 20 5)"
expect "cache cooling (30-10 min)"    "💨 esfriando"   "$(render 20 20 40)"
expect "cache ending (<=10 min)"      "💀 acabando"    "$(render 20 20 55)"
expect "cache expired"                "💀 expirado"    "$(render 20 20 70)"
expect "context size shown"           "/200k"         "$(render 20 20 1)"
[ -f "$MEDIDOR_STATE_DIR/sessions/test.json" ] && echo "ok   per-session state written" || { echo "FAIL per-session state"; fail=1; }

exit $fail
