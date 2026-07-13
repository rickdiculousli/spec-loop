# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code **plugin** (and its own single-plugin marketplace, via `.claude-plugin/marketplace.json` with source `./`). There is no build, lint, or test toolchain — the deliverables are two bash scripts, three skill prose files, three templates, and a hook manifest. Runtime dependencies are deliberately just `bash` + `git` (the hook additionally uses `jq` or `python3` if present, and **fails open** without them — preserve that, and preserve that it fails open *loudly*: an stderr warning naming the missing tool(s), never a silent `exit 0`).

## How the pieces connect

- `.claude-plugin/plugin.json` — plugin identity/version.
- `hooks/hooks.json` — wires PreToolUse on Bash to `scripts/legible-bash.sh` via `${CLAUDE_PLUGIN_ROOT}`.
- `skills/{brainstorm,spec-setup,implement}/SKILL.md` — the three slash commands. They are prose contracts executed by a model, not code: `brainstorm` and `implement` delegate **all** git choreography to `scripts/spec.sh` (resolved relative to the plugin root — skills live at `<plugin>/skills/<name>/`, so the script is `../../scripts/spec.sh`); `spec-setup` copies files from `templates/` into target repos.
- `scripts/spec.sh` — deterministic spec lifecycle (`new/save/start/done/untrack/track/list/check`) plus subagent-handoff file generation (`brief/diff`) for `/implement`. Reads/writes YAML frontmatter in `specs/<slug>/proposal.md` with awk (`fm_get` / `set_status`). `brief`/`diff` write into `.spec-loop/<slug>/`, a working-tree scratch dir that self-ignores via its own `.gitignore` — untracked, survives session restarts, wiped by `git clean -fdx` like any other untracked path.
- `README.md` — mirrors the behavior of the scripts and skills in table form.

**Cross-file coupling is the main hazard:** the frontmatter schema (`title`, `status` enum `proposed|in-progress|done|iceboxed`, `priority`, `effort`, `created`, `depends_on`, `sequencing`) and the `spec.sh` subcommand surface (`new/save/start/done/untrack/track/list/check/brief/diff`) are each restated in `scripts/spec.sh`, all three skills, `templates/specs-README.md`, and `README.md`. Changing any of them means updating all of those in the same commit. Same for the hook's rejection rules, which are restated in `README.md` and `templates/legible-shell-memory.md`.

## Core invariants (the product's design, not style preferences)

- Branch name == spec folder name == slug (`^[a-z0-9][a-z0-9-]*$`). The default branch is never written directly; specs land only by merge. `spec.sh` enforces this — don't add commands that weaken it. This holds even under `SPEC_LOOP_SPECS=local`: branches are still created and named the same way — only the spec folder's git-tracking changes (see below); `/implement`'s code commits always land on the branch as usual.
- Checkbox truthfulness: skills are written so a `tasks.md` box is checked only after validation + independent verification. Edits to `skills/implement/SKILL.md` must not soften that contract.
- Hook exit-code protocol (PreToolUse): `0` allow, `2` block with stderr fed back to the model, `1` allow with stderr shown to the user (warn mode). Modes come from the `LEGIBLE_BASH` env var: `block` (default) / `warn` / `off`.
- Config knobs are env vars read at runtime, set via `settings.json` `"env"`: `LEGIBLE_BASH` (hook mode), `SPEC_LOOP_PUSH` (`auto` default / `off` — gates the pushes in `spec.sh save`/`start`), and `SPEC_LOOP_SPECS` (`git` default / `local` — gates whether `spec.sh new/save/start/done` touch git under `specs/<slug>`). All three are documented in README's Configuration section; keep that table in sync when adding a knob.
- Under `SPEC_LOOP_SPECS=local`, `specs/<slug>` is git-ignored and `spec.sh new/save/start/done` never commit it — the spec folder never lands in git on its own; only `/implement`'s code commits do. `spec.sh untrack`/`track` flip a spec between tracked and local on its branch, one commit each — `track` is the explicit, deliberate way to put a local spec into git.
- The hook judges shell *structure*, not content: it truncates at heredoc openers, joins backslash-continued lines, and strips quoted spans before pattern-matching, so e.g. `grep "a && b"` must keep passing. Quote-stripping is split in two: both single- and double-quoted spans are stripped for the compound-statement/`cd`/env-var-prefix/`sleep`/trailing-`&` checks (those literal characters are inert in either quote type), but only single-quoted spans are stripped before the command-substitution/variable-expansion checks — double-quoted `$(…)`/`$VAR` must stay visible to those, since bash still expands them inside double quotes.

## Versioning

Before the final commit confirmation for any change that touches plugin behavior (scripts, skills, hooks, templates), bump `version` in `.claude-plugin/plugin.json` — semver patch for fixes, minor for new features/knobs. It's the only version signal users installing via the marketplace get; `marketplace.json` has no version field of its own to keep in sync.

## Testing changes

`bash tests/run.sh` runs every `tests/test-*.sh`. Current coverage: the hook's block/warn/off/fail-open behavior and quote-stripping (`test-legible-bash.sh`), the `SPEC_LOOP_PUSH` knob (`test-push-knob.sh`, which builds a throwaway repo + bare origin in `mktemp -d`), the `brief`/`diff` subagent-handoff generation (`test-dispatch.sh`), the Success-criteria coverage-gate warning (`test-coverage-gate.sh`, a throwaway repo via `mktemp -d`, no remote needed since `check` never pushes), and the `SPEC_LOOP_SPECS` knob plus `untrack`/`track` (`test-local-specs.sh`, two throwaway repos in `mktemp -d`: one exercising local mode through `new/save/start/done`, one exercising `untrack`/`track` on an already-committed spec). Extend these when touching the scripts — e.g. new hook rules get a `check` line, new `spec.sh` behavior gets assertions in the sandbox repo.

For ad-hoc probing beyond the suite:

- Hook: pipe a PreToolUse JSON payload and check the exit code, e.g.
  `printf '{"tool_input":{"command":"cd /x && make"}}' | bash scripts/legible-bash.sh` should exit 2 with the fix on stderr.
- `spec.sh`: use a throwaway git repo (never this one — `new` requires a clean tree on the default branch). `spec.sh check` and `spec.sh list` are safe to run anywhere with a `specs/` dir.
- Skills/templates: they're prose — verify by reading that steps still match what `spec.sh` and the hook actually do.
