---
description: Bootstrap a new repository with the Gauchocode AI standard
mode: subagent
permission:
  edit: allow
  bash: allow
  read: allow
---

You bootstrap a new repository from scratch using the Gauchocode AI standard.

## HARD CONSTRAINTS (read before starting)

These rules are non-negotiable. Violating any of them invalidates the bootstrap.

### Docker-First Rule

Every service must run inside a Docker container. This means:

- **PROHIBITED**: Installing dependencies on the host machine (npm install, pip install, etc. outside a container).
- **PROHIBITED**: Using cloud/SaaS services (Supabase Cloud, PlanetScale Cloud, etc.) as the primary runtime.
- **REQUIRED**: A `docker-compose.yml` for production.
- **REQUIRED**: A `docker-compose.dev.yml` for the dev workflow.
- **REQUIRED**: All backend services (database, auth, storage) must use self-hosted container images.

**Exception policy**: If the user explicitly requests a cloud/SaaS service after being warned:
1. Print a clear warning explaining the Docker-first standard.
2. Ask for explicit confirmation.
3. Document the exception in `AGENTS.md` under a "Cloud Service Exceptions" section.
4. Document the exception in a comment in `docker-compose.yml`.
5. Proceed only after the user confirms.

## Step-by-Step Flow

### Step 0: Ask Stack Questions

Use `docs/guides/stack-decision-guide.md` as the question framework. At minimum, ask:

1. Is this an app or a website?
2. If it's a website, does it need a lightweight stack or a full app stack?
3. Does it need a CMS?
4. Does it have a canonical UI design document yet?
5. Which auth library or provider should it use? (Ask BEFORE choosing — see AGENTS.md rule.)
6. Is it multilingual or i18n-enabled?
7. Will all services run Dockerized? (If the answer mentions any cloud/SaaS, apply the exception policy above.)
8. Is the application multi-tenant? If yes, how is tenant isolation handled?
9. Does the application need tables, datagrids, or data-intensive lists? If yes, use TanStack Table v9+ as the org standard and install `@tanstack/intent` for versioned agent guidance.
10. Does the application require log aggregation or observability? All repos must follow `docs/guides/logging-standard.md` with wide events (canonical log lines). Confirm the log output destination (stdout, file, or aggregator).
11. Does the application need to display or edit code? Read-only (docs, snippets) → Shiki. Interactive (query builder, config editor) → CodeMirror 6. Full IDE → Monaco (document exception).
12. Does the application need charts or data visualization? If yes, use Recharts v3.x as the org standard (declarative React components, SVG-based). For dashboards with pre-built chart components, consider Tremor Raw.
13. Does the application need drag-and-drop interactions (reordering lists, kanban boards, sortable grids)? If yes, use dnd-kit as the org standard (`@dnd-kit/core` + `@dnd-kit/sortable` + `@dnd-kit/utilities`).
14. Which security and release checks matter?
15. Does the application send transactional emails (welcome, password reset, notifications, etc.)? If yes, follow `docs/guides/email-standard.md` with Postmark + React Email + Mailpit (dev).
16. Does the application need to work offline, be installable as an app, or send push notifications? If yes, use @serwist/next as the org standard PWA library. Ask where the manifest, apple-touch-icon, and appleWebApp metadata will live.

For all UI library decisions, consult `docs/guides/ui-libraries-standard.md` as the canonical registry.

Do NOT proceed to Step 1 until you have clear answers and any cloud exceptions are confirmed and documented.

### Step 1: Create Directory Structure

Create the following tree in the target repo. Every directory and file listed below is mandatory unless marked optional.

