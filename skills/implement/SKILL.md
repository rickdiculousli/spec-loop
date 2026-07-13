---
name: implement
description: Spec executor. Runs a specs/<slug>/ initiative end-to-end - reads proposal.md and tasks.md, executes tasks in order via subagent orchestration, checks boxes in real time, runs each task's validation, and updates spec status at the end. Use when the user wants to execute an existing initiative from specs/.
argument-hint: <slug>
---

# /implement — Execute a Spec

Execute one initiative from `specs/`, keeping its `tasks.md` truthful at every moment. The checkbox discipline is the point: a spec whose boxes don't match reality is worse than no spec.

You are the **orchestrator**: you plan, dispatch, verify, and record — subagent workers do the writing. Spend frontier tokens on judgment, never on mechanical reading.

All git choreography goes through `scripts/spec.sh` in this plugin (`<plugin>/scripts/spec.sh`; resolve to an absolute path once, invoke as `bash <abs-path>/spec.sh <cmd> <slug>`).

## 1. Load and review

- Resolve the argument to `specs/<slug>/`. Read `proposal.md`, `tasks.md`, and `design.md` if present.
- Read `specs/HOUSE-RULES.md`. If it's missing or still the unedited scaffold, say so — briefs without house rules produce plausible-but-wrong code — and offer to fill it in with the user (or run `/spec-setup`) before dispatching anything.
- Check `depends_on` against `spec.sh list`. If a dependency isn't `done`, stop and ask.
- **Raise concerns before starting.** If a task is ambiguous, contradicts the code as it exists now, or looks stale, say so and resolve it with the user first — don't reinterpret silently.
- Run `spec.sh start <slug>` — checks out the spec's branch and flips the proposal to `status: in-progress` on it. From now on **everything stays on the branch, including spec deviations** — revised tasks, scope corrections, any `proposal.md`/`tasks.md` edit. The default branch receives this work only when the branch merges. Under `SPEC_LOOP_SPECS=local`, that in-progress flip is written to disk but not committed — the spec folder stays local-only throughout.

## 2. Roles and ground rules

- **Only the orchestrator** edits `tasks.md`, runs `spec.sh`, or touches git. Subagents never do.
- **Context diet:** the orchestrator never reads implementation files or full diffs. Its inputs are worker reports, verifier reports, validation output, and `git diff --stat`. Sole exception: inline escalation.
- **Inline, no subagent:** trivial tasks (single-file, ≲5-line edit, doc-only) and judgment-heavy tasks (design decisions, debugging without a known cause). Everything mechanical in between goes to a worker (`model: sonnet`). Inline work skips the dispatch, not the gates: judgment-heavy inline tasks still get a verifier (§6); trivial tasks skip that too.
- Subagents work in the **real tree, one writer at a time** — never `isolation: "worktree"`. Read-only research fan-out (Explore agents) is the only parallel exception besides verifiers (§6).

## 3. Dispatch planning

- Read all tasks upfront and sketch each task's "files to read" set — you're writing it into the brief anyway.
- **Cluster = shared context root:** ≥3 tasks in one module/dir, read-sets overlapping ≳50%, or a task plus its validate-fix-retry chain. A cluster gets one **zone worker**, continued per task via SendMessage (a returned agent stays resumable — SendMessage by its ID continues the thread with context intact). Everything else gets a fresh task worker.
- **Schedule clusters contiguously** where dependencies allow: follow-ups stay inside the 5-minute prompt cache, tree deltas stay empty, the zone retires sooner.
- **Persist run state:** after each task, write ledger, task statuses, and handoff notes to one scratchpad file; pass briefs and handoffs between agents as file paths, not re-tokenized prose — use `spec.sh brief <slug> <N>` to extract a task's text and `spec.sh diff <slug> <BASE> <HEAD>` to capture its review package (both write to `.spec-loop/<slug>/` and print the path; neither output touches your own context). A resumed run must reconstruct from that file alone.

## 4. Per-task loop

