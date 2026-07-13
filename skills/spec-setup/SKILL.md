---
name: spec-setup
description: One-time project initialization for the spec-loop workflow. Scaffolds specs/ conventions (README + HOUSE-RULES), seeds the permission allowlist for spec.sh, appends a CLAUDE.md pointer, offers to store the legible-shell doctrine in memory, and always asks about the plugin's already-active env knobs (SPEC_LOOP_SPECS, LEGIBLE_BASH, SPEC_LOOP_PUSH), one question per knob. Use when adopting spec-loop in a repo, or to re-apply any missing piece later.
---

# /spec-setup — Adopt the workflow in this repo

Set up a project to use `/brainstorm` and `/implement`. Idempotent: every piece is skipped (and reported as already present) if it exists. Every piece edits files the user owns, so **present the menu first** with one AskUserQuestion (multiSelect) and apply only what they pick.

Two things happen in this skill: an opt-in file-scaffolding menu (§The menu), and a mandatory configuration question (§Configuration knobs). Keep them separate — the knobs are not optional scaffolding. `SPEC_LOOP_SPECS` (default `git`), `LEGIBLE_BASH` (default `block`), and `SPEC_LOOP_PUSH` (default `auto`) are already live the moment the plugin is enabled, with or without `/spec-setup`. Skipping the knob question would mean the user never got a say in behavior that's already affecting them — so always ask it, even if the menu selection is empty or covers only unrelated pieces.

## 0. Preconditions

- Inside a git repository? If not, offer `git init` — the workflow is branch-based and cannot run without git.
- Resolve the plugin root to an absolute path once (this skill lives at `<plugin>/skills/spec-setup/`; templates are in `<plugin>/templates/`, scripts in `<plugin>/scripts/`). Use literal absolute paths everywhere below.

## The menu — offer all four, multiSelect, all recommended

**1. specs/ scaffolding.** Copy `templates/specs-README.md` → `specs/README.md` and `templates/HOUSE-RULES.md` → `specs/HOUSE-RULES.md` (skip any file that exists). Then tailor `HOUSE-RULES.md`'s `## general` block to reality: read the project's manifests (justfile, Makefile, package.json, go.mod, …) and fill in the actual build/test/lint commands — a scaffold with placeholder commands is worse than none. Add area blocks (`## frontend`, `## backend`, …) only if the project's shape is already clear; otherwise leave the commented examples for later.

**2. Permission allowlist.** Add to `.claude/settings.json` → `permissions.allow` (merge with existing content, never clobber):
- `Bash(bash <abs-plugin-root>/scripts/spec.sh *)` — with the literal resolved path.

This makes every `spec.sh` invocation prompt-free. Suggest the built-in `/fewer-permission-prompts` for growing the project's wider read-only allowlist over time.

**3. CLAUDE.md pointer.** Append a short pointer section (create the file if absent) — pointer lines only, never doctrine content:

```markdown
## Workflow

- Ideas become specs via `/brainstorm`, specs become code via `/implement` (spec-loop plugin). Conventions: `specs/README.md`; per-project rules for implementation subagents: `specs/HOUSE-RULES.md`.
- Every Bash call must be statically legible to the permission matcher — a plugin hook enforces this and its rejection messages state the fix.
```

**4. Legible-shell doctrine → memory.** If this session has a persistent memory directory (the system prompt names it), copy `templates/legible-shell-memory.md` into it as `legible-shell-doctrine.md` and add the index line to `MEMORY.md`:

```
- [Legible-shell doctrine](legible-shell-doctrine.md) — compose Bash to pass the permission matcher first try; the hook enforces it
```

Memory is per-user and per-project — teammates run `/spec-setup` themselves. If no memory directory exists in this environment, say so and skip; the CLAUDE.md pointer (piece 3) plus the hook still cover it. Seeding memory matters because the hook alone teaches by rejection; memory makes commands legible on the first try.

## Configuration knobs — always ask, independent of the menu above

Run this regardless of which menu pieces (if any) were picked — it is not skippable by omission. First check every scope's settings file (`.claude/settings.json`, `.claude/settings.local.json`, `~/.claude/settings.json`) for an existing `env.SPEC_LOOP_SPECS` / `env.LEGIBLE_BASH` / `env.SPEC_LOOP_PUSH`; report anything already set (which scope, which value — more specific scope wins) so the user isn't asked to configure something they already configured.

Then one AskUserQuestion call holding three separate questions — `SPEC_LOOP_SPECS` first, then `LEGIBLE_BASH`, then `SPEC_LOOP_PUSH` — each answerable independently, each knob's current default named "(recommended)" in its own option list:

- **SPEC_LOOP_SPECS** — "Should specs/ be git-tracked, or stay entirely local and untracked?" Options: `git` — tracked, specs land in the branch's history (recommended) / `local` — specs/ never touches git; only /implement's code commits land on the branch.
- **LEGIBLE_BASH** — "Bash call legibility guard." Options: `block` — reject illegible calls (recommended) / `warn` — report but allow / `off` — disable the guard.
- **SPEC_LOOP_PUSH** — "Push spec branches to origin automatically?" Options: `auto` — push when origin exists (recommended) / `off` — never push, branches stay local until pushed by hand.

If every answer matched its default, write nothing; state plainly that all three knobs stay at their defaults and where to change them later (this section, rerun `/spec-setup` anytime).

If any answer differs from its default, ask one more question — **Scope**, once, covering every value that changed (not per-knob): where the `"env"` block lives — project `.claude/settings.json` (recommended; shared with the team), personal `.claude/settings.local.json` (this repo, just this user), or user `~/.claude/settings.json` (all of this user's projects).

Merge only the values that changed from their default into that scope's `"env"` object — create the file or the object if absent, never clobber other keys or knobs left at default.

## Finish

- Note that the legible-bash guard is active for the whole session wherever the plugin is enabled.
- If anything was created, show a one-line summary per piece (created / skipped-exists / declined), plus the configuration outcome (defaults kept / values set and where).
- Suggest `/brainstorm <idea>` as the next step. Do not commit the scaffolding yourself unless asked — the user may want to review it first.
