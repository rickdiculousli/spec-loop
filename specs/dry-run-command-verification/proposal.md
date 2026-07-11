---
title: Legible read-only iteration and taught idioms (resolved from the dry-run verification stub)
status: proposed
priority: P2
effort: S
created: 2026-07-11
depends_on: "scratchpad-autoallow (related, iceboxed — this satisfies its read-only re-entry criterion without reopening it)"
sequencing: Second active spec, after hook-and-proposal-hardening (done). Re-scoped 2026-07-11 from the "dry-run verification" stub — the design session rejected all verification mechanisms; see design.md.
---

## Why

The stub version of this spec asked whether the hook could *verify* safety for
currently-rejected constructs (loops, env-var prefixes, interpolation) via a dry run. The
design session answered no: every mechanism either re-parses shell text (the fragility
class `hook-and-proposal-hardening` just fixed — now with approve powers, where a bug means
silent execution instead of a missed block) or executes untrusted input at hook time. And
the permission matcher's prefix matching means a verified command still prompts anyway.
Full analysis, rejected mechanisms, and external evidence (destructive_command_guard) live
in `design.md`.

What survives is better than a verifier: two of the three constructs already have
hook-passing spellings (`env FOO=1 cmd`, `find … | xargs …` — verified against the live
hook), and the remaining gap — read-only per-file iteration without a scratchpad script —
closes with one audited runner that receives argv and never parses shell.

## What

1. **`scripts/foreach.sh`** — vetted read-only iteration runner:
   `bash <plugin>/scripts/foreach.sh '<glob>' <cmd> [args…]`. Executes only bare-name
   commands on a hardcoded read-only allowlist (`grep, wc, head, tail, cat, file, stat`);
   refuses path-shaped or non-allowlisted commands with exit 2. Behavior details in
   `design.md`.
2. **Hook messages teach the idioms** — stderr text only, no rule-logic change: the
   env-var-prefix rejection names the one-off spelling `env FOO=1 cmd`; the footer names
   `find … | xargs …` and the resolved absolute `foreach.sh` path.
3. **`/spec-setup` seeds the runner's allowlist entry** —
   `Bash(bash <abs-plugin-root>/scripts/foreach.sh *)`, alongside the existing `spec.sh`
   entry (same prescribed-exact-path trust model).
4. **Docs stay coupled** (per CLAUDE.md's cross-file-coupling rule, same commit): README
   hook table + components table, `templates/legible-shell-memory.md`.
5. **Tests**: new `tests/test-foreach.sh`; extended `tests/test-legible-bash.sh` message
   assertions.

## Constraints

- The hook stays block/pass — no `permissionDecision: "allow"`, no auto-approve path.
- No new dependencies: the runner is plain bash; existing invariants (jq/python3 optional,
  fail open loudly) untouched.
- No existing rejection weakens — only stderr wording changes.
- Allowlist growth criterion: a command joins the runner's allowlist only if it has no flag
  that writes to the filesystem (`sort -o` and `sed -i` are the canonical exclusions).
- Version bump: minor (new feature) in `.claude-plugin/plugin.json` before the final commit.

## Out of scope

- Any verification mechanism — sandboxed dry-run, static verifier, shim dry-run — rejected
  with reasons in `design.md`; do not relitigate without new evidence.
- Loops with write effects or multi-step bodies: scratchpad script + one prompt stays the
  path, deliberately.
- Widening `$VAR` / `$(…)`: resolve-then-paste stays doctrine.
- Graduated-response hook modes (dcg-style confirm codes) — future idea, noted in design.md.
- Reopening the `scratchpad-autoallow` icebox decision.

## Success criteria

- Current: read-only per-file iteration needs a scratchpad script plus a permission prompt,
  or a `find | xargs` pipeline the model must think of unprompted. Target: one hook-passing
  call via `scripts/foreach.sh`. Acceptance: a PreToolUse payload with command
  `bash <abs>/scripts/foreach.sh *.md wc -l` exits 0 through `scripts/legible-bash.sh`, and
  `bash tests/test-foreach.sh` passes.
- Current: no runner exists. Target: `foreach.sh` executes only bare-name allowlisted
  read-only commands (`grep, wc, head, tail, cat, file, stat`) and refuses others.
  Acceptance: `bash scripts/foreach.sh '*.md' rm -f` and
  `bash scripts/foreach.sh '*.md' /bin/cat` both exit 2 with a refusal message on stderr,
  asserted in `tests/test-foreach.sh`.
- Current: the env-prefix rejection says only "script or task-runner recipe", and the
  footer names no iteration idiom. Target: the env-prefix message includes the literal
  spelling `env FOO=1 cmd`; the footer includes `xargs` and the absolute `foreach.sh` path.
  Acceptance: `tests/test-legible-bash.sh` asserts those substrings in rejection stderr.
- Current: `/spec-setup` seeds only the `spec.sh` permission entry. Target: it also seeds
  the `foreach.sh` entry. Acceptance: `skills/spec-setup/SKILL.md` menu item 2 lists
  `Bash(bash <abs-plugin-root>/scripts/foreach.sh *)`.
