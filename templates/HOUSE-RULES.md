# House Rules — paste-in blocks for /implement briefs

Each `##` section below is a named block. `/implement` pastes `## general` into **every**
implementation brief and verifier checklist, and pastes an area block (`## frontend`,
`## backend`, …) into briefs whose task touches that area.

Keep blocks short, imperative, and project-specific: the things a capable but
context-free coder would plausibly get wrong here. Commands must be real and runnable —
a placeholder command is worse than none. Fold in new rules whenever a subagent gets
something wrong that a sentence would have prevented.

## general

- Build: `<command>`
- Test (cheap, per-task): `<command>`
- Full suite (per cluster boundary): `<command>`
- Lint/format: `<command>`

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
