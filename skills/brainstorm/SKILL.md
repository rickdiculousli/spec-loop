---
name: brainstorm
description: Socratic spec builder. Turns a rough idea into a specs/<slug>/ initiative folder (proposal.md + tasks.md) on its own branch by interrogating the idea one question at a time and pushing back on scope creep. Use when the user wants to spec out a new initiative or feature before any implementation.
argument-hint: <idea>
---

# /brainstorm — Idea → Spec

Turn the user's idea into a new initiative folder under `specs/`, on its own branch. You are building a spec, **not implementing anything** — the terminal state is a spec branch (pushed if a remote exists) plus the suggestion to run `/implement` later. Under `SPEC_LOOP_SPECS=local`, the branch still opens the same way but the spec folder never lands in git — see step 3.

All git choreography goes through `scripts/spec.sh` in this plugin. Resolve it to an absolute path once (this skill's directory is `<plugin>/skills/brainstorm/`; the script is `<plugin>/scripts/spec.sh`) and invoke it as `bash <abs-path>/spec.sh <cmd> <slug>` — never re-derive the git steps by hand, and never write to the default branch.

## 1. Orient (before asking anything)

- Read `specs/README.md` (project conventions + icebox). If it doesn't exist, suggest running `/spec-setup` first and stop.
- Run `spec.sh list` for the current portfolio.
- If the idea touches existing code, skim only the directly relevant files so your questions are informed. Do not explore broadly.
- If the idea overlaps an existing spec or an icebox entry, say so now and ask whether to continue.

## 2. Interrogate — one question at a time

Ask with AskUserQuestion, **one question per message**, multiple-choice where sensible. Stop asking when you could write the proposal without inventing answers — usually 4–7 questions. Cover, in roughly this order:

1. **Goal** — what outcome, in one sentence? What's broken or missing today?
2. **Who it's for** — which users or operators, and what changes for them.
3. **Constraints** — budget, tooling, platforms, compatibility, things it must not break.
4. **MVP line** — the smallest version that's still worth doing. Push here: propose a cut-down version and ask if it's enough.
5. **Out of scope** — what tempting adjacent work is explicitly excluded.
6. **Success criteria** — for each, get a Current / Target / Acceptance triple: where things stand today, what they should be, and a falsifiable pass/fail check (a runnable command or a precisely observable behavior) that proves it — not vibes, and not free prose.
7. **Priority/effort** — P0–P3, S/M/L, and where it sits relative to the portfolio (`spec.sh list`).

**Use the project's decision tools where they exist.** If `specs/README.md` or the project's skills name a better way to resolve a class of question (e.g. a component-variants skill for visual choices, a prototyping harness for interaction feel), invoke it instead of asking in prose — the user judges rendered output better than descriptions. `tasks.md` steps may likewise name such a round as the way a task resolves its design.

**Scope pushback is your job, not politeness.** If the idea bundles independent subsystems, flag it immediately and propose splitting into separate specs. If an answer grows the scope, name the growth and ask whether it belongs in MVP, out-of-scope, or a future spec.

## 3. Open the branch, then write

- Pick a slug: short, lowercase, hyphenated, named for the outcome (`toplist-grid-view`, not `fix-stuff` or `misc-improvements`).
- Run `spec.sh new <slug>` — verifies a clean tree on the default branch, opens branch `<slug>`, creates `specs/<slug>/`.

Create in `specs/<slug>/`:

**`proposal.md`** — frontmatter is the registry (rendered by `spec.sh list`), so fill it fully: `title`, `status: proposed`, `priority` (P0–P3), `effort` (S/M/L), `created` (today, YYYY-MM-DD), `depends_on` (slugs as free text, e.g. `"auth-rework (soft)"`, or `-`), and a one-line `sequencing` note placing it in the portfolio order. Then sections: `## Why`, `## What`, `## Constraints`, `## Out of scope`, `## Success criteria`. Match the voice and density of existing proposals. Short — a proposal that fits on one screen gets read.

`## Success criteria` bullets are Current / Target / Acceptance triples, not free prose — one bullet per criterion:
```
- Current: <where things stand today>. Target: <what it should be instead>. Acceptance: <a runnable command or precisely observable check that proves it>.
```
Acceptance must be falsifiable — something that can concretely pass or fail, not "works well" or "is checkable in principle." `spec.sh check` heuristically warns when a criterion's significant words don't appear anywhere in `tasks.md`, so keep Current/Target/Acceptance in vocabulary that also shows up in the tasks that implement it.

**`tasks.md`** — `# Tasks — <slug>` then a flat checkbox list. Rules:
- Tasks are ordered, concrete, and individually checkable. Name exact files where known.
- Each task that produces code names its validation: a runnable shell command, or a precisely observable behavior.
- No placeholders: never "TBD", "refactor sensibly", "handle errors appropriately". If you can't write the task concretely, you're missing an answer — go ask.
- End with `- [ ] Mark spec status \`done\``.

**`design.md`** — only if real design decisions surfaced during questioning; otherwise skip.

Then run `spec.sh check` to validate the frontmatter, and `spec.sh save <slug>` to commit the folder on the branch (and push it, if a remote exists — unless the project sets `SPEC_LOOP_PUSH=off`). Under `SPEC_LOOP_SPECS=local`, `save` writes and validates the files as usual but commits nothing — `specs/<slug>/` stays git-ignored and local-only.

## 4. Self-review before presenting

Check your own output:
- **Placeholder scan** — no TBD/TODO/vague tasks anywhere.
- **Consistency** — tasks cover everything `## What` promises; nothing in tasks exceeds it.
- **Scope** — fits one initiative; if it doesn't, split now.
- **Executable by a stranger** — every task is doable without unstated judgment or tribal knowledge.

Fixes from this pass are edits + another `spec.sh save <slug>`. Present the spec, note anything you cut or deferred during questioning, and suggest `/implement <slug>` as the next step. Do not start implementing.
