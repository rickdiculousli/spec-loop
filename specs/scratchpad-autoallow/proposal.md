---
title: Auto-allow legible Bash calls under the session scratchpad and .spec-loop scratch dirs
status: proposed
priority: P2
effort: S
created: 2026-07-11
depends_on: "-"
sequencing: Second spec in this repo's own portfolio; extends legible-bash.sh from hook-and-proposal-hardening.
---

## Why

`/implement`'s own doctrine tells subagent workers to write real scripts to the session
scratchpad and invoke them as a single `bash <path>` call, specifically to stay compliant
with `legible-bash`'s one-statement-per-call rule. In practice those calls still trigger an
interactive permission prompt every time. The environment's "scratchpad needs no permission
prompts" guidance turns out to describe the Bash tool's sandboxed filesystem-access
boundary, not Claude Code's separate permission-prompt system — two different layers. There
is also no way to fix this with a static `settings.json` allowlist entry: the scratchpad
path embeds a random per-session UUID that never repeats, so an exact entry can't match a
future session, and a glob broad enough to match would grant blanket trust to an entire temp
root, not just this plugin's scratch usage.

Checked against current Claude Code hook documentation: a `PreToolUse` hook can return
`hookSpecificOutput.permissionDecision: "allow"` to skip the interactive prompt for that
call, and this is additive only — an explicit `deny` or `ask` rule anywhere in settings
still wins over a hook's `allow`. The hook's JSON input already carries `session_id`
(unique per session) and `cwd`, but no scratchpad-path field, and the temp-directory naming
convention itself is undocumented and platform-specific, so hardcoding it would be fragile.
Checking whether a command's text contains the literal path segment `/<session_id>/scratchpad/`
gives an exact per-session match using only the documented `session_id` field, without
depending on that undocumented convention.

## What

1. Extend `scripts/legible-bash.sh`: move JSON parsing (`command` and `session_id`
   extraction) ahead of the existing `LEGIBLE_BASH=off` early exit, so a new auto-allow
   check can run in every mode. Add a match check: the raw command contains
   `/<session_id>/scratchpad/`, or contains `.spec-loop/` (the plugin's own gitignored
   scratch dir, repo-relative, no session_id needed). Add a `SPEC_LOOP_SCRATCHPAD_AUTOALLOW`
   env knob (default `on`; `off` disables the check). Wherever the hook is about to allow a
   call (the `off`-mode fast path, the msgs-empty clean pass, and `warn`-mode's allow-with-report)
   — never on the `block`-mode `exit 2` path — print the `permissionDecision: allow` JSON if
   the knob is on and the match hit.
2. Document `SPEC_LOOP_SCRATCHPAD_AUTOALLOW` in README's Configuration table (alongside
   `LEGIBLE_BASH`/`SPEC_LOOP_PUSH`) and in the legible-bash section's prose; note the
   deny/ask-rules-still-win safety property in both places.
3. Add `tests/test-scratchpad-autoallow.sh` covering: a qualifying scratchpad path gets the
   JSON override; a qualifying `.spec-loop/<slug>/` path gets it too; a non-matching path
   doesn't; the knob set to `off` suppresses it even for a matching path; `LEGIBLE_BASH=off`
   with the knob on still emits it; a structurally illegible command (e.g. joined with `&&`)
   that also references a matching path is still rejected (exit 2) with no override emitted.
4. Bump `.claude-plugin/plugin.json`'s version (minor — new knob and hook behavior).

## Constraints

- Never weakens `legible-bash`'s structural rejection: a command that fails the
  compound-statement/cd/env-var-prefix/sleep/trailing-&/substitution checks is rejected
  (exit 2) regardless of whether it references a qualifying path. Auto-allow only adds a
  permission-prompt bypass on top of a call the hook was already going to allow.
- No new hard runtime dependency; same jq/python3-optional, fail-open-loud posture as the
  rest of the hook (unchanged from hook-and-proposal-hardening).
- Must not hardcode the OS temp-root/session-directory naming convention (e.g.
  `/private/tmp/claude-<uid>/...`) — it's undocumented and platform-specific. Match on the
  documented `session_id` input field plus a literal `scratchpad` path segment instead.
- Relies only on the documented hook I/O contract confirmed against current Claude Code hook
  docs: `session_id`, `cwd`, `tool_input.command` in; `hookSpecificOutput.permissionDecision`
  out (values `allow`/`deny`/`ask`/`defer`; `allow` skips the prompt but explicit deny/ask
  settings rules still take precedence).
- `tests/test-legible-bash.sh` must keep passing unchanged; this is additive behavior, not a
  replacement of any existing check.

## Out of scope

- Any new `spec.sh` subcommand.
- Auto-allow for tools other than Bash, or for arbitrary paths outside the session
  scratchpad and `.spec-loop/<slug>/`.
- Changing global/user-level Claude Code settings (`~/.claude/settings.json`) or permission
  modes — this ships as plugin hook behavior only, active in any repo that installs
  spec-loop.
- A generic configurable-glob "trust any path matching this pattern" mechanism — scope is
  exactly the two known scratch locations.

## Success criteria

- Current: a Bash call referencing a path under the session scratchpad always triggers an
  interactive permission prompt, with no durable way to allowlist it. Target:
  `legible-bash.sh` emits a `permissionDecision: allow` override for such a call. Acceptance:
  a synthetic PreToolUse JSON payload with a `session_id` and a `tool_input.command`
  containing `/<session_id>/scratchpad/` produces stdout containing `"permissionDecision":"allow"`
  and exit code `0`.
- Current: no mechanism recognizes `.spec-loop/<slug>/` paths. Target: commands referencing
  `.spec-loop/<slug>/` also get the override. Acceptance: a payload whose command contains
  `.spec-loop/some-slug/brief-1.md` produces the same `"permissionDecision":"allow"` stdout.
- Current: no knob exists to disable this independently of `LEGIBLE_BASH`. Target:
  `SPEC_LOOP_SCRATCHPAD_AUTOALLOW=off` suppresses the override even for a matching path.
  Acceptance: the same qualifying payload, run with `SPEC_LOOP_SCRATCHPAD_AUTOALLOW=off`,
  produces no `permissionDecision` in stdout.
- Current: `LEGIBLE_BASH=off` short-circuits the hook before it parses `tool_input.command`
  at all, so no other hook logic runs in that mode. Target: a qualifying path still gets the
  override when `LEGIBLE_BASH=off` and the auto-allow knob is on. Acceptance: the same
  qualifying payload, run with `LEGIBLE_BASH=off`, still produces
  `"permissionDecision":"allow"` in stdout.
- Current: a structurally illegible command is rejected outright today. Target: referencing
  a qualifying path does not exempt an illegible command from rejection. Acceptance: a
  payload whose command is `bash /x/<session_id>/scratchpad/a.sh && bash /x/<session_id>/scratchpad/b.sh`
  still exits `2` and prints no `permissionDecision` override.
- Current: README's Configuration table lists only `LEGIBLE_BASH` and `SPEC_LOOP_PUSH`.
  Target: it also documents `SPEC_LOOP_SCRATCHPAD_AUTOALLOW`. Acceptance:
  `grep -F "SPEC_LOOP_SCRATCHPAD_AUTOALLOW" README.md` matches.