1. Record the branch's current `HEAD` as this task's BASE — needed by step 3's diff capture; never substitute `HEAD~1` later, since a task's fix-up commits (step 5) can put more than one commit between BASE and the review, and `HEAD~1` would silently drop the earlier ones. Then dispatch the impl worker (Agent tool: `model: sonnet`, `run_in_background: false`). Zone follow-ups go via SendMessage and state the tree delta since the worker's last turn (`git status --porcelain` + diff — this also catches validation side-effects like regenerated artifacts). Empty delta → say "tree unchanged since your last turn"; non-empty → list the files, re-read required only where they intersect its task.
2. When it reports: run the task's **cheap deterministic validation yourself** (typecheck, targeted test, grep). Expensive suites (full e2e, integration) run once per cluster boundary, not per task.
3. **Commit the task on the branch** — that commit is the loop's cadence (fix-ups land as follow-up commits; pushing stays user-directed) and freezes the snapshot: run `spec.sh diff <slug> <BASE> <HEAD>` (BASE from step 1, HEAD = the commit just made) to capture the review package, then launch the verifier in the background (§6) with the printed path. The next impl worker may start immediately — verification and implementation overlap; recording does not.
4. **Check the box only when its verifier passed and validation passed** — one Edit per task, immediately, never batched. Never check a box on a workaround, and never weaken or comment out a failing check to get there. Resolve every ⚠️ cannot-verify item from the verifier yourself before checking the box (§6) — you hold plan and cross-task context it doesn't; a confirmed gap routes back to the worker like any failed verification. A box checked while its cluster suite is pending carries the annotation "(cluster suite pending)" — the suite passing removes it; a suite failure reopens the implicated boxes.
5. **Failure handling — validation failures and verifier concerns route the same way:** a *localized* problem (output points at a specific spot) → one follow-up turn to the same worker; its context is an asset. An *approach* problem (same strategy failed twice, long exploratory stem, substantive verifier objection, ledger breach) → fresh worker whose brief carries the evidence — never a remediation dialogue in a thread that went wrong. After two failed workers, do the task inline and note it.

## 5. Briefs

House rules come from `specs/HOUSE-RULES.md`: paste the `## general` block into every brief; paste each area block whose section matches the task's territory into that task's briefs and verifier checklists. Also paste `proposal.md`'s own `## Constraints` section into every brief and verifier checklist for this spec — house rules are project-wide; Constraints is what this initiative specifically demands (exact values, formats, things it must not break).

Impl worker template — fill every line, token-frugal, no "explore the codebase":

```
Task: <one sentence>
Files to modify: <exact paths>
Files to read for context: <exact paths — only what's needed>
House rules: <paste the matching block(s) from specs/HOUSE-RULES.md>
Spec constraints: <paste proposal.md's ## Constraints section>
Do not touch anything else. Do not read broadly. Never touch git, tasks.md, or install anything.
Steps: <numbered, concrete>
Validate with: <exact cheap deterministic command> — must pass before you finish.
Stop and report back — cheap, expected, not failure — if: (a) an instruction is ambiguous
or contradicts the code; (b) the same approach has failed twice; (c) you're about to build
a workaround for tooling/environment friction; (d) you're about to hand-roll nontrivial
tooling an off-the-shelf tool likely covers — name the need instead.
Report (≤40 lines): files changed; validation result (output verbatim only on failure);
deviations from the steps; what remains uncertain or unverified;
[zone workers] context worth keeping: yes/no + what, for which remaining tasks.
```

- Impl-brief validation is always cheap and deterministic. Browser drives, screenshot loops, and environment setup are their own brief or orchestrator-run — never bolted onto an implementation brief.
- **Build-vs-install is yours, installs are the user's:** when a worker names a tool need (trigger d), you judge build-vs-install; an install is proposed to the user ("X replaces ~N lines of generated tooling — install?") and, if approved, lands pinned in the project's toolchain manifest (mise, asdf, package.json, …) or a bootstrap script.

## 6. Verification