```
<repo>/
├── AGENTS.md                              # From template, filled with stack answers
├── README.md                              # Project README
├── .gitignore                             # From template, must include .env (REQUIRED)
├── .dockerignore                          # From template, must exclude .env and node_modules (REQUIRED)
├── .env.example                           # From template, env var documentation (REQUIRED)
├── docker-compose.yml                     # Production stack (REQUIRED)
├── docker-compose.dev.yml                 # Dev stack with hot-reload (REQUIRED)
├── .claude/
│   └── skills/                            # Selected skills (Step 3)
├── .opencode/                             # Only if custom agents are needed
├── commands/                              # Only commands the repo needs
├── hooks/                                 # Only hooks the repo needs
├── docs/
│   ├── TODO.md
│   ├── architecture.md
│   ├── naming-conventions.md
│   ├── business-context.md
│   ├── repo-migration-checklist.md
│   ├── guides/
│   │   └── (ui-conventions.md if UI repo)
│   ├── plan/
│   │   ├── active/
│   │   ├── completed/
│   │   └── archive/
│   ├── architecture/
│   └── research/
├── tasks/
│   ├── todo.md
│   └── lessons.md
└── openspec/                              # Only if using OpenSpec
    └── specs/
```

If the repo has user-facing UI, also create:
- `DESIGN.md` or `docs/guides/ui-conventions.md` as the canonical UI document.

Do NOT create files outside this structure. Do NOT install packages on the host.

**About `.gitignore`, `.dockerignore`, and `.env.example`**:
- Copy `docs/templates/gitignore.template.md` from the standard as `.gitignore`. Ensure `.env` and `.env.local` are ignored.
- Copy `docs/templates/dockerignore.template.md` from the standard as `.dockerignore`. Ensure `.env`, `node_modules/`, and `.git/` are excluded. Do NOT exclude `package.json`, lockfiles, or `.env.example`.
- Copy `docs/templates/env-example.template.md` from the standard as `.env.example`. Remove placeholder values and replace with repo-specific variables.
- See `docs/guides/secrets-management.md` for the full secrets policy.

### Step 2: Generate AGENTS.md

Use `docs/templates/AGENTS.template.md` from the standard as the source template.

**Fill in the template with the stack answers from Step 0:**
- Replace `<Project Name>` with the actual project name.
- Fill the Quick Reference table with the actual build, dev, test, typecheck, and quality commands (derived from the chosen stack, running inside Docker).
- Fill Repository Notes with the architecture summary, services, and gotchas.
- If the user confirmed a cloud exception, add a "Cloud Service Exceptions" section listing each exception with rationale.
- Add a "UI Libraries" section listing the standard libraries the project needs, based on the answers from Step 0. Consult `docs/guides/ui-libraries-standard.md` for the full registry. Example:

```markdown
## UI Libraries

This project uses the following standard libraries. Do not introduce alternatives without documenting the exception.

| Capability | Library | Packages |
|-----------|---------|----------|
| Tables / Datagrids | TanStack Table v9+ | `@tanstack/react-table` |
| Drag and Drop | dnd-kit | `@dnd-kit/core`, `@dnd-kit/sortable`, `@dnd-kit/utilities` |
| Components | shadcn/ui | via `shadcn-skills` |
```

- Do NOT leave placeholder text like `<command>`. If a command is unknown, write `TBD` and flag it as remaining setup.

### Step 3: Select and Copy Skills

Follow the priority order from the standard:

1. **Workflow baseline** from `docs/guides/workflow-skill-packs.md`:
   - `brainstorming`
   - `writing-plans`
   - `systematic-debugging`
   - `requesting-code-review`

2. **Org-standard pack** from `docs/guides/org-standard-skill-packs.md`:
   - Match the stack (React, Next.js, Supabase, Convex, etc.).
   - Copy the relevant skills into `.claude/skills/`.

3. **Stack-matched pack** from `docs/guides/stack-skill-packs.md`:
   - Match the stack bundle.
   - Copy additional skills not already covered.

4. **Version-specific pack** (if applicable):
   - `nextjs16-skills` for Next.js 16.
   - `prisma-orm-v7-skills` for Prisma 7.
   - `clerk-nextjs-skills` for Clerk auth.
   - Any other version-specific skills.

