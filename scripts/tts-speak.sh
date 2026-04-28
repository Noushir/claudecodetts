#!/bin/bash
# Stop hook: reads last assistant message from transcript, speaks it via macOS `say`.
# State controlled by ~/.claude/tts-state.json. Exits silently if disabled or on any error.

STATE_FILE="$HOME/.claude/tts-state.json"
PID_FILE="$HOME/.claude/tts-speak.pid"
LOG_FILE="$HOME/.claude/tts-speak.log"
LAST_HASH_FILE="$HOME/.claude/tts-last-hash"
VOICE=""   # empty → use macOS system default voice (set in Spoken Content)
RATE=185

# Rotate log if > 200KB
if [ -f "$LOG_FILE" ] && [ "$(stat -f%z "$LOG_FILE" 2>/dev/null)" -gt 204800 ]; then
    : > "$LOG_FILE"
fi

echo "[$(date '+%H:%M:%S')] hook fired" >> "$LOG_FILE"

[ -f "$STATE_FILE" ] || { echo "  no state file, exit" >> "$LOG_FILE"; exit 0; }

HOOK_INPUT=$(cat)
export HOOK_INPUT STATE_FILE PID_FILE LOG_FILE LAST_HASH_FILE VOICE RATE

/usr/bin/env python3 <<'PY'
import json, os, re, subprocess, signal, sys, hashlib, time

state_file     = os.environ["STATE_FILE"]
pid_file       = os.environ["PID_FILE"]
log_file       = os.environ["LOG_FILE"]
last_hash_file = os.environ["LAST_HASH_FILE"]
voice          = os.environ["VOICE"]
rate           = os.environ["RATE"]
hook_input     = os.environ.get("HOOK_INPUT", "")

def log(msg):
    try:
        with open(log_file, "a") as f:
            f.write(f"  {msg}\n")
    except Exception: pass

try:
    state = json.load(open(state_file))
except Exception as e:
    log(f"state read failed: {e}")
    sys.exit(0)

log(f"state: {state}")

if not state.get("enabled"):
    log("disabled, exit")
    sys.exit(0)
mode = state.get("mode", "brief")

try:
    hook = json.loads(hook_input)
    transcript_path = hook["transcript_path"]
except Exception as e:
    log(f"hook input parse failed: {e}; input head: {hook_input[:120]!r}")
    sys.exit(0)
log(f"transcript: {transcript_path}")

def read_last_assistant_text(path):
    last = None
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line: continue
                try: rec = json.loads(line)
                except Exception: continue
                if rec.get("type") != "assistant": continue
                content = rec.get("message", {}).get("content", [])
                if not isinstance(content, list): continue
                chunks = [c.get("text","") for c in content if isinstance(c, dict) and c.get("type") == "text"]
                text = "\n".join(t for t in chunks if t).strip()
                if text: last = text
    except Exception:
        return None
    return last

# Retry loop: Claude Code sometimes fires Stop before flushing the assistant's
# final response to the transcript file. If we see the same text as last
# spoken, wait briefly for the new message to land, up to ~1.5s total.
prev_hash = ""
try:
    if os.path.exists(last_hash_file):
        prev_hash = open(last_hash_file).read().strip()
except Exception: pass

last_text = None
for attempt in range(8):
    last_text = read_last_assistant_text(transcript_path)
    if last_text is None:
        time.sleep(0.2); continue
    raw_hash = hashlib.sha256(last_text.encode("utf-8")).hexdigest()
    if raw_hash != prev_hash:
        if attempt > 0: log(f"transcript caught up after {attempt} retries")
        break
    time.sleep(0.2)

if not last_text:
    log("no last assistant text found in transcript after retries")
    sys.exit(0)
log(f"last_text head: {last_text[:80]!r}")

def clean(t: str) -> str:
    t = re.sub(r"```.*?```", " ", t, flags=re.DOTALL)
    # Inline backticks: drop the backticks but keep the contents only if it
    # looks pronounceable (no slashes-with-dots / paths). Otherwise drop.
    def _ibk(m):
        inner = m.group(1)
        if re.search(r"[~/]?(?:[\w.-]+/)+[\w.-]+", inner): return " "
        return inner
    t = re.sub(r"`([^`]*)`", _ibk, t)
    t = re.sub(r"https?://\S+", " ", t)
    t = re.sub(r"(?<!`)[~/]?(?:[\w.-]+/)+[\w.-]+", " ", t)
    t = re.sub(r"^#{1,6}\s*", "", t, flags=re.MULTILINE)
    t = re.sub(r"^\s*[-*+]\s+", "", t, flags=re.MULTILINE)
    t = re.sub(r"^\s*\d+\.\s+", "", t, flags=re.MULTILINE)
    t = re.sub(r"\*\*([^*]+)\*\*", r"\1", t)
    t = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"\1", t)
    t = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", t)
    t = re.sub(r"[#*_>`]", " ", t)
    t = re.sub(r"\s+", " ", t).strip()
    return t

cleaned = clean(last_text)
if not cleaned:
    log("cleaned text empty after stripping markdown")
    sys.exit(0)
log(f"mode: {mode}")

if mode == "brief":
    parts = [p for p in re.split(r"(?<=[.!?])\s+", cleaned.strip()) if p.strip()]
    if parts: cleaned = parts[-1]

cleaned = cleaned[:1200]

# De-dup: skip if we already spoke this exact RAW message (prevents re-speaking
# when the Stop hook fires twice for the same assistant message). Hash is on
# raw last_text, matching the retry loop above so brief/full mode toggles still
# re-speak the same source message correctly.
text_hash = hashlib.sha256(last_text.encode("utf-8")).hexdigest()
if text_hash == prev_hash:
    log("skip: same text as last spoken")
    sys.exit(0)

log(f"speaking: {cleaned[:80]!r}... ({len(cleaned)} chars)")

# Note: prior `say` is intentionally NOT killed here. Killing on every Stop hook
# fire was clipping speech when the user sent a follow-up message. /tts-off
# kills speech explicitly when silence is wanted.

cmd = ["/usr/bin/say", "-r", rate]
if voice:
    cmd[1:1] = ["-v", voice]
cmd.append(cleaned)
proc = subprocess.Popen(
    cmd,
    stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    start_new_session=True,
)
try: open(pid_file, "w").write(str(proc.pid))
except Exception: pass
try: open(last_hash_file, "w").write(text_hash)
except Exception: pass
log(f"spawned say pid={proc.pid}")
PY
exit 0
