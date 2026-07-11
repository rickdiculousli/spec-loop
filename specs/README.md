# Specs — Initiative Portfolio

This directory is the shared to-do surface for the project: one folder per initiative, picked up by reading its `proposal.md` and executing its `tasks.md`. The `/brainstorm` and `/implement` skills (spec-loop plugin) automate the lifecycle; humans can run it by hand too.

## Conventions

- One folder per initiative: `specs/<slug>/` — short, lowercase, hyphenated, named for the outcome (`toplist-grid-view`, not `fix-stuff`).
- `proposal.md` — why, what, scope, success criteria. Its frontmatter **is the registry**, rendered by `spec.sh list`:
  ```yaml
  ---
  title: Short initiative name
  status: proposed | in-progress | done | iceboxed
  priority: P0 | P1 | P2 | P3            # free text; "P1 (phase A) / P2 (phase B)" is fine
  effort: S | M | L
  created: 2026-01-01
  depends_on: "other-slug (soft)"        # free text; slug tokens are integrity-checked, or "-"
  sequencing: One-line note on ordering/role in the portfolio
  ---
  ```
- `tasks.md` — checkbox task list. **Whoever executes (human or agent) checks boxes as they go** — a spec whose tasks don't match reality is worse than no spec. Each code-producing task names its validation (a runnable command, or a precisely observable behavior).
- `design.md` — optional, only when an initiative needs real design decisions recorded.
- **Branch name = folder name = `<slug>`.** The spec is the branch's first commit. Every later edit — including spec deviations discovered mid-implementation (revised tasks, scope corrections) — lands on the branch. **The default branch is never written directly**; it receives a spec and its implementation together, when the branch merges (squash merge recommended: per-task commits are loop machinery, not history).
- Lifecycle: `/brainstorm` opens the branch and commits the spec (`status: proposed`) → `/implement` flips it to `in-progress` and executes → `done` → PR / merge.
- `spec.sh list` / `spec.sh check` (plugin scripts) render and validate the portfolio in the current checkout. In-flight initiatives are visible as branches/PRs, which is where in-flight work belongs.

## House rules

`specs/HOUSE-RULES.md` holds the project-specific rule blocks `/implement` pastes into every implementation subagent's brief and every verifier's checklist. Keep it current — it is the project's institutional knowledge distilled for context-free coders.

## Icebox

Ideas deliberately not in the portfolio. Give each explicit re-entry criteria — revisit only when a criterion is met, don't relitigate otherwise.

- (none yet)