One verifier per task — **never the implementer**, never reading the worker's thread (its claims arrive only via the report), `model: sonnet`, read-only tools (Explore agent type where available), `run_in_background: true`. Default is fresh each task; when a cluster's verification shares an expensive context root (setup stub, architecture read), a **zone verifier** may serve the cluster — same ledger rules, retires with the cluster, and every follow-up re-primes it: prior approvals are not evidence, judge this diff alone. Template:

```
Verify against a frozen snapshot — do NOT read the live tree.
Diff: <path from spec.sh diff> ; base commit <SHA> (file states via `git show <SHA>:<path>`).
The task this diff must satisfy: <task text>
House rules it must follow: <matching block(s) from specs/HOUSE-RULES.md>
Spec constraints it must follow: <proposal.md's ## Constraints section>
Worker's report: <path> — fact-check its claims against the diff.
Find a reason this fails the task. A pass verdict must quote diff lines as evidence;
otherwise report concerns, most severe first. If a requirement can't be verified from
this diff alone (it lives in unchanged code or spans tasks), report it as
⚠️ cannot-verify instead of broadening your search — don't read outside the diff to chase it.
```

Never pre-judge a verifier's findings in its dispatch — don't instruct it to ignore, downgrade, or skip a concern ("at most minor", "don't flag X"). If you expect a finding to be a false positive, let the verifier raise it and adjudicate afterward; suppressing it in the prompt is how a real defect ships.

A subagent's word alone never checks a box — the validation run is always yours.

## 7. Worker ledger

Track per worker: turns (your SendMessage count), tasks completed, failures split localized-vs-approach, and estimated context = brief size + Σ(read-file bytes ÷ 4) + report sizes — prefer harness-reported usage when shown. Decisions come from the ledger, not vibes. Starting thresholds (tune when reality disagrees): refresh/retire at ~6 turns, 2 approach failures, or est. ~100k tokens.

**Retention flex:** a worker's "context worth keeping" note buys at most one extension (~2 turns) past a threshold — the ledger stays authoritative. When the thread retires anyway, spend one final turn: "distill the flagged context into a handoff note" — and seed the successor's brief with it.

## 8. Wrap up

- **All tasks checked** → before `spec.sh done`, ask the user (AskUserQuestion) whether to run an optional final whole-branch review — a broad pass over everything the branch changed, catching cross-task issues (drift, duplication, contradictions) that the per-task verifiers' frozen-snapshot scope (§6) can't see by design. This is the one place a bigger model can pay for itself, so let the user choose it:
  1. **Run it?** Yes / No — no default steer; a multi-task or higher-risk spec is where this earns its cost, a small one may not need it.
  2. **Model?** (only if yes) — the user picks explicitly from what the harness offers. Recommend the most capable available option, since this review substitutes judgment the per-task verifiers never had, but the choice is theirs.
  If yes: compute the merge base (`git merge-base <default-branch> HEAD` — the branch this spec forked from, per `spec.sh new`), run `spec.sh diff <slug> <merge-base> HEAD` for the package, and dispatch one reviewer (Agent tool, `model: <user's choice>`, read-only tools, `run_in_background: true`) against the whole branch: the package path, `proposal.md`'s Why/What/Constraints, all of `tasks.md`, and `specs/HOUSE-RULES.md`'s `## general` block plus every area block touched. Same rules as §6 — frozen snapshot, no coaching the reviewer, findings quote diff lines. This phase informs the user; it does not auto-fix anything or block `spec.sh done` — report its findings and let the user decide what, if anything, gets fixed before merge.
- Run `spec.sh done <slug>` on the branch (flips the frontmatter and commits). Propose landing it as a **squash merge** (PR where the project uses them): per-task and fix-up commits are loop machinery, not history the default branch needs.
- Tasks remaining → leave status `in-progress`, annotate the unchecked tasks with why. The branch stays open so anyone can continue it.
- Summarize for the user: what changed, **what diverged from what the spec predicted**, which tasks went subagent vs inline, ledger stats worth noting, the final-review outcome if run, and any threshold, template, or house-rule tweaks worth folding back into `specs/HOUSE-RULES.md` or this skill.
- Per-task commits already happened in the loop (§4); push only when the user asks.
