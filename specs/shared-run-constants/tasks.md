# Tasks — shared-run-constants

**Iceboxed — not executed.** See `proposal.md`'s Iceboxed section: deferred because the
pain is hypothetical — no observed `/implement` run has shown turns wasted re-resolving
run-static values, and orchestrator-pastes-literals already covers most of the surface.
Left unchecked as a record of the intended shape, not a to-do list.

- [ ] Add an `env` subcommand to `scripts/spec.sh` (alongside `brief`/`diff` in the case
  statement and the usage line): `spec.sh env <slug>` prints to stdout one labeled line
  each for repo root (`git rev-parse --show-toplevel`), default branch (same resolution
  `new` uses), spec dir (`specs/<slug>`), workspace dir (`.spec-loop/<slug>`), and the
  plugin scripts dir (the directory containing `spec.sh` itself). It must print no commit
  SHAs and no tree state, and must not create or modify any file — read-only, safe to run
  anywhere with a `specs/` dir, like `list`/`check`. Validate:
  `bash scripts/spec.sh env shared-run-constants` exits 0 and prints all five labeled
  lines.

- [ ] Add `tests/test-env.sh` (auto-discovered by `tests/run.sh`'s `test-*.sh` glob):
  build a throwaway repo in `mktemp -d` (pattern from `test-coverage-gate.sh`, no remote
  needed), run `spec.sh env`, and assert (a) each of the five labeled constants is
  present, (b) the output does not contain the repo's HEAD SHA in short or full form,
  (c) a missing slug argument dies with a usage error. Validate:
  `bash tests/test-env.sh` passes.

- [ ] Update `skills/implement/SKILL.md`: in §1 (or §3), the orchestrator runs
  `spec.sh env <slug>` once at start and records the printed block in the run-state file
  so a resumed run doesn't re-derive it; add a `Resolved constants: <paste the spec.sh env
  block>` line to the impl-worker brief template (§5) and to the verifier template (§6).
  Validate: `grep -c "Resolved constants" skills/implement/SKILL.md` prints 2 or more.

- [ ] Restate the new subcommand across the coupling set (per CLAUDE.md): add `env` to
  README's subcommand table and, if `templates/specs-README.md` names spec.sh subcommands,
  there too. Validate: `grep -F "spec.sh env" README.md` matches; reread
  `templates/specs-README.md` for consistency.

- [ ] Bump `version` in `.claude-plugin/plugin.json` (minor — new subcommand). Validate:
  `grep '"version"' .claude-plugin/plugin.json` shows the bumped value.

- [ ] Run the full suite: `bash tests/run.sh` passes.

- [ ] Mark spec status `done`
