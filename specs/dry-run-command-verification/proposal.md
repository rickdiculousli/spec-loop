---
title: Dry-run / structural verification for currently-rejected shell constructs
status: proposed
priority: P3 (unscoped)
effort: ? (needs a dedicated design session)
created: 2026-07-11
depends_on: "scratchpad-autoallow (related, iceboxed)"
sequencing: Third spec in this repo's own portfolio. Stub only — deliberately not interrogated to a full proposal yet; the user intends to work through the open questions in a separate, judgment-heavy session before this gets a real `## What`/`## Success criteria`. Not iceboxed: this is an open idea awaiting design work, not a rejected one.
---

## Why

`legible-bash.sh` currently rejects, unconditionally, several constructs it can't statically
reason about: compound statements, `cd`, env-var prefixes (`FOO=1 cmd`), command
substitution (`$(...)`/backticks), variable expansion (`$VAR`), `sleep` polling, and trailing
`&`. That doctrine — reject what can't be proven safe by inspection, rather than trying to
prove arbitrary constructs safe — is deliberate and is what makes the hook's regex/quote-
stripping approach defensible at all (see `hook-and-proposal-hardening`'s fixed double-quote
bug for how easily a "prove it's fine" heuristic goes wrong).

While scoping `scratchpad-autoallow` (now iceboxed — see its proposal's Rejected section),
the idea came up of instead trying to *verify* safety for some of these rejected shapes —
loops, env-var prefixes, interpolation — via some kind of "dry run" (in bash or python)
that assumes safety if the dry run looks clean, rather than rejecting them outright. An
independent review of the (different, narrower) scratchpad-autoallow idea flagged that
proving arbitrary shell safe without executing it is not generally tractable, and that a
real dry run implies either sandboxed execution + rollback (a new subsystem, its own attack
surface, in tension with this repo's bash+git-only minimalism) or static analysis sound
enough to trust (not a solved problem for general shell). Those objections apply here too,
but the idea itself — loops, env-var prefixes, and interpolation are the three most common
things that make legible subagent scripts illegible today — is worth a real design pass
rather than dismissing outright.

## Open questions (unresolved — this is why there's no `## What` yet)

- What would "dry run" concretely mean here: real sandboxed execution with rollback,
  static/symbolic analysis of the command text, or something narrower (e.g. a curated set of
  provably-idempotent command shapes, not general loops/substitution)?
- Which of the three constructs (loops, env-var prefixes, interpolation) are actually
  tractable to verify, and do they need one unified mechanism or three separate, narrower
  ones?
- What does "safe" mean as a target for the dry run to establish — read-only? idempotent?
  bounded blast radius? reversible?
- Does this replace, extend, or sit alongside `legible-bash.sh`'s existing reject-by-default
  posture — and does it require revisiting CLAUDE.md's bash+git-only / jq-python3-optional
  dependency invariant (e.g. requiring python3 as a hard dependency for this specific
  mechanism)?
- Is there a narrower, immediately-useful slice (e.g. just env-var prefixes, since those are
  arguably the easiest to reason about mechanically) worth splitting into its own MVP-sized
  spec, versus tackling all three constructs together?

## Constraints (known so far)

- Must not weaken `legible-bash.sh`'s existing rejections for constructs this mechanism
  doesn't explicitly cover — anything not proven safe stays rejected.
- Any resolution here either satisfies CLAUDE.md's existing invariants (bash+git only,
  jq/python3 optional-best-effort, hook fails open loudly) or makes an explicit, deliberate
  case in this proposal for amending them — not a silent scope-widening.

## Out of scope (for this stub)

- Committing to any mechanism, dependency, or task list right now — this file exists to
  hold the idea and its context for a follow-up design session, not to scope an MVP.
- Re-litigating `scratchpad-autoallow`'s specific rejected design (substring path matching)
  — that's closed; see its own proposal.

## Success criteria

Not yet defined — blocked on the open questions above. Do not add tasks.md or start
`/implement` until a follow-up session resolves enough of them to write real
Current/Target/Acceptance criteria and concrete tasks.
