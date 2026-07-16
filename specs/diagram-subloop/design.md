# Design — diagram-subloop

## How the scope collapsed

The idea started as a full feature in this plugin: a `/visualize` skill + a DSL→`.excalidraw` compiler script + a brainstorm subloop. Two research passes (2026-07-15, Sonnet subagents: a deep-dive on the two candidate repos, a broad ecosystem survey) killed the bundled-engine version:

- **coleam00/excalidraw-diagram-skill** (4.1k★) — rejected. Mandates hand-writing raw Excalidraw JSON element-by-element plus a Playwright+Chromium render-critique loop; its own tracker reports 100k+ tokens for one example diagram (issues #36, #33). 2 commits on main, open renderer bugs (#38, #35, #21), **no license file** (#8) — unbundleable.
- **BV-Venky/excalidraw-architect-mcp** (135★, MIT) — best token shape: pure-Python pip (fastmcp, pydantic, grandalf), one batched `create_diagram(nodes[], connections[])`, git-diffable `architecture.md` source of truth. But ~4 months old, no live view (manual drag into excalidraw.com), and full Sugiyama re-layout clobbers hand-edits.
- **yctimlin/mcp_excalidraw** (2.2k★, MIT, active) — the only tool solving both hard problems: live browser canvas via WebSocket sync (works for Zed users — no editor extension), and incremental state that imports existing `.excalidraw`, so hand-sketches survive agent turns. Cost: Node ≥18 + a running local server; per-element CRUD needs skill prose mandating batch/apply ops.
- **D2** (24.7k★, single Go binary, `d2 --watch` live-reload) — best install/maintenance profile surveyed, but no sketchable canvas and not the Excalidraw aesthetic the user wanted.
- Official `excalidraw/excalidraw-mcp` — chat-widget-shaped (MCP Apps, renders inline in claude.ai), not repo-file-shaped.
- Python generators (excaligen 3★, Excalidraw-Interface, four unrelated `excalidraw-cli`s) — fragmented, unproven; they solve JSON emission, not layout or viewing.

Every credible engine drags in a dependency class this plugin refuses (node, pip, a persistent server), and the space is churning (MCP Apps stabilized only this year). Decision: **the engine is a per-repo choice; the plugin ships only the loop contract.**

## What the contract encodes (the durable part)

1. **Declared-tool trigger** — brainstorm looks for a diagram-tool declaration in the consuming repo's `specs/README.md`/`specs/HOUSE-RULES.md`; absent → no-op.
2. **Structural-change gating** — update the diagram only when a component, boundary, or dependency changes, not per answer.
3. **Compact text source of truth** — the model edits a small text form (mermaid, D2, an engine's node/edge payload), never coordinates.
4. **No hand-written canvas JSON** — raw `.excalidraw`-style element arrays are the proven 100k-token anti-pattern.

## Per-repo setup this design assumes (documentation, not deliverable)

A consuming repo that wants the loop: install its engine (e.g. `yctimlin/mcp_excalidraw` in `.mcp.json`), declare it in `specs/README.md`, and brainstorm picks it up. Hand-edit preservation and live viewing are properties of the chosen engine, not of spec-loop.

## Icebox re-entry criteria for the full /visualize feature

- The ecosystem consolidates on a maintained pip-or-single-binary engine with hand-edit preservation, **or**
- two consuming repos independently build the same per-repo setup (evidence the contract alone is insufficient).
