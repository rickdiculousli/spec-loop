---
title: Teach the legible idioms for currently-rejected shell constructs (resolved from the dry-run verification stub)
status: proposed
priority: P2
effort: S
created: 2026-07-11
depends_on: "scratchpad-autoallow (related, iceboxed)"
sequencing: Second active spec, after hook-and-proposal-hardening (done). Re-scoped 2026-07-11 from the "dry-run verification" stub — the design session rejected all verification mechanisms and a vetted runner; see design.md.
---

## Why

The stub version of this spec asked whether the hook could *verify* safety for
currently-rejected constructs (loops, env-var prefixes, interpolation) via a dry run. The
design session answered no: every mechanism either re-parses shell text (the fragility
class `hook-and-proposal-hardening` just fixed — now with approve powers, where a bug means
silent execution instead of a missed block) or executes untrusted input at hook time; a
vetted iteration runner was also considered and cut for portability (machine-specific
absolute paths in shared allowlists). Full analysis, rejected mechanisms, and external
evidence (destructive_command_guard) live in `design.md`.

What survives needs no new mechanism at all: two of the three constructs already have
hook-passing spellings — `env FOO=1 cmd` for one-off env prefixes and `find … | xargs …`
for read-only iteration, both verified against the live hook. Today those spellings are
accidental knowledge; this spec makes them taught and regression-pinned.

## What

1. **Hook messages teach the idioms** — stderr text only in `scripts/legible-bash.sh`, no
   rule-logic change: the env-var-prefix rejection names the one-off spelling
   `env FOO=1 cmd`; the shared footer names `find … | xargs …` for read-only iteration.
2. **Idioms pinned as passing** — `tests/test-legible-bash.sh` asserts the new message
   text, and asserts that `env FOO=1 make test` and `find . -name *.txt | xargs wc -l`
   payloads exit 0, so future hook hardening can't silently break the taught spellings.
3. **Docs stay coupled** (per CLAUDE.md's cross-file-coupling rule, same commit): the
   README hook table and `templates/legible-shell-memory.md` gain the same idioms in the
   same vocabulary.

## Constraints

- The hook stays block/pass — no `permissionDecision: "allow"`, no auto-approve path.
- No existing rejection weakens — only stderr wording changes; every current rejection
  test keeps passing.
- No new files, dependencies, or knobs; existing invariants (jq/python3 optional, fail
  open loudly) untouched.
- Version bump: patch (message/doc improvement, no new feature surface) in
  `.claude-plugin/plugin.json` before the final commit.

## Out of scope

- Any verification mechanism — sandboxed dry-run, static verifier, shim dry-run — rejected
  with reasons in `design.md`; do not relitigate without new evidence.
- A vetted `foreach.sh` iteration runner — cut for portability; re-entry criteria in
  `design.md`.
- Loops with write effects, multi-step bodies, or iteration beyond `find | xargs`:
  scratchpad script + one prompt stays the path, deliberately.
- Widening `$VAR` / `$(…)`: resolve-then-paste stays doctrine.
- Graduated-response hook modes (dcg-style confirm codes) — future idea, noted in design.md.
- Reopening the `scratchpad-autoallow` icebox decision.

## Success criteria

- Current: the env-prefix rejection says only "script or task-runner recipe". Target: it
  also names the one-off spelling `env FOO=1 cmd`. Acceptance: `tests/test-legible-bash.sh`
  asserts the substring `env FOO=1` in the rejection stderr for a `FOO=1 cmd` payload.
- Current: no rejection message mentions an iteration idiom. Target: the shared footer
  names `find … | xargs …` for read-only iteration. Acceptance: `tests/test-legible-bash.sh`
  asserts the substring `xargs` in rejection stderr.
- Current: the idioms pass the hook but nothing pins that. Target: both taught spellings
  are regression-tested as passing. Acceptance: `tests/test-legible-bash.sh` asserts exit 0
  for `env FOO=1 make test` and `find . -name *.txt | xargs wc -l` payloads.
- Current: README's hook table and `templates/legible-shell-memory.md` don't mention the
  idioms. Target: both name `env FOO=1 cmd` (one-off) and `find | xargs` (read-only
  iteration) in the same vocabulary as the hook messages. Acceptance: grep for `env FOO=1`
  and `xargs` succeeds in both files.
