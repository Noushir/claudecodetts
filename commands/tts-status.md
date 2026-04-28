---
description: Show current TTS enabled/disabled state and mode
allowed-tools: Bash(cat:*), Bash(python3:*)
---

Run this exact command and report only the resulting one-line string verbatim, nothing else:

```
python3 -c "import json,os; p=os.path.expanduser('~/.claude/tts-state.json'); s=json.load(open(p)) if os.path.exists(p) else {'enabled':False,'mode':'brief'}; print(f\"TTS: {'on' if s.get('enabled') else 'off'} (mode: {s.get('mode','brief')})\")"
```
