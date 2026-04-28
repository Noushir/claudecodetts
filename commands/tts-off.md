---
description: Disable Claude Code text-to-speech and stop any in-flight speech
allowed-tools: Bash(python3:*), Bash(pkill:*)
---

Run these two commands, then reply with only the words "TTS disabled." and stop:

```
python3 -c "import json,os; p=os.path.expanduser('~/.claude/tts-state.json'); s=json.load(open(p)) if os.path.exists(p) else {}; s['enabled']=False; json.dump(s,open(p,'w'))"
pkill -f '/usr/bin/say' 2>/dev/null; true
```