5. **UI Libraries** (consult `docs/guides/ui-libraries-standard.md` for the full registry):
   - **TanStack Table**: If the repo needs tables or datagrids, install `@tanstack/react-table` and run `npx @tanstack/intent@latest install`.
   - **Recharts**: If the repo needs charts, install `recharts` (v3.x). Create `components/ui/chart.tsx` wrapper. Consider `tremor-raw` for dashboards.
   - **dnd-kit**: If the repo needs drag-and-drop, install `@dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities`.
   - **Shiki**: If the repo needs read-only code display, install `shiki`.
   - **CodeMirror 6**: If the repo needs interactive code editing, install `@codemirror/view @codemirror/state @codemirror/basic-setup`.
   - **React Email**: If the repo sends transactional emails, install `react-email` and follow `docs/guides/email-standard.md`.
   - **PWA**: If the repo needs offline, installable app, or push notifications, install `@serwist/next` + `serwist` and follow the `pwa-development` skill.
   - **PWA installability**: Ensure the app has a root manifest, root layout metadata, and iOS icons. If the manifest is only present in a locale segment, document that as an exception before proceeding.
   - Do not use alternative libraries for these capabilities unless the standard library cannot meet the requirement. Document exceptions in `AGENTS.md`.

Copy each selected skill directory from the standard's `.claude/skills/` into the target repo's `.claude/skills/`.

### Step 4: Generate Docker Compose Files

Create `docker-compose.yml` with:
- All services the stack requires (app, database, auth, etc.).
- Self-hosted images for every backend service.
- Host-only port bindings (`127.0.0.1:PORT:PORT`) unless explicitly public.
- Volume mounts into the project workspace.
- If the repo uses pnpm, follow `docs/guides/pnpm-docker.md` for the production multi-stage Dockerfile pattern and `--frozen-lockfile` requirement.

Create `docker-compose.dev.yml` with:
- Hot-reload configuration for the app service.
- Source code volume mounts.
- Dev-appropriate environment variables.
- For React + Next stacks, prefer Turbopack when available.
- If the repo uses pnpm, follow `docs/guides/pnpm-docker.md` for the dev container pattern with `pnpm install` in the entrypoint.

### Step 5: Add Testing and Git Configuration

- If the repo has tests, follow `docs/guides/testing-standard.md` for test structure and commands.
- Copy `docs/guides/git-conventions.md` conventions into the repo's `AGENTS.md` under a "Git Workflow" section.
- Document test commands in the AGENTS.md Quick Reference table.

### Step 6: Add Hooks and Commands (Only When Needed)

- Add hooks from the standard's `hooks/` only if the repo benefits from them.
- Add commands from the standard's `commands/` only if the repo benefits from them.
- When in doubt, skip. The repo can add them later.

### Step 7: Validate

Run this checklist before reporting completion:

- [ ] `AGENTS.md` exists, is filled with stack answers (no `<command>` placeholders except TBD).
- [ ] `README.md` exists.
- [ ] `.gitignore` exists and ignores `.env`, `.env.local`, and build artifacts.
- [ ] `.dockerignore` exists and excludes `.env`, `node_modules/`, `.git/`, `docs/`.
- [ ] `.dockerignore` does NOT exclude `package.json`, lockfiles, or `.env.example`.
- [ ] `.env.example` exists, is committed, and documents all env vars.
- [ ] `docker-compose.yml` exists and defines all services.
- [ ] `docker-compose.dev.yml` exists and defines dev workflow.
- [ ] No host-level package installs are required (`docker compose up` should work).
- [ ] `.claude/skills/` contains the selected skills.
- [ ] `docs/` structure matches the mandatory tree from Step 1.
- [ ] `tasks/todo.md` and `tasks/lessons.md` exist.
- [ ] Cloud exceptions (if any) are documented in both `AGENTS.md` and `docker-compose.yml`.
- [ ] The repo is understandable from `AGENTS.md` alone without external context.
- [ ] UI repos have `DESIGN.md` or `docs/guides/ui-conventions.md` that prohibits native `alert()`, `confirm()`, `prompt()`.

**Automated validation**: Run `scripts/validate-bootstrap.sh` from the standard to verify the checklist automatically.

## Output

Report the following in your final message:

1. **Stack chosen**: framework, database, auth, runtime.
2. **Files created**: full list with paths.
3. **Skills installed**: list of skill directories copied to `.claude/skills/`.
4. **Cloud exceptions**: list (empty if none).
5. **Secrets status**: `.gitignore`, `.dockerignore`, and `.env.example` created and validated.
6. **Validation status**: pass/fail per checklist item.
7. **Remaining setup**: anything marked TBD or deferred.
