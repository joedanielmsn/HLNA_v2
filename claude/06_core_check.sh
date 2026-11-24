#!/usr/bin/env bash
# Day 3: verify the Ollama side of the first-release core: reachable, model present, streaming works
# at 16K context, model fits on the GPU, and unavailability fails fast.
# This tests Ollama itself, not the HLNA UI. It sends one short prompt and changes no models.
#   MODEL=assistant-qwen-16k:latest  OLLAMA=http://127.0.0.1:11434  NUM_CTX=16384
set -uo pipefail
OLLAMA="${OLLAMA:-http://127.0.0.1:11434}"
MODEL="${MODEL:-assistant-qwen-16k:latest}"
NUM_CTX="${NUM_CTX:-16384}"
PASS=0; FAIL=0
ok()   { echo "PASS  $*"; PASS=$((PASS+1)); }
bad()  { echo "FAIL  $*"; FAIL=$((FAIL+1)); }
warn() { echo "WARN  $*"; }

echo "== 1. Ollama reachable"
if TAGS="$(curl -fsS --max-time 5 "$OLLAMA/api/tags" 2>/dev/null)"; then ok "$OLLAMA/api/tags"; else bad "cannot reach $OLLAMA (systemctl status ollama)"; echo "Result: $PASS pass, $FAIL fail"; exit 1; fi

echo "== 2. Model installed: $MODEL"
if printf '%s' "$TAGS" | grep -q "\"name\":\"$MODEL\""; then ok "$MODEL present"; else bad "$MODEL not in: $(printf '%s' "$TAGS" | grep -o '"name":"[^"]*"' | tr '\n' ' ')"; fi

echo "== 3. Streaming generate at num_ctx=$NUM_CTX"
START=$(date +%s.%N)
CHUNKS=0; FIRST=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  CHUNKS=$((CHUNKS+1))
  [ -z "$FIRST" ] && FIRST=$(date +%s.%N)
done < <(curl -sN --max-time 120 "$OLLAMA/api/generate" \
  -d "{\"model\":\"$MODEL\",\"prompt\":\"Say hello in five words.\",\"stream\":true,\"keep_alive\":\"2m\",\"options\":{\"num_ctx\":$NUM_CTX,\"num_predict\":32}}")
END=$(date +%s.%N)
if [ "$CHUNKS" -gt 2 ]; then
  ok "streamed $CHUNKS chunks; first chunk after $(awk -v a="$FIRST" -v b="$START" 'BEGIN{printf "%.2f", a-b}')s; total $(awk -v a="$END" -v b="$START" 'BEGIN{printf "%.2f", a-b}')s"
else
  bad "got $CHUNKS chunk(s); expected a stream (model load error? check: journalctl -u ollama -n 50)"
fi

echo "== 4. GPU placement (model should be 100% GPU on the 4 GB RTX 3050)"
if command -v ollama >/dev/null 2>&1; then
  PS="$(ollama ps 2>/dev/null)"; echo "$PS"
  if echo "$PS" | grep -q "100% GPU"; then ok "100% GPU"; elif echo "$PS" | grep -q "$MODEL"; then bad "model is not fully on GPU (CPU offload slows chat and may mean num_ctx is too large)"; else warn "model not currently loaded"; fi
else warn "ollama CLI not found; skipping"; fi
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader
else warn "nvidia-smi not found"; fi

echo "== 5. Unavailable server fails fast (app must show a clear error, not hang)"
T0=$(date +%s)
curl -fsS --max-time 5 "http://127.0.0.1:11999/api/tags" >/dev/null 2>&1; RC=$?
T1=$(date +%s)
if [ "$RC" -ne 0 ] && [ $((T1-T0)) -le 3 ]; then ok "closed port refused in $((T1-T0))s"; else bad "unexpected result rc=$RC after $((T1-T0))s"; fi

echo "== 6. Model unload frees VRAM"
curl -fsS "$OLLAMA/api/generate" -d "{\"model\":\"$MODEL\",\"keep_alive\":0}" >/dev/null 2>&1
sleep 2
if command -v ollama >/dev/null 2>&1 && ! ollama ps 2>/dev/null | grep -q "$MODEL"; then ok "unloaded"; else warn "still loaded (or ollama CLI missing)"; fi

echo; echo "Result: $PASS pass, $FAIL fail"
echo "Still manual in the app: stop/cancel mid-stream, regenerate, copy, history persistence, 4K-16K context setting persists."
[ "$FAIL" -eq 0 ]
