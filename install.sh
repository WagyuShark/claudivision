#!/bin/bash
# ============================================================
# install.sh — Install Division ISAC sounds for Claude Code
#
# Copies sound files and playback script to ~/.claude/,
# then merges hook entries into ~/.claude/settings.json.
#
# Usage:
#   ./install.sh           # install
#   ./install.sh --remove  # uninstall
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOUNDS_SRC="$SCRIPT_DIR/sounds"
HOOK_SRC="$SCRIPT_DIR/hooks/play-isac.sh"
SOUNDS_DEST="$HOME/.claude/sounds/division"
HOOK_DEST="$HOME/.claude/hooks/play-isac.sh"
SETTINGS="$HOME/.claude/settings.json"
BACKUP="$HOME/.claude/settings.json.backup"
# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[ISAC]${NC} $1"; }
ok()    { echo -e "${GREEN}[ISAC]${NC} $1"; }
err()   { echo -e "${RED}[ISAC]${NC} $1"; }

# --- Uninstall ---
if [[ "${1:-}" == "--remove" ]]; then
  info "Removing Division ISAC sounds..."

  if [[ -d "$SOUNDS_DEST" ]]; then
    rm -rf "$SOUNDS_DEST"
    ok "Removed $SOUNDS_DEST"
  fi

  if [[ -f "$HOOK_DEST" ]]; then
    rm -f "$HOOK_DEST"
    ok "Removed $HOOK_DEST"
  fi

  if [[ -f "$SETTINGS" ]] && command -v python3 &>/dev/null; then
    python3 -c "
import json

with open('$SETTINGS', 'r') as f:
    cfg = json.load(f)

if 'hooks' in cfg:
    marker = 'play-isac.sh'
    for event_name in list(cfg['hooks'].keys()):
        entries = cfg['hooks'][event_name]
        filtered = []
        for entry in entries:
            hooks_list = entry.get('hooks', [])
            clean = [h for h in hooks_list if marker not in h.get('command', '')]
            if clean:
                entry['hooks'] = clean
                filtered.append(entry)
        if filtered:
            cfg['hooks'][event_name] = filtered
        else:
            del cfg['hooks'][event_name]
    if not cfg['hooks']:
        del cfg['hooks']

with open('$SETTINGS', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
"
    ok "Removed ISAC hooks from settings.json (other hooks preserved)"
  fi

  # Clean up cooldown lock files
  rm -f /tmp/claude-isac-*.last 2>/dev/null

  ok "Uninstall complete."
  exit 0
fi

# --- Pre-flight checks ---
if [[ ! -d "$SOUNDS_SRC" ]]; then
  err "Sound files not found at $SOUNDS_SRC"
  err "Make sure you run this script from the repository root."
  exit 1
fi

if [[ ! -f "$HOOK_SRC" ]]; then
  err "Hook script not found at $HOOK_SRC"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  err "python3 is required to merge settings.json"
  exit 1
fi

# --- Install ---
info "Installing Division ISAC sounds for Claude Code..."

# 1. Copy sounds
mkdir -p "$SOUNDS_DEST"
cp "$SOUNDS_SRC/"*.mp3 "$SOUNDS_DEST/"
ok "Copied sound files to $SOUNDS_DEST ($(ls "$SOUNDS_DEST"/*.mp3 | wc -l | tr -d ' ') files)"

# 2. Copy hook script
mkdir -p "$(dirname "$HOOK_DEST")"
cp "$HOOK_SRC" "$HOOK_DEST"
chmod +x "$HOOK_DEST"
ok "Installed hook script to $HOOK_DEST"

# 3. Merge hooks into settings.json
if [[ -f "$SETTINGS" ]]; then
  cp "$SETTINGS" "$BACKUP"
  info "Backed up existing settings to $BACKUP"
fi

HOOKS_JSON='{
  "SessionStart": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh session-start &"}]}],
  "Stop": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh stop &"}]}],
  "SubagentStart": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh subagent-start &"}]}],
  "SubagentStop": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh subagent-stop &"}]}],
  "TeammateIdle": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh teammate-idle &"}]}],
  "TaskCompleted": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh task-completed &"}]}],
  "PermissionRequest": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh permission &"}]}],
  "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh prompt-submit &"}]}],
  "PreToolUse": [
    {"matcher": ".*", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh permission-out &"}]},
    {"matcher": "WebSearch|WebFetch", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh web-search-pre 5 &"}]},
    {"matcher": "mcp__.*", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh mcp-pre 5 &"}]}
  ],
  "PostToolUse": [
    {"matcher": "WebSearch|WebFetch", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh web-search-post 5 &"}]},
    {"matcher": "mcp__.*", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh mcp-post 5 &"}]}
  ],
  "PostToolUseFailure": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh failure 15 &"}]}],
  "PreCompact": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/play-isac.sh compact &"}]}]
}'

python3 -c "
import json, sys

settings_path = '$SETTINGS'
hooks = json.loads('''$HOOKS_JSON''')

try:
    with open(settings_path, 'r') as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

existing_hooks = cfg.get('hooks', {})
for event_name, new_entries in hooks.items():
    if event_name not in existing_hooks:
        existing_hooks[event_name] = new_entries
    else:
        # Remove any previous ISAC entries, then append new ones
        marker = 'play-isac.sh'
        cleaned = [e for e in existing_hooks[event_name]
                   if not any(marker in h.get('command', '') for h in e.get('hooks', []))]
        cleaned.extend(new_entries)
        existing_hooks[event_name] = cleaned
cfg['hooks'] = existing_hooks

with open(settings_path, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
"
ok "Merged hooks into $SETTINGS"

echo ""
ok "Installation complete! ISAC is now online."
info "Restart Claude Code to activate sound hooks."
info "To uninstall: ./install.sh --remove"
