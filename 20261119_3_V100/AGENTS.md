## Execution, Escalation & Dual-GPU Parallelism Rules

### 1. Plan First with `@architect-deep`, Then Implement Fast

- **Before writing code on any multi-file feature, architectural change, or complex bug**, immediately invoke the
  `@architect-deep` subagent with the relevant file paths and requirements.
- Have `@architect-deep` produce a concise, file-by-file implementation blueprint (exact interfaces, method signatures,
  edge cases, and order of changes).
- Once `@architect-deep` returns the plan, **execute all file edits yourself using the fast non-thinking `build` model
  ** (and `@fast-edit` for unit tests/boilerplate). Do not re-plan from scratch between edits.

### 2. Automatic Escalation on Stuck Problems (2-Strike Rule)

- If a compiler error (`mvn`/`gradle`/`tsc`), test failure, or runtime bug **is not resolved after 2 consecutive edit
  attempts**, **STOP guessing immediately**.
- Invoke `@architect-deep` with:
    1. The exact compiler/test error output.
    2. The code snippets involved.
    3. What was already tried and why it failed.
- Apply the root-cause fix returned by `@architect-deep`.

### 3. Parallel Architect Execution (Dual V100 Load Balancing)

- The backend gateway load-balances `qwen-architect` across **two independent V100 GPUs (`least-busy`)**.
- Whenever a task splits cleanly into **two independent modules** (for example: Backend Java REST/Service layer +
  Frontend Angular/Next.js components, or two independent microservices):
    1. Implement one module directly in the main `build` thread (runs on GPU 0).
    2. Simultaneously spawn **`@architect-parallel`** in parallel to implement the second module (routes automatically
       to GPU 1).
- Never spawn more than **2 concurrent architect tasks** at once so both primary GPUs stay at 100% single-stream speed
  without queueing.
