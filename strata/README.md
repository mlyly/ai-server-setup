# Local LLM, RAG & Coding Stack

Self-hosted local AI stack running:

- **PostgreSQL** (`litellm-postgres`): Token/usage tracking and persistence for LiteLLM.
- **LiteLLM Proxy** (`litellm-proxy`, port `4000`): Unified OpenAI-compatible API gateway and admin dashboard.
- **Open WebUI** (`open-webui`, port `3000`): Chat interface wired to LiteLLM and Qdrant RAG.
- **Strata** (`strata-v100`, GPUs `0` & `1`, port `8080`): `Qwen3.8-Flash-Next` for architecture and planning.
- **llama.cpp Server** (`qwen27b-coder`, GPU `2`, port `8081`): `Qwen3.8-27B` (`IQ4_XS`, 128k context, 4 parallel slots)
  for coding and fast sub-agents.
- **Ollama Embeddings** (`local-embeddings-cpu`, CPU only, port `11435` host / `11434` internal): `nomic-embed-text`
  kept warm (`OLLAMA_KEEP_ALIVE=-1`) without contending for GPU 2 VRAM.
- **Qdrant** (`local-qdrant`, ports `6333` REST/UI & `6334` gRPC): Vector database for document embeddings and RAG.

---

## 1. Prerequisites & Configuration Files

Place the following files in your project directory:

- `docker-compose.yml`
- `litellm_config.yaml`
- `.env` (created from your `.env` template with strong secrets for `POSTGRES_PASSWORD`, `LITELLM_MASTER_KEY`, and
  `STRATA_API_KEY`)
- `opencode.jsonc` (optional, for OpenCode CLI/IDE routing)
- `check-stack.sh` (health check script)

Set restrictive permissions on `.env`:

```bash
chmod 600 .env
```

---

## 2. Start the Stack

Start all services in detached mode:

```bash
docker compose up -d
```

Watch startup logs if needed:

```bash
docker compose logs -f --tail=50
```

---

## 3. Pull Required Models

1. **Pull the embedding model into the CPU Ollama container:**

   ```bash
   docker exec local-embeddings-cpu ollama pull nomic-embed-text
   ```

2. **LLM models (`strata` and `qwen27b`):**
    - `strata-v100` is configured with `ALLOW_DOWNLOAD=1` and `MODEL=IQ3_S` into `./strata-data`.
    - `qwen27b-coder` is configured with `--hf-repo unsloth/Qwen3.8-27B-GGUF` and
      `--hf-file Qwen3.8-27B-UD-IQ4_XS.gguf`, caching models in `./models`.
    - First-time downloads happen automatically on container start; monitor progress with:

      ```bash
      docker compose logs -f strata qwen27b
      ```

3. **Configure Open WebUI RAG settings (if upgrading an existing `open_webui_data` volume):**
    - Open `http://localhost:3000` -> **Admin Panel -> Settings -> Documents**.
    - Set **Vector DB** to `qdrant` (`http://qdrant:6333`) if not already set via environment variables, **Embedding
      Model Engine** to `OpenAI`, **API Base URL** to `http://litellm:4000/v1`, **API Key** to `${LITELLM_MASTER_KEY}`,
      and **Embedding Model** to `nomic-embed-text`.

---

## 4. Verify Everything Is Connected and Working

Run the automated verification script:

```bash
chmod +x check-stack.sh
./check-stack.sh
```

The script checks:

- Container running/healthy states (`postgres`, `litellm`, `open-webui`, `strata`, `qwen27b`, `embeddings`, `qdrant`).
- GPU placement (`nvidia-smi` check for GPU availability and `ollama ps` confirming `100% CPU` for
  `local-embeddings-cpu`).
- Direct backend endpoints (`postgres`, `strata`, `qwen27b`, `qdrant`, `open-webui`).
- Container-to-container connectivity from `litellm-proxy` to `strata`, `qwen27b`, `embeddings`, and `qdrant`.
- End-to-end LiteLLM `/v1/models`, `/v1/chat/completions`, and `/v1/embeddings` (verifying non-zero vector dimensions).

---

## 5. Useful Endpoints & Commands

- **LiteLLM Proxy / Admin UI:** `http://localhost:4000`
- **Open WebUI:** `http://localhost:3000`
- **Qdrant Dashboard & REST API:** `http://localhost:6333/dashboard` and `http://localhost:6333/collections`
- **Restart LiteLLM after editing `litellm_config.yaml`:**

  ```bash
  docker compose restart litellm
  ```
  