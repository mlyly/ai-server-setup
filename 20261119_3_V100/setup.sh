#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="${STACK_DIR}/models"
CACHE_DIR="${STACK_DIR}/cache"
ENV_FILE="${STACK_DIR}/.env"

# Model definitions (Hugging Face resolve URLs -> local filenames)
PRIMARY_FILE="Qwen3.6-27B-Q8_0.gguf"
PRIMARY_URL="https://huggingface.co"

FAST_FILE="Devstral-Small-2-24B-Instruct-2512-Q4_K_M.gguf"
FAST_URL="https://huggingface.co"

EMBED_FILE="bge-m3-Q8_0.gguf"
EMBED_URL="https://huggingface.co"

echo "=== 1. Creating directories ==="
mkdir -p "${MODELS_DIR}" "${CACHE_DIR}"

echo "=== 2. Checking NVIDIA V100 persistence mode ==="
if command -v nvidia-smi &> /dev/null; then
    sudo nvidia-smi -pm 1 || echo "Warning: Could not set persistence mode (run with sudo if needed)."
    nvidia-smi --query-gpu=index,name,memory.total,pci.bus_id --format=csv,noheader
else
    echo "Error: nvidia-smi not found. Verify NVIDIA drivers are installed."
    exit 1
fi

echo "=== 3. Generating .env secrets ==="
if [[ -f "${ENV_FILE}" ]]; then
    echo ".env already exists at ${ENV_FILE} — skipping generation to preserve existing keys."
else
    MASTER_KEY="sk-v100-master-$(openssl rand -hex 20)"
    SALT_KEY="sk-v100-salt-$(openssl rand -hex 20)"
    BACKEND_KEY="sk-v100-backend-$(openssl rand -hex 20)"
    DB_PASS="$(openssl rand -hex 24)"

    cat > "${ENV_FILE}" <<EOF
# --- Security & API Keys ---
LITELLM_MASTER_KEY=${MASTER_KEY}
LITELLM_SALT_KEY=${SALT_KEY}
BACKEND_API_KEY=${BACKEND_KEY}

# --- PostgreSQL Credentials ---
POSTGRES_DB=litellm
POSTGRES_USER=litellm
POSTGRES_PASSWORD=${DB_PASS}

# --- Model Filenames (inside ./models) ---
PRIMARY_MODEL_FILE=${PRIMARY_FILE}
FAST_MODEL_FILE=${FAST_FILE}
EMBED_MODEL_FILE=${EMBED_FILE}
EOF
    chmod 600 "${ENV_FILE}"
    echo "Generated ${ENV_FILE} with secure random keys (chmod 600)."
fi

echo "=== 4. Downloading GGUF models (resumable via curl) ==="
download_model() {
    local url="$1"
    local dest="${MODELS_DIR}/$2"
    echo "-> Checking $2..."
    curl -fL -C - --retry 5 --retry-delay 5 -o "${dest}" "${url}"
}

download_model "${PRIMARY_URL}" "${PRIMARY_FILE}"
download_model "${FAST_URL}" "${FAST_FILE}"
download_model "${EMBED_URL}" "${EMBED_FILE}"

echo "=== 5. Pulling container images ==="
cd "${STACK_DIR}"
docker compose pull

echo ""
echo "Setup complete! Start your stack with:"
echo "  cd ${STACK_DIR} && docker compose up -d"
echo ""
echo "Your generated LiteLLM Master Key (for Admin UI login at :4000/ui):"
grep "^LITELLM_MASTER_KEY=" "${ENV_FILE}"
