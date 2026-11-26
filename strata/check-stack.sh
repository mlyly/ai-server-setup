#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-litellm}"
POSTGRES_DB="${POSTGRES_DB:-litellm}"
LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-}"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  printf "[PASS] %s\n" "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf "[FAIL] %s\n" "$1" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing required command: $1"
    exit 1
  fi
}

require_cmd docker
require_cmd curl

if [[ -z "$LITELLM_MASTER_KEY" ]]; then
  fail "LITELLM_MASTER_KEY is not set (check .env or environment)"
  exit 1
fi

echo "=== 1. Container Status ==="
CONTAINERS=(
  "litellm-postgres"
  "litellm-proxy"
  "open-webui"
  "strata-v100"
  "qwen27b-coder"
  "local-embeddings-cpu"
  "local-qdrant"
)

for cname in "${CONTAINERS[@]}"; do
  status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cname" 2>/dev/null || echo "missing")"
  if [[ "$status" == "running" || "$status" == "healthy" ]]; then
    pass "Container $cname ($status)"
  else
    fail "Container $cname state is '$status'"
  fi
done

echo "=== 2. GPU & CPU Embedding Placement ==="
if command -v nvidia-smi >/dev/null 2>&1; then
  if nvidia-smi >/dev/null 2>&1; then
    pass "nvidia-smi accessible"
  else
    fail "nvidia-smi returned an error"
  fi
else
  fail "nvidia-smi not found on host"
fi

if ollama_ps_out="$(docker exec local-embeddings-cpu ollama ps 2>/dev/null)"; then
  if printf "%s\n" "$ollama_ps_out" | grep -q "nomic-embed-text"; then
    pass "Ollama model nomic-embed-text loaded/listed"
    if printf "%s\n" "$ollama_ps_out" | grep -q "100% CPU"; then
      pass "Embeddings runner is 100% CPU"
    else
      fail "Embeddings runner is not reporting 100% CPU: $ollama_ps_out"
    fi
  else
    fail "nomic-embed-text not found in ollama ps (run: docker exec local-embeddings-cpu ollama pull nomic-embed-text)"
  fi
else
  fail "Failed to query ollama ps in local-embeddings-cpu"
fi

echo "=== 3. Direct Service Health ==="
if docker exec litellm-postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
  pass "PostgreSQL ready ($POSTGRES_DB as $POSTGRES_USER)"
else
  fail "PostgreSQL not ready"
fi

if curl -fsS --max-time 10 "http://localhost:8080/health" >/dev/null 2>&1 || curl -fsS --max-time 10 "http://localhost:8080/v1/models" >/dev/null 2>&1; then
  pass "Strata endpoint reachable on :8080"
else
  fail "Strata endpoint unreachable on :8080"
fi

if curl -fsS --max-time 10 "http://localhost:8081/health" >/dev/null 2>&1 || curl -fsS --max-time 10 "http://localhost:8081/v1/models" >/dev/null 2>&1; then
  pass "qwen27b (llama.cpp) endpoint reachable on :8081"
else
  fail "qwen27b (llama.cpp) endpoint unreachable on :8081"
fi

if curl -fsS --max-time 10 "http://localhost:6333/collections" >/dev/null 2>&1; then
  pass "Qdrant REST API reachable on :6333"
else
  fail "Qdrant REST API unreachable on :6333"
fi

if curl -fsS --max-time 10 -I "http://localhost:3000" >/dev/null 2>&1; then
  pass "Open WebUI reachable on :3000"
else
  fail "Open WebUI unreachable on :3000"
fi

echo "=== 4. Internal Docker Network Connectivity (from litellm-proxy) ==="
INTERNAL_CHECKS=(
  "strata|http://strata:8080/v1/models"
  "qwen27b|http://qwen27b:8080/v1/models"
  "embeddings|http://embeddings:11434/api/tags"
  "qdrant|http://qdrant:6333/collections"
)

for entry in "${INTERNAL_CHECKS[@]}"; do
  label="${entry%%|*}"
  url="${entry#*|}"
  if docker exec litellm-proxy curl -fsS --max-time 10 "$url" >/dev/null 2>&1; then
    pass "Internal network litellm -> $label ($url)"
  else
    fail "Internal network litellm -> $label ($url)"
  fi
done

echo "=== 5. LiteLLM Proxy Functional Checks ==="
models_json="$(curl -fsS --max-time 15 "http://localhost:4000/v1/models" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" 2>/dev/null || echo "")"

if [[ -n "$models_json" ]]; then
  pass "LiteLLM /v1/models responded"
  for expected_model in "qwen3.8-flash-next" "qwen3.8-27b-coder" "qwen3.8-27b-fast" "nomic-embed-text"; do
    if printf "%s" "$models_json" | grep -q "\"$expected_model\""; then
      pass "LiteLLM exposes model '$expected_model'"
    else
      fail "LiteLLM missing model '$expected_model'"
    fi
  done
else
  fail "LiteLLM /v1/models request failed"
fi

chat_resp="$(curl -fsS --max-time 60 "http://localhost:4000/v1/chat/completions" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3.8-27b-fast","messages":[{"role":"user","content":"Reply with OK"}],"max_tokens":16}' 2>/dev/null || echo "")"

if printf "%s" "$chat_resp" | grep -q '"choices"'; then
  pass "LiteLLM /v1/chat/completions succeeded (qwen3.8-27b-fast)"
else
  fail "LiteLLM /v1/chat/completions failed (qwen3.8-27b-fast)"
fi

emb_resp="$(curl -fsS --max-time 30 "http://localhost:4000/v1/embeddings" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"nomic-embed-text","input":"stack health check"}' 2>/dev/null || echo "")"

if printf "%s" "$emb_resp" | grep -q '"embedding"'; then
  pass "LiteLLM /v1/embeddings succeeded (nomic-embed-text)"
else
  fail "LiteLLM /v1/embeddings failed (nomic-embed-text)"
fi

echo "=== Summary ==="
printf "Passed: %d | Failed: %d\n" "$PASS_COUNT" "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
