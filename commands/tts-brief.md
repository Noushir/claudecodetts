---
description: Set TTS mode to brief (read only the last sentence of each response)
allowed-tools: Bash(python3:*)
---

Run this exact command, then reply with only the words "TTS mode: brief." and stop:

```
python3 -c "import json,os; p=os.path.expanduser('~/.claude/tts-state.json'); s=json.load(open(p)) if os.path.exists(p) else {'enabled':False}; s['mode']='brief'; json.dump(s,open(p,'w'))"
```
