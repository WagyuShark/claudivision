# Claudivision

**ISAC sound hooks for Claude Code** - inspired by Tom Clancy's The Division.

Every Claude Code event triggers ISAC voice lines: session start, task completion, subagent join/leave, web searches entering the Dark Zone, MCP tool calls entering contaminated zones, and more.

https://github.com/user-attachments/assets/placeholder

## Quick Start

```bash
git clone https://github.com/w00ing/claudivision.git
cd claudivision
./install.sh
```

Restart Claude Code. ISAC is now online.

## Uninstall

```bash
./install.sh --remove
```

## What It Does

The installer copies sound files and a playback script to `~/.claude/`, then registers [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) in `~/.claude/settings.json`. Your existing settings and hooks from other tools are preserved.

### Sound Mapping

| Hook Event | Sound | Description |
|---|---|---|
| `SessionStart` | `ISAC-online` | ISAC system boot |
| `Stop` | `ISAC-mission_complete` (1-3) | Mission complete, random pick |
| `SubagentStart` | `ISAC-agent_join` (1-3) | Agent joined, random pick |
| `SubagentStop` | `ISAC-agent_left` (1-3) | Agent left, random pick |
| `TeammateIdle` | `ISAC-agent_down` (1-4) | Agent down, random pick |
| `TaskCompleted` | `ISAC-checkpoint_update` (1-3) | Checkpoint updated, random pick |
| `PermissionRequest` | `transmission_in` | ISAC awaiting authorization |
| `PreToolUse` (after permission) | `transmission_out` | Authorization resolved (flag-based) |
| `UserPromptSubmit` | `ISAC-mission_start` (1-3) | Mission start, random pick |
| `PreToolUse` (web) | `ISAC-darkzone_enter` (1-3) | Entering the Dark Zone |
| `PostToolUse` (web) | `ISAC-darkzone_exit` (1-2) | Leaving the Dark Zone |
| `PreToolUse` (MCP) | `ISAC-contaminated_zone_enter` (1-2) | Entering contaminated area |
| `PostToolUse` (MCP) | `ISAC-contaminated_zone_exit` (1-2) | Leaving contaminated area |
| `PostToolUseFailure` | `ISAC-lockpick_required` | Lockpick required |
| `PreCompact` | `ISAC-backup_activated` | Backup activated |

### Transmission Wrapping

Most events play a 3-part sequence:

```
transmission_in -> [main sound] -> transmission_out
```

`PermissionRequest` is special: `transmission_in` plays when the permission dialog appears, and `transmission_out` plays when you approve (the next `PreToolUse` fires). A flag file (`/tmp/claude-isac-permission-pending`) ensures `transmission_out` only plays after an actual permission request, not on every tool use.

### Cooldowns

| Event | Cooldown |
|---|---|
| Web search (Dark Zone) | 5 seconds |
| MCP tools (Contaminated Zone) | 5 seconds |
| Tool failure | 15 seconds |

High-frequency tool events (`PreToolUse`/`PostToolUse` for Bash, Read, Write, etc.) are intentionally excluded to avoid noise.

## How It Works

```
Claude Code event fires
  -> ~/.claude/settings.json hooks config matches the event
  -> play-isac.sh runs in background (&)
  -> Script checks cooldown, picks random sound variant
  -> afplay (macOS) / paplay (Linux) / powershell (Windows) plays the sequence
```

All playback runs in the background so Claude Code is never blocked.

## Platform Support

| Platform | Audio Backend |
|---|---|
| macOS | `afplay` (built-in) |
| Linux | `paplay` (PulseAudio) / `aplay` (ALSA) / `ffplay` (FFmpeg) |
| Windows (WSL/MSYS) | `powershell.exe` SoundPlayer |

## Project Structure

```
claudivision/
├── sounds/              # ISAC .mp3 sound files
├── hooks/
│   └── play-isac.sh     # Playback script with transmission wrapping
├── install.sh           # Installer / uninstaller
└── README.md
```

## Customization

After installing, edit `~/.claude/hooks/play-isac.sh` to:
- Change cooldown values
- Swap sound files for different events
- Add new event mappings
- Disable transmission wrapping for specific events

The `sounds/` directory contains additional ISAC voice lines not mapped by default (safe area confirmations, data scans, checkpoint updates, etc.) that you can wire up.

## Credits

- Sound design: Massive Entertainment / Ubisoft (Tom Clancy's The Division)
- Inspired by [claudecraft](https://github.com/w00ing/claudecraft)
- Built with [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks)

## License

MIT
