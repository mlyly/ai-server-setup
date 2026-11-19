# Next.js / React / shadcn/ui — Agent & Subagent Guidelines

## 1. Subagent & Parallel Execution Strategy

- **Parallel Discovery (`@explore`)**: Launch parallel `@explore` subagents for full-stack feature work:
    - Subagent 1: Inspect `app/` routes, layouts, Server Actions, and API route handlers.
    - Subagent 2: Inspect `components/`, `hooks/`, Zod schemas, and existing `components/ui/` shadcn primitives.
- **Offload Boilerplate (`@fast-edit`)**: Delegate Tailwind styling tweaks, Zod validation schemas, TypeScript
  interfaces, and Vitest/React Testing Library specs to `@fast-edit`.
- **Primary Model (`build`)**: Reserve for Server/Client Component boundaries, data fetching/caching flows, complex form
  state, and TypeScript generic issues.

## 2. Context & Token Efficiency Rules

- **Ignore Lockfiles & Build Output**: Never read `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `.next/`, `out/`,
  or `node_modules/`.
- **Do Not Hand-Write shadcn Primitives**: Before creating a UI control, check `components/ui/`. If a missing shadcn/ui
  component is needed (e.g., `dialog`, `table`, `form`), install it via CLI (`npx shadcn@latest add <component>`)
  instead of writing it from scratch.
- **Minimal Diffs**: Use targeted search/replace edits. Never rewrite full JSX trees when updating props, classes, or
  hooks.

## 3. Fast Build & Verification Loops

- **Type-check without emitting files (fastest)**:
    - `npx tsc --noEmit`
- **Lint single changed file**:
    - `npx next lint --file path/to/file.tsx` (or `npx eslint path/to/file.tsx`)
- **Single test execution**:
    - `npx vitest run path/to/file.test.tsx` (or `npx jest path/to/file.test.tsx`)
- **Avoid**: Running `npm run build` / `next build` after every small edit unless verifying production bundle/SSR
  compilation at the end of a task.

## 4. Next.js, React & shadcn/ui Conventions

- **Server vs. Client Components**: Default to React Server Components (RSC) in `app/`. Only add `"use client"` at the
  lowest possible leaf component that requires interactivity (`useState`, `useEffect`, event handlers, browser APIs).
- **Styling & shadcn/ui**: Compose UIs using existing `components/ui/*` primitives, Tailwind CSS utility classes, and
  the `cn()` helper (`@/lib/utils`). Do not write custom CSS modules or inline `style={{}}` objects unless dynamic
  coordinates require it.
- **Forms & Validation**: Use `react-hook-form` paired with `@hookform/resolvers/zod` and shadcn `<Form />` components.
  Share Zod schemas between client forms and Server Actions / Route Handlers.
- **Strict TypeScript**: Never use `any` or `@ts-ignore`. Explicitly type all component props and async server data
  payloads.
