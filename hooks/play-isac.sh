#!/bin/bash
# ============================================================
# play-isac.sh — Division ISAC sound playback script
#
# Usage:
#   play-isac.sh <event> [cooldown-seconds]
#
# Examples:
#   play-isac.sh session-start         -> transmission_in + online_1 + transmission_out
#   play-isac.sh permission            -> transmission_in only (awaiting authorization)
#   play-isac.sh permission-out        -> transmission_out only (authorization resolved)
#   play-isac.sh stop                  -> transmission_in + random mission_complete + transmission_out
#   play-isac.sh web-search-pre 5      -> 5s cooldown, in -> random darkzone_enter -> out
#   play-isac.sh mcp-pre 5             -> 5s cooldown, in -> random contaminated_zone_enter -> out
# ============================================================

SOUNDS_DIR="$HOME/.claude/sounds/division"
EVENT="$1"
COOLDOWN="${2:-0}"

# --- Platform-specific playback (synchronous for sequence ordering) ---
play_file() {
  local file="$1"
  [[ ! -f "$file" ]] && return
  if [[ "$OSTYPE" == "darwin"* ]]; then
    afplay "$file" 2>/dev/null
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v paplay &>/dev/null; then
      paplay "$file" 2>/dev/null
    elif command -v aplay &>/dev/null; then
      aplay "$file" 2>/dev/null
    elif command -v ffplay &>/dev/null; then
      ffplay -nodisp -autoexit "$file" 2>/dev/null
    fi
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    powershell.exe -c "(New-Object Media.SoundPlayer '$file').PlaySync()" 2>/dev/null
  fi
}

# --- Pick random element from array ---
pick_random() {
  local arr=("$@")
  echo "${arr[$RANDOM % ${#arr[@]}]}"
}

# --- Cooldown check ---
if [[ "$COOLDOWN" -gt 0 ]]; then
  LOCK_FILE="/tmp/claude-isac-${EVENT}.last"
  NOW=$(date +%s)
  if [[ -f "$LOCK_FILE" ]]; then
    LAST=$(cat "$LOCK_FILE" 2>/dev/null || echo "0")
    DIFF=$((NOW - LAST))
    [[ $DIFF -lt $COOLDOWN ]] && exit 0
  fi
  echo "$NOW" > "$LOCK_FILE"
fi

# --- Determine sound for event ---
MAIN_SOUND=""

case "$EVENT" in
  session-start)
    MAIN_SOUND="$SOUNDS_DIR/ISAC-online_1.mp3"
    ;;
  stop)
    MAIN_SOUND=$(pick_random \
      "$SOUNDS_DIR/ISAC-mission_complete_1.mp3" \
      "$SOUNDS_DIR/ISAC-mission_complete_2.mp3" \
      "$SOUNDS_DIR/ISAC-mission_complete_3.mp3")
    ;;
  subagent-start)
    MAIN_SOUND=$(pick_random \
      "$SOUNDS_DIR/ISAC-agent_join_1.mp3" \
      "$SOUNDS_DIR/ISAC-agent_join_2.mp3" \
      "$SOUNDS_DIR/ISAC-agent_join_3.mp3")
    ;;
  subagent-stop)
    MAIN_SOUND=$(pick_random \
      "$SOUNDS_DIR/ISAC-agent_left_1.mp3" \
      "$SOUNDS_DIR/ISAC-agent_left_2.mp3" \
      "$SOUNDS_DIR/ISAC-agent_left_3.mp3")
    ;;
  teammate-idle)
    MAIN_SOUND=$(pick_random \
      "$SOUNDS_DIR/ISAC-agent_down_1.mp3" \
      "$SOUNDS_DIR/ISAC-agent_down_2.mp3" \
      "$SOUNDS_DIR/ISAC-agent_down_3.mp3" \
      "$SOUNDS_DIR/ISAC-agent_down_4.mp3")
    ;;
  task-completed)
    MAIN_SOUND=$(pick_random \
      "$SOUNDS_DIR/ISAC-checkpoint_update_1.mp3" \
      "$SOUNDS_DIR/ISAC-checkpoint_update_2.mp3" \
      "$SOUNDS_DIR/ISAC-checkpoint_update_3.mp3")
    ;;
  permission)
    MAIN_SOUND="$SOUNDS_DIR/ISAC-database_access.mp3"
    ;;
  permission-out)
    exit 0
    ;;
  prompt-submit)
    MAIN_SOUND=$(pick_random \
      "$SOUNDS_DIR/ISAC-mission_start_1.mp3" \
      "$SOUNDS_DIR/ISAC-mission_start_2.mp3" \
      "$SOUNDS_DIR/ISAC-mission_start_3.mp3")
    ;;
  web-search-pre)
    MAIN_SOUND=$(pick_random \
      "$SOUNDS_DIR/ISAC-darkzone_enter_1.mp3" \
      "$SOUNDS_DIR/ISAC-darkzone_enter_2.mp3" \
      "$SOUNDS_DIR/ISAC-darkzone_enter_3.mp3")
    ;;
  web-search-post)
    MAIN_SOUND=$(pick_random \
      "$SOUNDS_DIR/ISAC-darkzone_exit_1.mp3" \
      "$SOUNDS_DIR/ISAC-darkzone_exit_2.mp3")
    ;;
  mcp-pre)
    MAIN_SOUND=$(pick_random \
      "$SOUNDS_DIR/ISAC-contaminated_zone_enter_1.mp3" \
      "$SOUNDS_DIR/ISAC-contaminated_zone_enter_2.mp3")
    ;;
  mcp-post)
    MAIN_SOUND=$(pick_random \
      "$SOUNDS_DIR/ISAC-contaminated_zone_exit_1.mp3" \
      "$SOUNDS_DIR/ISAC-contaminated_zone_exit_2.mp3")
    ;;
  failure)
    MAIN_SOUND="$SOUNDS_DIR/ISAC-lockpick_required.mp3"
    ;;
  compact)
    MAIN_SOUND="$SOUNDS_DIR/ISAC-backup_activated.mp3"
    ;;
  *)
    exit 0
    ;;
esac

# Exit silently if no main sound found
[[ -z "$MAIN_SOUND" || ! -f "$MAIN_SOUND" ]] && exit 0

# --- Global playback lock (prevent overlapping sounds across sessions) ---
LOCK_DIR="/tmp/claude-isac-playback.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # Stale lock recovery: if lock is older than 10s, assume crash and reclaim
  if [[ -d "$LOCK_DIR" ]] && [[ $(($(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo "0"))) -gt 10 ]]; then
    rmdir "$LOCK_DIR" 2>/dev/null
    mkdir "$LOCK_DIR" 2>/dev/null || exit 0
  else
    exit 0
  fi
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

# --- Playback execution ---
# Wrapped events: transmission_in -> main -> transmission_out (sequential)
play_file "$SOUNDS_DIR/ISAC-transmission_in.mp3"
play_file "$MAIN_SOUND"
play_file "$SOUNDS_DIR/ISAC-transmission_out.mp3"
