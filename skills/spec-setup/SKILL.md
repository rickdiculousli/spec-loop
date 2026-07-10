---
name: spec-setup
description: One-time project initialization for the spec-loop workflow. Scaffolds specs/ conventions (README + HOUSE-RULES), seeds the permission allowlist for spec.sh, appends a CLAUDE.md pointer, offers to store the legible-shell doctrine in memory, and configures the plugin's env knobs (LEGIBLE_BASH, SPEC_LOOP_PUSH) at the scope the user picks. Use when adopting spec-loop in a repo, or to re-apply any missing piece later.
---

# /spec-setup — Adopt the workflow in this repo

Set up a project to use `/brainstorm` and `/implement`. Idempotent: every piece is skipped (and reported as already present) if it exists. Every piece edits files the user owns, so **present the menu first** with one AskUserQuestion (multiSelect) and apply only what they pick.

## 0. Preconditions

- Inside a git repository? If not, offer `git init` — the workflow is branch-based and cannot run without git.
- Resolve the plugin root to an absolute path once (this skill lives at `<plugin>/skills/spec-setup/`; templates are in `<plugin>/templates/`, scripts in `<plugin>/scripts/`). Use literal absolute paths everywhere below.

## The menu — offer all five, multiSelect, all recommended

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

**5. Configuration knobs.** One AskUserQuestion with three questions:

- **Scope** — where the `"env"` block lives: project `.claude/settings.json` (recommended; shared with the team), personal `.claude/settings.local.json` (this repo, just this user), or user `~/.claude/settings.json` (all of this user's projects).
- **`LEGIBLE_BASH`** — `block` (recommended: reject illegible Bash calls) / `warn` (report but allow) / `off`.
- **`SPEC_LOOP_PUSH`** — `auto` (recommended: `spec.sh` pushes spec branches when `origin` exists) / `off` (never push; branches stay local until pushed by hand).

Merge the chosen values into that file's `"env"` object — create the file or the object if absent, never clobber other keys. Defaults need no entry: write only non-default values, and if every answer is the default, write nothing and say so. If a different scope already sets one of these vars, point out which value wins (more specific scope overrides) instead of silently stacking entries.

## Finish

- Note that the legible-bash guard is active for the whole session wherever the plugin is enabled. If piece 5 was declined, mention that `LEGIBLE_BASH` and `SPEC_LOOP_PUSH` can be set later in any settings `env` block.
- If anything was created, show a one-line summary per piece (created / skipped-exists / declined).
- Suggest `/brainstorm <idea>` as the next step. Do not commit the scaffolding yourself unless asked — the user may want to review it first.
