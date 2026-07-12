---
title: Share resolved run constants across orchestrator, workers, and verifiers
status: iceboxed
priority: P3
effort: S
created: 2026-07-11
depends_on: "-"
sequencing: Iceboxed — deferred pending observed run evidence; see Iceboxed section below.
---

## Iceboxed

Unlike `scratchpad-autoallow`, this was not rejected as unsound — it was deferred because
the pain is hypothetical. The design session (2026-07-11) found the narrow version below
sound, but no observed `/implement` run has yet demonstrated turns wasted on re-resolving
shared values; the existing mechanism — the orchestrator resolves once and pastes literals
into briefs, already mandated by `skills/implement/SKILL.md` — covers most of the surface.

Design findings worth preserving for re-entry:

1. **Env vars are a dead channel.** `legible-bash` rejects `$VAR` expansion in commands, so
   a shared value can only reach an agent as literal text in its context (brief prose, or a
   file it reads and then pastes from). Any `settings.json` `"env"` scheme is structurally
   useless for this — rule that family out immediately on re-entry.
2. **The static/dynamic split is the safety line.** Repo root, default branch, plugin
   scripts dir, `specs/<slug>`, `.spec-loop/<slug>` are safe to share — constant for a whole
   run. Commit SHAs, merge-bases, and tree status are not: the per-task BASE freshness rule
   in `skills/implement/SKILL.md` §4 exists precisely because stale git state is the failure
   mode. A shared-constants block must exclude dynamic values by construction and by test.
3. **Residual waste is bounded.** Worker briefs already paste exact paths; verifier
   dispatches already paste the diff path and base SHA. What remains is a handful of
   orchestrator setup round-trips per session (repeated on resume) and occasional subagent
   hook-rejection→retry churn.

Re-entry criteria — revisit only when one is met, don't relitigate otherwise:

- (a) A real `/implement` run transcript shows **≥5 Bash round-trips** (including
  hook-rejection→retry cycles) spent resolving values that were static for the whole run
  (repo root, default branch, plugin scripts path, spec/workspace dirs); or
- (b) **two or more subagents in a single run** each independently re-resolve the same
  static value the orchestrator already held.

## Why

`legible-bash`'s doctrine is "resolve the value first, paste the literal": every `$(...)`
and `$VAR` is rejected, so acquiring any value costs a Bash round-trip before the call that
uses it. An `/implement` run multiplies this — one orchestrator plus N workers plus N
verifiers, each starting cold — so the same run-static constants (repo root, default
branch, plugin scripts dir, spec and workspace dirs) can in principle be re-resolved many
times per run, and again after every session resume. Collapsing those resolutions into one
call, with the result pasted forward, would trim turns without touching any invariant.

## What

The narrow version, if re-entered:

1. Add a `spec.sh env <slug>` subcommand to `scripts/spec.sh`: prints a small paste-ready
   block of static run constants — repo root, default branch, spec dir (`specs/<slug>`),
   workspace dir (`.spec-loop/<slug>`), and the plugin scripts dir — to stdout. No commit
   SHAs, no tree state, ever. (Stdout, not a file: unlike `brief`/`diff` output, this block
   is meant to enter the orchestrator's context for pasting into briefs, and it is tiny.)
2. Update `skills/implement/SKILL.md`: the orchestrator runs `spec.sh env` once at start,
   records the block in the run-state file (§3, fixing resume re-derivation for free), and
   adds a `Resolved constants:` line to both the impl-worker brief template (§5) and the
   verifier template (§6).
3. Restate the new subcommand everywhere the subcommand surface is restated (per
   CLAUDE.md's cross-file-coupling rule): the usage line in `scripts/spec.sh`, README's
   subcommand table, and `templates/specs-README.md` if it names subcommands.
4. Add `tests/test-env.sh`: asserts the output contains each expected labeled constant and
   does not contain the repo's HEAD SHA.
5. Bump the plugin version (minor — new subcommand).

## Constraints

- The shared block contains only values static for the entire run. Never commit SHAs,
  merge-bases, or tree status — per-task BASE/HEAD stay freshly resolved per
  `skills/implement/SKILL.md` §4, unchanged.
- No env-var sharing channel (dead under the hook, see Iceboxed finding 1); no
  subagent-writable shared state — the orchestrator remains the sole writer.
- No changes to `legible-bash.sh` behavior, the checkbox-truthfulness contract, or the
  verifier's frozen-snapshot rules.

## Out of scope

- Caching or sharing dynamic git state of any kind.
- Hook changes, including permission auto-allow (that is `scratchpad-autoallow`'s iceboxed
  territory).
- A general key-value store or new handoff protocol beyond the existing `brief`/`diff`
  files in `.spec-loop/<slug>/`.

## Success criteria

- Current: resolving repo root, default branch, plugin scripts dir, spec dir, and workspace
  dir costs one Bash round-trip each. Target: one `spec.sh env <slug>` call prints all of
  them. Acceptance: in a throwaway repo, `bash scripts/spec.sh env some-slug` exits 0 and
  prints a labeled line for each of: repo root, default branch, spec dir, workspace dir,
  scripts dir.
- Current: nothing prevents dynamic git values leaking into a shared block. Target: `env`
  output is SHA-free by construction and by test. Acceptance: `tests/test-env.sh` asserts
  the output does not contain the test repo's HEAD SHA (short or full form).
- Current: the brief and verifier templates in `skills/implement/SKILL.md` carry no
  resolved-constants line. Target: both templates include one. Acceptance:
  `grep -c "Resolved constants" skills/implement/SKILL.md` prints 2 or more.
- Current: README's subcommand table stops at `brief`/`diff`. Target: it documents `env`.
  Acceptance: `grep -F "spec.sh env" README.md` matches.
