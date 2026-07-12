# Design — dry-run-command-verification

Outcome of the 2026-07-11 design session this spec's stub was parked for. The stub asked:
can the hook *verify* safety for currently-rejected constructs (loops, env-var prefixes,
interpolation) via some kind of dry run, instead of rejecting them? **Answer: no mechanism
clears the bar — but most of the friction dissolves without one.** The spec is re-scoped
accordingly (see `proposal.md`).

## The constraint that reframes everything: the permission matcher

The hook is not the bottleneck; the permission matcher is. Allowlist entries match by
literal prefix, so `for f in …`, `FOO=1 make`, and `bash <some-path>/script.sh` never match
a rule regardless of what the hook proves — and path shapes make script entries either too
narrow (relative vs absolute spelling → prompt anyway, no friction win) or glob-broad
(substring-matching → bypassable by any same-named file; exactly why `scratchpad-autoallow`
was iceboxed). Consequences:

1. **Verify-then-pass buys nothing.** Hook exit 0 still lands at the matcher, which prompts.
   A friction win requires either the hook emitting `permissionDecision: "allow"`, or an
   exact-prefix allowlist entry for a fixed, prescribed spelling.
2. **Verify-then-approve inverts the failure asymmetry.** Today a hook bug means a missed
   block — the matcher still prompts. A bug in an approving verifier means *silent
   execution*. Any verifier would be held to a far higher soundness bar than the rejection
   rules, in which a quoting bug was found as recently as `hook-and-proposal-hardening`.
3. **Path recognition must be prescribed, not detected.** The sound answer to path-shape
   variance is the existing `spec.sh` precedent: `/spec-setup` seeds one exact absolute-path
   allowlist entry and the docs dictate that exact spelling.

## Rejected mechanisms (do not relitigate without new evidence)

- **Sandboxed dry-run execution** (container/chroot/clone + rollback): a new subsystem with
  its own attack surface, in direct tension with the bash+git-only invariant. Executing
  untrusted input to decide whether to execute it is the thing the hook exists to gate.
- **Static verifier (python3-gated real tokenizer)** — allow `NAME=<literal>` prefixes,
  `$(…)` with allowlisted read-only inner commands, one strict for-loop grammar: rejected on
  risk/coverage, not just effort. It re-introduces hand-rolled shell parsing (the exact
  fragility class just hardened against) but now a parser bug auto-approves. Coverage stays
  thin anyway: `$VAR` is statically unknowable and loop bodies would be limited to a single
  read-only command, so the flagship case isn't served. It also makes python3 load-bearing
  for a security decision and plants a command allowlist inside the hook forever.
- **Shim-based dry run** (execute in a subshell with an argv-logging shim `PATH`, judge the
  log): the only coherent "dry run", and still rejected. Redirections, builtins, `exec`, and
  arithmetic side effects execute in the shell itself, not through `PATH` — so it needs a
  static pre-pass (containing the verifier's fragility) *plus* untrusted execution at hook
  time *plus* timeouts for non-termination. Worst of both worlds.

**External evidence** — `github.com/Dicklesworthstone/destructive_command_guard` (dcg), the
closest real-world analog (a PreToolUse destructive-command blocker), examined 2026-07-11:
~87k lines of Rust with tree-sitter available, and it *still* refuses to run a real shell
grammar over the top-level command — it hand-rolls a span classifier and reserves AST
parsing for bounded heredoc bodies (their ADR-001). The price of hand-parsing at their
ambition level is ~30 `repro_*_bypass.rs` regression files, each a real bypass someone
found. Their `docs/security.md` declares "dynamic command construction that cannot be
resolved to literal payloads" permanently out of scope — independent corroboration of the
`$VAR` conclusion. One inversion worth pinning: dcg must *strip* `env`-wrappers because for
a content-blocker they are a bypass vector; for this hook `env FOO=1 cmd` is a legitimate
idiom, because the hook judges structure and defers content judgment to the matcher/human
prompt. Do not later "fix" the env idiom as if it were a hole.

## Also rejected: a vetted `foreach.sh` runner (cut 2026-07-11, portability)

The session's initial recommendation included an audited argv-based iteration runner
(`bash <plugin>/scripts/foreach.sh '<glob>' <cmd>` — never re-parses shell, hardcoded
read-only command allowlist, seeded exact-path permission entry like `spec.sh`). Cut on a
second pass: the friction win requires an allowlist entry containing a machine-specific
absolute plugin path in a *shared* `.claude/settings.json` — one entry per teammate per
machine, rotting whenever the plugin root moves. `spec.sh` carries the same flaw but is
essential to the workflow; the runner was a convenience whose main use-cases `find | xargs`
already covers (including recursion). Re-entry: only if the harness gains portable
allowlist spellings (e.g. variable expansion in permission rules) or the residual gap
proves painful in practice.

## Chosen design: teach the already-passing idioms

Two of the three constructs already have hook-passing spellings (verified against the live
hook): `env FOO=1 make test` and `find . -name *.txt | xargs wc -l`. The whole deliverable
is making those spellings *taught* rather than accidental — the hook's rejection stderr,
README, and the memory template all name them, and tests pin them as passing so no future
hook hardening silently breaks them. Read-only iteration that xargs can't express falls
back to scratchpad-script-plus-one-prompt, which is the product working as designed. No
hook auto-approve, no `permissionDecision`, no new files, no new dependencies — the hook
stays block/pass and only its wording changes.

## Deliberately unsolved

- Loops with write effects, multi-step bodies, or read-only iteration beyond what
  `find | xargs` expresses: scratchpad script + one prompt. That prompt is the product
  working — a human eyeballs unvetted script code once.
- Bare `$VAR` / general `$(…)`: statically unknowable; resolve-then-paste stays doctrine.
- Recurring env setups: task-runner recipe (matcher-legible), as the hook already says;
  `env FOO=1` is the *one-off* spelling and will prompt, correctly.

## Future idea (out of scope, noted so it isn't lost)

dcg's graduated response — warn → soft-block overridable by a human-typed confirmation code
(designed so an agent can't script past it) → hard block — could someday inform a
`LEGIBLE_BASH` mode between `warn` and `block`. Separate spec if ever.
