# Angular Project — Agent & Subagent Guidelines

## 1. Subagent & Parallel Execution Strategy

- **Parallel Discovery (`@explore`)**: Spawn parallel `@explore` subagents when tracing a feature module or route:
    - Subagent 1: Locate smart/container components, route definitions (`*.routes.ts`), and guards/resolvers.
    - Subagent 2: Locate injectable `@Injectable` services, HTTP clients, state stores/signals, and TypeScript models.
- **Offload Boilerplate (`@fast-edit`)**: Delegate HTML template updates, SCSS styling, TypeScript interfaces, and
  Jasmine/Jest `*.spec.ts` unit tests to `@fast-edit`.
- **Primary Model (`build`)**: Reserve for RxJS stream orchestration, Signal state architecture, reactive forms, and
  complex TypeScript template type-checking errors.

## 2. Context & Token Efficiency Rules

- **Ignore Build & Cache Artifacts**: Never read `.angular/`, `dist/`, `coverage/`, `node_modules/`, or lockfiles (
  `package-lock.json`, `pnpm-lock.yaml`).
- **Minimal Diffs**: Apply targeted search/replace edits to `.ts`, `.html`, and `.scss` files rather than rewriting
  whole components.

## 3. Fast Build & Verification Loops

- **Strict TypeScript & Angular template type-check (fastest)**:
    - `npx ngc --noEmit` (or `npx tsc --noEmit`)
- **Single component/service spec execution**:
    - Karma: `npx ng test --include='**/target.component.spec.ts' --watch=false`
    - Jest/Vitest: `npx jest path/to/target.component.spec.ts`
- **Lint single file**:
    - `npx ng lint --lint-file-patterns="src/app/path/to/file.ts"`
- **Avoid**: Running `npx ng build` after every incremental edit; rely on `ngc --noEmit` until the feature is complete.

## 4. Angular Coding Conventions

- **Modern Angular Architecture**:
    - Prefer **Standalone Components** (`standalone: true`) and lazy-loaded route arrays over legacy `NgModule`
      declarations unless working inside an existing module boundary.
    - Use the `inject()` function instead of constructor parameter injection for cleaner inheritance and composition.
    - Use built-in control flow syntax (`@if`, `@for` with `track`, `@switch`) instead of `*ngIf` / `*ngFor`.
- **Signals & RxJS**:
    - Prefer **Signals** (`signal()`, `computed()`, `input()`, `output()`) for synchronous local and derived component
      state.
    - Use **RxJS** for asynchronous event streams and HTTP pipelines; bridge observables to templates via `toSignal()`
      or the `async` pipe. Never leave raw `.subscribe()` calls without `takeUntilDestroyed()`.
- **Change Detection & Typing**:
    - Set `changeDetection: ChangeDetectionStrategy.OnPush` on all new components.
    - Enforce strict typing (`no any`) across Typed Reactive Forms (`FormGroup<...>`) and backend API response
      interfaces.
