# claude-code-tts

Hear Claude Code respond. A Claude Code plugin that speaks each assistant turn aloud through macOS's `say` command, controlled by slash commands. Pairs naturally with Claude Code's built-in voice input for a hands-free coding loop.

## Why

Claude Code already supports voice input. With this plugin, the loop closes — you talk, it talks back, you keep your eyes on the diff. Set your system voice to a Siri voice (Arthur, Stephanie, etc.) and you have a Jarvis-like coding assistant.

## Requirements

- **macOS** (the plugin shells out to `/usr/bin/say` and `/usr/bin/python3`)
- **Claude Code**

## Install

```
/plugin marketplace add Noushir/claudecodetts
/plugin install claude-code-tts
```

Restart Claude Code once after installing so the Stop hook is loaded.

## One-time voice setup (recommended)

Out of the box `say` uses the basic Daniel voice, which sounds robotic. To get a Siri-quality voice:

1. Open **System Settings → Accessibility → Spoken Content → System Voice → Manage Voices**
2. Pick an English Siri voice (e.g., **Voice 1 — Arthur**, en-GB) and check it to download (~200 MB)
3. Set it as the **System Voice** and close settings

The plugin's hook calls `say` *without* a `-v` argument, so it uses whatever you've set as your system voice — including Siri voices, which Apple otherwise blocks from third-party processes. This is the only known way to make a Siri voice reachable from `say`.

## Usage

| Command | What it does |
|---|---|
| `/tts-on` | Enable speaking |
| `/tts-off` | Disable + stop any in-flight speech |
| `/tts-brief` | Speak only the last sentence of each response (terse) |
| `/tts-full` | Speak the entire response |
| `/tts-status` | Show current state |

State persists across sessions in `~/.claude/tts-state.json`.

## How it works

A `Stop` hook fires when each assistant turn completes. The hook:

1. Reads the last assistant message from the conversation transcript
2. Strips markdown, code blocks, URLs, and file paths so `say` only reads prose
3. Pipes the cleaned text to `say` (system default voice)

Slash commands flip flags in the state file, which the hook checks on each fire.

## Caveats

- **macOS only.** No Linux/Windows support — `say` doesn't exist there.
- **Apple Siri voice availability.** Apple keeps Siri voices in a private framework. The "set as system voice" route is the only way third-party processes can use them. If a future macOS release closes that loop, this plugin falls back to whatever `say` can reach.
- **One in-flight `say` at a time.** If you receive two assistant responses in quick succession, both speak — the second won't interrupt the first. Use `/tts-off` if you want to silence it immediately.

## Debugging

Logs at `~/.claude/tts-speak.log` show every hook fire with the chosen text and PID. Helpful if you ever notice a turn was skipped.

## License

MIT
