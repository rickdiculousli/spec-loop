---
title: Engine-agnostic diagram subloop in /brainstorm
status: proposed
priority: P2
effort: S
created: 2026-07-15
depends_on: "-"
sequencing: Only active spec in the portfolio; independent of everything done or iceboxed.
---

# Engine-agnostic diagram subloop in /brainstorm

## Why

Watching a design take shape as a diagram during `/brainstorm` beats re-reading prose — but the 2026 diagram-tool ecosystem (Excalidraw MCP servers, canvas skills, text-to-diagram CLIs) churns fast, and every credible engine drags in a dependency class this plugin refuses (node, pip, a running server). Research on the two leading Excalidraw options confirmed the split: the popular skill hand-writes raw canvas JSON at 100k+ tokens per diagram, and the clean batched MCP server is four months old. The durable part isn't any engine — it's the loop discipline: a compact text source of truth, regeneration only on structural change, never hand-written canvas JSON. That contract can ship engine-free.

## What

- `skills/brainstorm/SKILL.md` gains a diagram-subloop clause: when the project's `specs/README.md` (or `specs/HOUSE-RULES.md`) declares a diagram tool, maintain a diagram of the design structure in `specs/<slug>/` during questioning — updating only on structural change (new component, moved scope boundary, new dependency), keeping a compact text source of truth, and never hand-writing raw canvas JSON (e.g. `.excalidraw` element arrays). Diagram files ride along with `spec.sh save` like any other spec file. No declared tool → no subloop, silently.
- `templates/specs-README.md` gains a commented-out example declaration line in Conventions, so consuming repos know the format brainstorm looks for.
- `README.md` documents the subloop in the brainstorm section.
- This repo's `specs/README.md` icebox gains an entry for the full `/visualize` feature (bundled engine + standalone skill) with re-entry criteria.
- `.claude-plugin/plugin.json` version bump to 0.9.0 (new behavior, minor).

## Constraints

- No new runtime dependencies, no engine named as required, no scripts touched — the clause must degrade to a no-op in repos that declare nothing.
- The clause must not extend `/brainstorm`'s question budget or add per-answer overhead; diagram updates happen only on structural change.
- Checkbox-truthfulness and all existing skill contracts stay intact.

## Out of scope

- Bundling or requiring any engine (yctimlin/mcp_excalidraw, excalidraw-architect-mcp, D2, etc.) — per-repo choice, recorded in design.md.
- A standalone `/visualize` skill or compiler script in this plugin — iceboxed with re-entry criteria.
- `/implement`-time diagram maintenance — future spec if the brainstorm subloop proves out.
- Hand-edit merge tooling, live-view servers, or any viewer glue — engine/repo concerns.

## Success criteria

- Current: `skills/brainstorm/SKILL.md` has no diagram guidance. Target: it carries the diagram-subloop clause — declared-tool trigger, structural-change gating, compact source of truth, raw canvas JSON prohibition. Acceptance: `grep -c "diagram" skills/brainstorm/SKILL.md` ≥ 1 and the clause names all four rules on read-through.
- Current: `templates/specs-README.md` offers no way to declare a diagram tool. Target: a commented-out example declaration line in Conventions. Acceptance: `grep "diagram" templates/specs-README.md` shows the example line.
- Current: `README.md` doesn't mention the subloop. Target: brainstorm section documents it in one short paragraph. Acceptance: `grep -i "diagram" README.md` hits in the brainstorm section.
- Current: plugin version 0.8.0. Target: 0.9.0. Acceptance: `grep '"version"' .claude-plugin/plugin.json` shows `0.9.0`.
