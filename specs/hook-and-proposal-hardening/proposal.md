---
title: Harden legible-bash quoting/fail-open and add a spec coverage gate
status: in-progress
priority: P2
effort: S
created: 2026-07-11
depends_on: "-"
sequencing: First spec in this repo's own portfolio; no dependencies.
---

## Why

Researching `open-gsd/gsd-core` (a much larger, unrelated spec-driven framework) surfaced
a few small, concrete hardening ideas for spec-loop's two safety-critical mechanisms — the
legible-bash hook and the proposal→tasks handoff — worth adopting on their own merits,
without importing any of gsd-core's scale, language, or dependencies.

Reading `scripts/legible-bash.sh` while scoping this turned up a real bug (not just an
inspired-by port): its quote-stripping treats single- and double-quoted spans identically
before checking for `$(...)`/`$VAR`, but only single quotes actually block bash expansion.
Command substitution or variable expansion hidden inside double quotes currently passes
the hook completely undetected.

## What

1. Fix `scripts/legible-bash.sh`'s quote-handling bug: keep merged single+double-quote
   stripping for the compound-statement check (`;`, `&&`, `||` — those characters really
   are inert data in both quote types), but for the command-substitution and
   variable-expansion checks, strip only single-quoted spans first. Double-quoted content
   stays visible to those two checks, since bash still expands `$(...)`/`$VAR` inside
   double quotes.
2. Add a coverage-gate warning to `spec.sh check`: for each bullet under a proposal's
   `## Success criteria`, warn (never fail) if none of its significant words (length >= 4,
   case-insensitive, punctuation-stripped, common stop-words excluded) appear anywhere in
   that spec's `tasks.md`. Cheap, deterministic, no AI involved.
3. Tighten the proposal template: `## Success criteria` bullets become Current / Target /
   Acceptance triples (Acceptance = a falsifiable pass/fail check) instead of free prose.
   Update `skills/brainstorm/SKILL.md`'s question list and template guidance to match.
4. Fix `scripts/legible-bash.sh`'s silent fail-open: when neither `jq` nor `python3` is
   present, it currently does a bare `exit 0` with no output at all. Make the degradation
   loud — print an stderr warning naming the missing tool(s) before exiting 0.

## Constraints

- No new runtime dependencies. `jq`/`python3` stay optional and best-effort; bash + git
  remain the only hard requirements.
- The coverage gate must be warn-only — keyword overlap is a heuristic with false
  positives, so it must never change `spec.sh check`'s exit code.
- Every place the CLAUDE.md cross-file-coupling rule already names for frontmatter or
  `spec.sh` subcommand changes must be updated in the same commit. For the `##` section
  structure specifically, that's `skills/brainstorm/SKILL.md` only — confirmed by reading
  `README.md` and `templates/specs-README.md`, neither of which documents the
  `## Why`/`## What`/`## Success criteria` prose structure.
- `README.md` and `CLAUDE.md` both describe current quote-stripping and fail-open behavior
  in prose; both need a wording pass so they stay accurate after items 1 and 4.
- `tests/test-legible-bash.sh` must keep passing; extend it for the new cases rather than
  replacing its existing assertions.

## Out of scope

- Any new `spec.sh` subcommand — the coverage gate folds into the existing `check`.
- Porting gsd-core's Socratic ambiguity scoring, XML task format, capability/plugin
  system, MCP server, or ambiguity-score gating — all out of scope per CLAUDE.md's
  bash+git minimalism.
- Rewriting `legible-bash.sh`'s quote handling into a general shell tokenizer/parser — the
  targeted single-vs-double-quote fix is sufficient; a general parser is a bigger, riskier
  rewrite nobody asked for.
- Retrofitting the Current/Target/Acceptance triad onto any existing proposal — this repo
  has no other specs yet, so there is nothing to retrofit.

## Success criteria

- Current: `echo "$(cat /etc/passwd)"` passes `legible-bash.sh` undetected (verified by
  tracing the strip logic — the double-quoted span is removed before the `$(` check runs).
  Target: the same command is rejected (exit 2), citing command substitution, while
  `grep "a && b"` and `grep 'a && b'` (literal `&&` inside either quote type) still pass
  with exit 0. Acceptance: `printf '{"tool_input":{"command":"echo \"$(cat /etc/passwd)\""}}' | bash scripts/legible-bash.sh; echo $?` prints `2` on the last line, and the existing `grep "a && b"` case in `tests/test-legible-bash.sh` still passes.
- Current: `spec.sh check` validates frontmatter only — a `tasks.md` that silently drops a
  stated success criterion is never flagged. Target: `spec.sh check` prints a `warn:` line
  per unmatched Success-criteria bullet, without failing the run. Acceptance: a throwaway
  spec whose Success-criteria bullet shares no significant word with its `tasks.md`
  produces a `warn:` line on stderr, and `spec.sh check`'s exit code is still `0`.
- Current: `## Success criteria` bullets in `proposal.md` are free prose. Target: each
  bullet is a Current/Target/Acceptance triple. Acceptance: `skills/brainstorm/SKILL.md`'s
  interrogation-question list and its proposal-writing section both describe the triad;
  no remaining wording describes Success criteria as free-form prose.
- Current: `legible-bash.sh` exits `0` silently when `jq` and `python3` are both absent.
  Target: it prints an stderr warning naming both missing tools before exiting `0`.
  Acceptance: running the hook with `PATH` scrubbed of `jq` and `python3` against any
  payload produces non-empty stderr mentioning `jq` and `python3`, with exit code still `0`.
