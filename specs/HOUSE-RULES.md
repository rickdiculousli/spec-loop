# House Rules — paste-in blocks for /implement briefs

Each `##` section below is a named block. `/implement` pastes `## general` into **every**
implementation brief and verifier checklist, and pastes an area block (`## frontend`,
`## backend`, …) into briefs whose task touches that area.

Keep blocks short, imperative, and project-specific: the things a capable but
context-free coder would plausibly get wrong here. Commands must be real and runnable —
a placeholder command is worse than none. Fold in new rules whenever a subagent gets
something wrong that a sentence would have prevented.

## general

- Build: none — this repo ships bash scripts, prose skill files, templates, and a hook manifest; nothing is compiled.
- Test (cheap, per-task): run the single relevant `tests/test-*.sh` directly, e.g. `bash tests/test-legible-bash.sh`.
- Full suite (per cluster boundary): `bash tests/run.sh`.
- Lint/format: none. Keep bash portable (matching the existing scripts' style) and prose files matching the voice/density of existing skills.
- Runtime deps are deliberately just `bash` + `git` (the hook additionally uses `jq`/`python3` if present, and must fail open, loudly, without them) — don't introduce a new dependency to solve a task.
- Cross-file coupling: the frontmatter schema and the `spec.sh` subcommand surface are each restated in `scripts/spec.sh`, all three skills, `templates/specs-README.md`, and `README.md`. Changing any of them means updating all of those in the same commit.
- Bump `version` in `.claude-plugin/plugin.json` before the final commit of any change touching scripts/skills/hooks/templates (patch for fixes, minor for new features/knobs).

<!-- Area blocks — add as the project's shape demands. Examples:

## frontend

- Read docs/component-guidelines.md before writing components.
- State lives in <pattern>; never mutate it outside <place>.
- Regenerate generated artifacts with <command>; never hand-edit <dir>.

## backend

- Handlers stay thin; logic belongs in <package/dir>.
- Changed public signatures → run <codegen command>.
- All times UTC; date format helpers live in <module>.

-->
