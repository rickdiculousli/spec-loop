# spec-loop

A Claude Code plugin for spec-driven development with subagent orchestration, built for
repos where the default branch is protected and permission prompts are the enemy of flow.

Three skills, one hook, one script:

| Piece | What it does |
|---|---|
| `/brainstorm <idea>` | Socratic Q&A → `specs/<slug>/` folder (proposal + tasks) committed on its own branch |
| `/implement <slug>` | Executes the spec: orchestrator dispatches Sonnet implementation workers and independent Sonnet verifiers, checks boxes in real time, commits per task |
| `/spec-setup` | One-time adoption: scaffolds `specs/`, seeds the permission allowlist, CLAUDE.md pointer, and the legible-shell doctrine into memory |
| `legible-bash` hook | PreToolUse guard that rejects Bash calls the permission matcher can't statically read — with the fix in the rejection message |
| `scripts/spec.sh` | All git choreography, deterministic: `new / save / start / done / list / check` |

## Requirements

- `bash` + `git`. That's it for the workflow — `spec.sh` has no other dependencies.
- The hook parses its JSON input with `jq` if present, else `python3`, else **fails open**
  (allows the call) rather than breaking Bash on machines with neither.

## Install

From a marketplace checkout or GitHub:

```
/plugin marketplace add <path-or-owner/spec-loop>
/plugin install spec-loop@spec-loop
```

Then, in each repo that adopts the workflow, run `/spec-setup`.

## The loop

```
  idea
   │   /brainstorm          (Socratic Q&A, scope pushback)
   ▼
  branch <slug>             specs/<slug>/proposal.md + tasks.md   — status: proposed
   │   /implement <slug>    (flip to in-progress, on the branch)
   ▼
  branch <slug>             execute tasks in order, one commit per task,
   │                        boxes checked the moment validation + verification pass
   ▼   PR / squash merge
  default branch            — status: done — feature + its spec land together
```

The default branch is **never written directly**. A spec is born on its branch, evolves
on its branch (including mid-implementation deviations), and reaches the default branch
only by merge — compatible with branch protection and required reviews from day one.

Checkbox truthfulness is the contract: a box is checked only when its named validation
passed and an independent verifier found no fault, never batched, never on a workaround.
A spec whose boxes don't match reality is worse than no spec.

## Orchestration model

`/implement` spends frontier-model tokens on judgment only. Mechanical work goes to
`sonnet` subagent workers with tightly scoped briefs (exact files, exact steps, exact
validation command); every task's diff is checked by a separate read-only verifier that
never talks to the implementer. A per-worker ledger (turns, failures, estimated context)
decides when a thread is retired. Project-specific rules the workers must follow live in
`specs/HOUSE-RULES.md` — written once at setup, grown whenever a subagent gets something
wrong that a sentence would have prevented.

## The legible-bash hook

Permission prompts mostly come from shell the matcher can't statically read. The hook
rejects those calls before they run, and each rejection tells the model the compliant
alternative:

| Rejected | Replacement |
|---|---|
| `a && b`, `a; b`, multi-line | one statement per call; scratchpad script for real scripts |
| `cd …` | absolute paths, `git -C`, `go -C`, `make -C` |
| `FOO=1 cmd` | a script or task-runner recipe |
| `$(…)`, backticks, `$VAR` | resolve once, paste the literal |
| `sleep` polling, trailing `&` | the Bash tool's background mode |

Quoted strings and heredoc bodies are stripped before matching, so `grep "a && b"` passes.
Configure per project via the `LEGIBLE_BASH` env var in settings `env`: `block` (default),
`warn` (report but allow), `off`.

## spec.sh reference

```
spec.sh new   <slug>   clean tree, on default branch → branch <slug> + specs/<slug>/
spec.sh save  <slug>   commit the spec folder on its branch; push -u if a remote exists
spec.sh start <slug>   checkout the branch (fetch/reopen as needed), status → in-progress
spec.sh done  <slug>   status → done, committed; merge lands it
spec.sh list           portfolio table from proposal.md frontmatter, plus sequencing notes
spec.sh check          frontmatter validation: required fields, status enum, depends_on integrity
```

Frontmatter registry per `proposal.md`: `title`, `status` (proposed | in-progress | done |
iceboxed), `priority`, `effort`, `created`, `depends_on`, `sequencing`. Branch name ==
folder name == slug, so anyone can find and continue any initiative.
