# OpenCode Agent Routing & Execution Guide

This repository uses the `local-v100` provider routed through LiteLLM (`qwen3.8-flash-next`, `qwen3.8-27b-coder`, and
`qwen3.8-27b-fast`). Follow the architect-and-worker rules below so planning stays high-level, implementation and
exploration stay fast and parallel, and autonomous (`--auto`) Docker sandbox runs stay safe and bounded.

---

## 1. Model & Role Responsibilities

- **Architect (`local-v100/qwen3.8-flash-next` — `plan` agent):**
    - Owns system design, architecture decisions, multi-file impact analysis, trade-offs, and step-by-step execution
      plans.
    - Does **not** write bulk code or run noisy exploratory commands when a worker subagent can do it faster.
    - Produces clear, scoped work items with exact file paths, interfaces, acceptance criteria, and non-overlapping
      boundaries so workers can run in parallel.

- **Precision Coder Worker (`local-v100/qwen3.8-27b-coder` — `build` agent):**
    - Implements planned changes, writes or edits code and diffs, and runs targeted tests/checks available inside the
      sandbox.
    - Escalates back to the Architect or summarizes blockers if requirements conflict, a design assumption breaks, or a
      change affects shared interfaces across modules.

- **Fast Parallel Worker (`local-v100/qwen3.8-27b-fast` — `explore` / `general` subagents):**
    - Runs fast codebase searches, symbol/reference lookups, file summaries, and independent read/lint/check sub-tasks.
    - Because GPU 2 (`qwen27b`) runs with parallel slots (`--parallel 4`) and thinking disabled on `qwen3.8-27b-fast`,
      use this model for quick lookups and independent parallel sub-tasks rather than deep architectural reasoning.

---

## 2. When to Call Architect vs. Worker

1. **Start with Architect (`qwen3.8-flash-next`) when:**
    - The task spans multiple files, services, or API contracts.
    - You need an architecture plan, migration path, or debugging strategy before editing code.
    - There are ambiguity or trade-off decisions (performance, data schema, security, or config structure).

2. **Delegate to Fast Workers (`qwen3.8-27b-fast`) when:**
    - Searching files, locating definitions, or gathering context across independent directories/modules.
   - Running independent verification steps inside the sandbox (e.g., syntax checks, lint/config checks, or inspecting
     local files).
    - Breaking a larger task into independent read/analysis slices that can run concurrently without file conflicts.

3. **Execute with Coder Worker (`qwen3.8-27b-coder`) when:**
    - Writing concrete code edits, YAML/JSON/config updates, scripts, or tests based on a clear specification.
    - Applying targeted bug fixes where the root cause is already identified.

---

## 3. Parallel & Subagent Delegation Rules

- **Partition by file or concern:** When delegating parallel sub-tasks to workers, assign disjoint files or distinct
  questions to each worker so edits do not collide.
- **Pass focused context, not raw dumps:** Give each worker only the relevant file paths, constraints, and expected
  output format (e.g., exact findings, file/line references, or a minimal diff).
- **Keep planning separate from editing:** Stay in `plan` (`qwen3.8-flash-next`) until the plan is clear; switch to or
  delegate to `build` (`qwen3.8-27b-coder`) for code changes.
- **Verify after changes:** Run relevant tests, linters, or checks available in the sandbox after edits, and report any
  remaining failures, skipped host checks, or assumptions clearly.

---

## 4. Sandbox Environment: Paths, Tools & Access

Because OpenCode runs inside a Docker sandbox, do **not** assume host-level paths, host hardware tools, or external/host
services unless verified inside the container:

- **Workspace paths:** Treat the mounted repository/workspace directory as the primary read/write boundary. Do not write
  outside the workspace or assume host paths (such as `/root`, `/etc`, `/data`, `/models`, or host volumes) exist unless
  explicitly mounted and verified.
- **Available tools & binaries:** Check what CLI tools and runtimes are actually installed in the sandbox (
  `command -v ...`) before running commands. Do **not** assume `docker`, `docker compose`, `nvidia-smi`, `ollama`, or
  host-only utilities are present inside the sandbox container—if a check requires host/Docker access, state clearly
  what was verified in-sandbox vs. what must be run on the host.
- **Network & endpoints:** Only call reachable endpoints (such as the configured LiteLLM proxy URL) when network access
  is permitted from the sandbox; do not assume unrestricted internet or host-network access.

---

## 5. Autonomous Sandbox Rules (`--auto` Mode)

- **No interactive prompts to rely on:** In `--auto` mode, actions execute without manual confirmation gates. Keep edits
  strictly scoped to the task and avoid speculative changes to unrelated files.
- **Bound retry loops:** If a command or edit fails twice with the same error, stop retrying blindly, record the exact
  error, and report the blocker rather than looping.
- **Strict file ownership in parallel runs:** Never assign two parallel workers to edit the same file simultaneously;
  keep parallel subagents on disjoint read slices or non-overlapping files.
- **Prefer non-destructive checks first:** Run syntax, schema, lint, or unit checks before broader edits, and never run
  destructive commands (such as deleting volumes/data, `rm -rf` outside build/temp artifacts, or broad resets) unless
  explicitly requested in the prompt.

---

## 6. Repository & Stack Conventions

- Keep infrastructure secrets out of versioned files (`.env` holds credentials; use placeholders in templates and
  examples).
- When modifying `docker-compose.yml`, `litellm_config.yaml`, or `opencode.jsonc`, keep model names (
  `qwen3.8-flash-next`, `qwen3.8-27b-coder`, `qwen3.8-27b-fast`, `nomic-embed-text`) and internal service hostnames (
  `postgres`, `litellm`, `open-webui`, `strata`, `qwen27b`, `embeddings`, `qdrant`) consistent across all files.
- Prefer small, readable, well-scoped diffs over broad rewrites unless requested.
