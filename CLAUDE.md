# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code **plugin** (and its own single-plugin marketplace, via `.claude-plugin/marketplace.json` with source `./`). There is no build, lint, or test toolchain — the deliverables are two bash scripts, three skill prose files, three templates, and a hook manifest. Runtime dependencies are deliberately just `bash` + `git` (the hook additionally uses `jq` or `python3` if present, and **fails open** without them — preserve that).

## How the pieces connect

- `.claude-plugin/plugin.json` — plugin identity/version.
- `hooks/hooks.json` — wires PreToolUse on Bash to `scripts/legible-bash.sh` via `${CLAUDE_PLUGIN_ROOT}`.
- `skills/{brainstorm,spec-setup,implement}/SKILL.md` — the three slash commands. They are prose contracts executed by a model, not code: `brainstorm` and `implement` delegate **all** git choreography to `scripts/spec.sh` (resolved relative to the plugin root — skills live at `<plugin>/skills/<name>/`, so the script is `../../scripts/spec.sh`); `spec-setup` copies files from `templates/` into target repos.
- `scripts/spec.sh` — deterministic spec lifecycle (`new/save/start/done/list/check`). Reads/writes YAML frontmatter in `specs/<slug>/proposal.md` with awk (`fm_get` / `set_status`).
- `README.md` — mirrors the behavior of the scripts and skills in table form.

**Cross-file coupling is the main hazard:** the frontmatter schema (`title`, `status` enum `proposed|in-progress|done|iceboxed`, `priority`, `effort`, `created`, `depends_on`, `sequencing`) and the `spec.sh` subcommand surface are each restated in `scripts/spec.sh`, all three skills, `templates/specs-README.md`, and `README.md`. Changing any of them means updating all of those in the same commit. Same for the hook's rejection rules, which are restated in `README.md` and `templates/legible-shell-memory.md`.

## Core invariants (the product's design, not style preferences)

- Branch name == spec folder name == slug (`^[a-z0-9][a-z0-9-]*$`). The default branch is never written directly; specs land only by merge. `spec.sh` enforces this — don't add commands that weaken it.
- Checkbox truthfulness: skills are written so a `tasks.md` box is checked only after validation + independent verification. Edits to `skills/implement/SKILL.md` must not soften that contract.
- Hook exit-code protocol (PreToolUse): `0` allow, `2` block with stderr fed back to the model, `1` allow with stderr shown to the user (warn mode). Modes come from the `LEGIBLE_BASH` env var: `block` (default) / `warn` / `off`.
- Config knobs are env vars read at runtime, set via `settings.json` `"env"`: `LEGIBLE_BASH` (hook mode) and `SPEC_LOOP_PUSH` (`auto` default / `off` — gates the pushes in `spec.sh save`/`start`). Both are documented in README's Configuration section; keep that table in sync when adding a knob.
- The hook judges shell *structure*, not content: it truncates at heredoc openers, joins backslash-continued lines, and strips quoted spans before pattern-matching, so e.g. `grep "a && b"` must keep passing.

## Testing changes

`bash tests/run.sh` runs every `tests/test-*.sh`. Current coverage: the hook's block/warn/off/fail-open behavior and quote-stripping (`test-legible-bash.sh`), and the `SPEC_LOOP_PUSH` knob (`test-push-knob.sh`, which builds a throwaway repo + bare origin in `mktemp -d`). Extend these when touching the scripts — e.g. new hook rules get a `check` line, new `spec.sh` behavior gets assertions in the sandbox repo.

For ad-hoc probing beyond the suite:

- Hook: pipe a PreToolUse JSON payload and check the exit code, e.g.
  `printf '{"tool_input":{"command":"cd /x && make"}}' | bash scripts/legible-bash.sh` should exit 2 with the fix on stderr.
- `spec.sh`: use a throwaway git repo (never this one — `new` requires a clean tree on the default branch). `spec.sh check` and `spec.sh list` are safe to run anywhere with a `specs/` dir.
- Skills/templates: they're prose — verify by reading that steps still match what `spec.sh` and the hook actually do.
