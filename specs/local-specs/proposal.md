---
title: Local-only specs mode (SPEC_LOOP_SPECS)
status: done
priority: P1
effort: M
created: 2026-07-13
depends_on: "-"
sequencing: Third active spec in this repo's portfolio; independent of hook-and-proposal-hardening and dry-run-command-verification (both done).
---

## Why

Today `spec.sh new/save/start/done` always `git add`/commit everything under `specs/<slug>/`, unconditionally. That's the right default when you own the repo, but there's no way to use spec-loop for planning while keeping every spec-loop artifact — proposal, tasks, status flips — out of git entirely: not committed, not in any diff, invisible to `git status`. On demand, in any repo, someone should be able to flip a switch and get exactly that: `/brainstorm` and `/implement` still run the full loop, but the only things that ever land as real commits are the actual code changes `/implement` produces.

## What

- New env knob `SPEC_LOOP_SPECS` — `git` (default, today's behavior, byte-identical) or `local`. Same pattern as `SPEC_LOOP_PUSH`: read at runtime, set via `settings.json` `"env"`.
- Under `local`, `spec.sh new/save/start/done` still read and write the files on disk (status flips happen, validation happens) but perform **zero** git operations against `specs/`: no `git add`, no `commit`, no `push`.
- `spec.sh new` under `local` additionally drops a self-ignoring `specs/<slug>/.gitignore` (same trick `.spec-loop/`'s `workspace_dir()` already uses: an unnegated `*` hides the whole folder, including the `.gitignore` itself, from `git status`) so the folder never shows up as untracked either. Scoped per-slug, not a blanket `specs/.gitignore` — other specs in the same `specs/` root that stay git-tracked are unaffected.
- Branch creation/checkout (`new`/`start`) is unchanged in both modes: `/implement`'s actual code commits still need a branch, and branch name == spec folder name == slug holds either way.
- Everything under `specs/` is covered uniformly — the `/spec-setup` scaffolding (`specs/README.md`, `specs/HOUSE-RULES.md`) goes local too under this mode, no split between "team docs stay tracked, spec folders go local."
- Two new subcommands for moving an already-committed spec across the boundary:
  - `spec.sh untrack <slug>` — `git rm -r --cached specs/<slug>` (kept on disk), commit the removal, then drop the self-ignoring `.gitignore`.
  - `spec.sh track <slug>` — reverse: delete the `.gitignore`, `git add specs/<slug>`, commit.
- `/spec-setup`'s configuration-knobs step is restructured, not just extended: today it bundles `LEGIBLE_BASH` and `SPEC_LOOP_PUSH` into one "keep both defaults or customize" choice, which prior use reported as friction (can't accept one knob's default while changing the other without an extra round-trip). Each knob becomes its own separate question — `SPEC_LOOP_SPECS` asked first, then `LEGIBLE_BASH`, then `SPEC_LOOP_PUSH` — with the knob's actual values as that question's options rather than a generic keep/customize gate. Only the shared "which settings scope" follow-up stays a single question, asked once, only if at least one answer differed from its default.

## Constraints

- `SPEC_LOOP_SPECS` unset, or explicitly `git`, must be byte-for-byte identical to current behavior — the full existing test suite (`bash tests/run.sh`) passes unmodified with no env var set.
- Branch name == spec folder name == slug (CLAUDE.md core invariant) holds in both modes — do not weaken it, do not skip branch creation in `local` mode.
- Cross-file coupling per CLAUDE.md: the frontmatter schema and `spec.sh` subcommand surface are restated in `scripts/spec.sh`, all three skills, `templates/specs-README.md`, and `README.md`. Every file in that list gets updated in this spec's commits, not left stale.
- Follow the existing knob idiom exactly: env var validated up front (reject bogus values the way `SPEC_LOOP_PUSH` does), documented in README's Configuration table, asked about in `/spec-setup`.
- The settings-scope question (project/personal/user) stays a single shared question, not asked per knob — splitting the value questions must not multiply into a scope prompt per knob too.
- Version bump in `.claude-plugin/plugin.json` (minor — new feature/knob) before the final commit, per CLAUDE.md's Versioning section.

## Out of scope

- Auto-detecting a "foreign repo" and switching modes automatically — always an explicit env var choice, never inferred from write access, fork state, or anything else.
- A per-spec override of the global knob — one mode per repo/session; no flag to force a single spec folder against the prevailing `SPEC_LOOP_SPECS` value.
- Bulk/batch conversion of an entire portfolio at once — `untrack`/`track` operate on one slug at a time, which is enough; no "convert everything" command.

## Amendment (2026-07-13, post-merge)

The as-shipped design above (per-slug `specs/<slug>/.gitignore`, `untrack`/`track` scoped to one slug) didn't match the actual intent: the whole `specs/` directory — including root-level `specs/README.md`/`specs/HOUSE-RULES.md`, which the per-slug mechanism never touched — was supposed to go dark under `local` mode, not just individual spec folders one at a time. Corrected in a same-day follow-up: a single blanket `specs/.gitignore` replaces the per-slug file (safe alongside already-tracked specs — `.gitignore` never un-tracks a committed path), `save`/`track` gained `-f` on their `git add` calls so tracking still works once that blanket ignore exists, and `untrack`/`track` gained an `--all` mode that sweeps everything under `specs/` in one commit on the current branch (not per-branch — specs mostly live on the default branch once merged). The "Out of scope: Bulk/batch conversion" line below and the per-slug details in `## What`/`## Success criteria` reflect the original round, not the corrected behavior — see `scripts/spec.sh`, `README.md`, and `CLAUDE.md` for what's actually live.

## Success criteria

- Current: `spec.sh new/save/start/done` always commit under `specs/<slug>`, regardless of any setting. Target: under `SPEC_LOOP_SPECS=local`, none of the four make any git commit touching `specs/`. Acceptance: in a throwaway repo, running `new`→edit→`save`→`start`→`done` under `SPEC_LOOP_SPECS=local` leaves `git log --oneline` with no commit mentioning `specs/<slug>`, and `git status --porcelain` empty throughout.
- Current: `specs/<slug>/` has no ignore rule; every new/changed file inside it shows in `git status`. Target: under `local`, `specs/<slug>/` never appears in `git status` once `spec.sh new` has run. Acceptance: after `spec.sh new` under local mode, `git status --porcelain` contains no line referencing `specs/<slug>`.
- Current: no way to move an already-committed spec folder out of git tracking, or back. Target: `spec.sh untrack <slug>` un-tracks and commits the removal; `spec.sh track <slug>` reverses it. Acceptance: in a throwaway repo with a committed `specs/t2`, `untrack t2` leaves `git ls-files specs/t2` empty with a new removal commit in `git log`; `track t2` afterward makes `git ls-files specs/t2` non-empty again.
- Current: `/spec-setup`'s configuration-knobs step bundles `LEGIBLE_BASH` and `SPEC_LOOP_PUSH` into a single keep-or-customize question. Target: each knob — `SPEC_LOOP_SPECS` first, then `LEGIBLE_BASH`, then `SPEC_LOOP_PUSH` — is its own separate question with that knob's values as options; only the settings-scope follow-up stays shared. Acceptance: `skills/spec-setup/SKILL.md`'s Configuration knobs section shows three distinct per-knob questions in that order, no combined "keep both defaults" option spanning multiple knobs.
- Current: `README.md`'s Configuration table and `spec.sh` reference section don't mention `SPEC_LOOP_SPECS`/`untrack`/`track`. Target: they do, consistently with `CLAUDE.md` and `templates/specs-README.md`. Acceptance: `grep -l SPEC_LOOP_SPECS README.md CLAUDE.md skills/*/SKILL.md templates/specs-README.md` lists all five files.
