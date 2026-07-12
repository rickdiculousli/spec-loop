# spec-loop

A Claude Code plugin for spec-driven development with subagent orchestration, built for
repos where the default branch is protected and permission prompts are the enemy of flow.

Three skills, one hook, one script:

| Piece | What it does |
|---|---|
| `/brainstorm <idea>` | Socratic Q&A → `specs/<slug>/` folder (proposal + tasks) committed on its own branch |
| `/implement <slug>` | Executes the spec: orchestrator dispatches Sonnet implementation workers and independent Sonnet verifiers, checks boxes in real time, commits per task |
| `/spec-setup` | One-time adoption: scaffolds `specs/`, seeds the permission allowlist, CLAUDE.md pointer, config knobs, and the legible-shell doctrine into memory |
| `legible-bash` hook | PreToolUse guard that rejects Bash calls the permission matcher can't statically read — with the fix in the rejection message |
| `scripts/spec.sh` | All git choreography, deterministic: `new / save / start / done / list / check` |

## Requirements

- `bash` + `git`. That's it for the workflow — `spec.sh` has no other dependencies.
- The hook parses its JSON input with `jq` if present, else `python3`, else **fails open**
  (allows the call) rather than breaking Bash on machines with neither — loudly: it prints
  an stderr warning naming the missing tool(s) so the gap doesn't go unnoticed.

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

Before `spec.sh done`, the orchestrator asks whether to run an optional whole-branch
review on a model you choose — the per-task verifiers only ever see one task's frozen
diff, so nothing today catches cross-task drift or contradictions; this phase can, on
whichever model you pick for it. It's opt-in per run and purely informational — findings
are reported, never auto-fixed.

## The legible-bash hook

Permission prompts mostly come from shell the matcher can't statically read. The hook
rejects those calls before they run, and each rejection tells the model the compliant
alternative:

| Rejected | Replacement |
|---|---|
| `a && b`, `a; b`, multi-line | one statement per call; `find . -name <glob> \| xargs <cmd>` for read-only iteration; scratchpad script for real scripts |
| `cd …` | run directly if already in the target dir (cwd persists); otherwise `git -C`, `go -C`, `make -C`, absolute paths |
| `FOO=1 cmd` | `env FOO=1 cmd` for a one-off; a script or task-runner recipe for recurring setups |
| `$(…)`, backticks, `$VAR` | resolve once, paste the literal |
| `sleep` polling, trailing `&` | the Bash tool's background mode |

Quoted strings and heredoc bodies are stripped before matching, so `grep "a && b"` passes.
Single-quoted spans are always stripped; double-quoted spans are stripped only for the
compound-statement check — `$(…)`/`$VAR` inside double quotes is still caught, since bash
expands both even when double-quoted.

## Configuration

Both knobs are environment variables. Set them in a `settings.json` `"env"` block — project-wide
in `.claude/settings.json`, personal in `.claude/settings.local.json`, or across all projects in
`~/.claude/settings.json`. Hook processes and Bash tool calls inherit them. `/spec-setup` always
asks whether to keep these defaults or customize them (scope + values) — both knobs are already
live once the plugin is enabled, so that question isn't skippable via the rest of its menu.

| Variable | Values | Controls |
|---|---|---|
| `LEGIBLE_BASH` | `block` (default) · `warn` (report but allow) · `off` | the legible-bash PreToolUse hook |
| `SPEC_LOOP_PUSH` | `auto` (default: push when `origin` exists) · `off` (never push) | whether `spec.sh save` / `start` push spec branches |

```json
{ "env": { "LEGIBLE_BASH": "warn", "SPEC_LOOP_PUSH": "off" } }
```

## spec.sh reference

```
spec.sh new   <slug>                clean tree, on default branch → branch <slug> + specs/<slug>/
spec.sh save  <slug>                commit the spec folder on its branch; push -u if a remote exists and pushing is on
spec.sh start <slug>                checkout the branch (fetch/reopen as needed), status → in-progress
spec.sh done  <slug>                status → done, committed; merge lands it
spec.sh list                        portfolio table from proposal.md frontmatter, plus sequencing notes
spec.sh check                       frontmatter validation: required fields, status enum, depends_on integrity;
                                     plus a warn-only heuristic for Success-criteria bullets with no matching task
spec.sh brief <slug> <N>            extract task N from tasks.md → .spec-loop/<slug>/, prints the path
spec.sh diff  <slug> <base> <head>  commit list + stat + diff → .spec-loop/<slug>/, prints the path
```

Frontmatter registry per `proposal.md`: `title`, `status` (proposed | in-progress | done |
iceboxed), `priority`, `effort`, `created`, `depends_on`, `sequencing`. Branch name ==
folder name == slug, so anyone can find and continue any initiative.

`brief`/`diff` exist for `/implement`'s subagent handoffs — task text and review diffs move
to workers and verifiers as file paths, never pasted through the orchestrator's context. Both
write into `.spec-loop/<slug>/`, a working-tree scratch dir that self-ignores (its own
`.gitignore`, no edits needed to the host repo's). It survives session restarts but is
ordinary untracked scratch: `git clean -fdx` wipes it like anything else untracked — recover
state from `git log` if that happens.

## Development

`bash tests/run.sh` runs the test suite (hook behavior + `spec.sh` push knob). Tests are
self-contained bash scripts; `spec.sh` tests build a throwaway repo with a bare origin under
`mktemp -d` and clean up after themselves.
