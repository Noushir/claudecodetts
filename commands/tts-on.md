---
description: Enable Claude Code text-to-speech for assistant responses
allowed-tools: Bash(python3:*)
---

Run this exact command, then reply with only the words "TTS enabled." and stop:

```
python3 -c "import json,os; p=os.path.expanduser('~/.claude/tts-state.json'); s=json.load(open(p)) if os.path.exists(p) else {}; s['enabled']=True; s.setdefault('mode','brief'); json.dump(s,open(p,'w'))"
```
