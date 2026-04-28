---
description: Set TTS mode to full (read the entire assistant response)
allowed-tools: Bash(python3:*)
---

Run this exact command, then reply with only the words "TTS mode: full." and stop:

```
python3 -c "import json,os; p=os.path.expanduser('~/.claude/tts-state.json'); s=json.load(open(p)) if os.path.exists(p) else {'enabled':False}; s['mode']='full'; json.dump(s,open(p,'w'))"
```
