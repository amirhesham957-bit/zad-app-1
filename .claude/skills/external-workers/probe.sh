#!/usr/bin/env bash
# Probe each worker provider: is the key set, does the model exist, does it answer.
# Prints names, model ids and HTTP codes only. Keys go to curl on stdin (-K -), never argv or output.
set -u
NV_MODEL="${ZAD_WORKER_NVIDIA_MODEL:-moonshotai/kimi-k3.1-pro}"
GM_MODEL="${ZAD_WORKER_GEMINI_MODEL:-gemini-3.5-flash}"
GQ_MODEL="${ZAD_WORKER_GROQ_MODEL:-openai/gpt-oss-120b}"

hdr() { printf 'header = "%s: %s"\n' "$1" "$2"; }

chat_openai() { # base key model
  printf '%s\n%s\n' "$(hdr Authorization "Bearer $2")" 'header = "Content-Type: application/json"' |
    curl -s -o /dev/null -w '%{http_code}' --max-time 40 -K - "$1/chat/completions" \
      -d "{\"model\":\"$3\",\"max_tokens\":16,\"messages\":[{\"role\":\"user\",\"content\":\"reply ok\"}]}"
}
models_openai() { # base key grep
  hdr Authorization "Bearer $2" | curl -s --max-time 30 -K - "$1/models" |
    grep -o '"id": *"[^"]*"' | cut -d'"' -f4 | grep -i -E "$3" | sort | head -15
}

probe() { # name var base model grep
  local key="${!2:-}"
  echo "== $1 ($2)"
  if [ -z "$key" ]; then echo "   key: NOT SET"; return; fi
  echo "   models matching /$5/:"; models_openai "$3" "$key" "$5" | sed 's/^/     /'
  echo "   $4 -> HTTP $(chat_openai "$3" "$key" "$4")"
}

probe NVIDIA NVIDIA_API_KEY https://integrate.api.nvidia.com/v1 "$NV_MODEL" 'kimi|qwen.*coder|deepseek|gpt-oss'
probe Groq   GROQ_API_KEY   https://api.groq.com/openai/v1      "$GQ_MODEL" 'qwen|gpt-oss|kimi|llama'

echo "== Gemini (GEMINI_API_KEY)"
if [ -z "${GEMINI_API_KEY:-}" ]; then echo "   key: NOT SET"; else
  code=$(printf '%s\n%s\n' "$(hdr x-goog-api-key "$GEMINI_API_KEY")" 'header = "Content-Type: application/json"' |
    curl -s -o /dev/null -w '%{http_code}' --max-time 40 -K - \
      "https://generativelanguage.googleapis.com/v1beta/models/$GM_MODEL:generateContent" \
      -d '{"contents":[{"parts":[{"text":"reply ok"}]}]}')
  echo "   $GM_MODEL -> HTTP $code   (404 = closed to new users; ListModels lies, see CLAUDE.md)"
fi
