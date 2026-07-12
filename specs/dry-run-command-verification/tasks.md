# Tasks — dry-run-command-verification

- [x] Update `scripts/legible-bash.sh` stderr text only (no rule-logic change): the
  env-var-prefix hit message adds the one-off spelling `env FOO=1 cmd` (recurring setups
  still: script or task-runner recipe); the shared footer line adds the read-only
  iteration idiom `find … | xargs …`. Validation: `bash tests/run.sh` (existing
  `tests/test-legible-bash.sh` still passes unchanged).
- [x] Extend `tests/test-legible-bash.sh` with idiom assertions: rejection stderr for a
  `FOO=1 cmd` payload contains `env FOO=1`; rejection stderr (footer) contains `xargs`;
  payloads `env FOO=1 make test` and `find . -name *.txt | xargs wc -l` both exit 0,
  pinning the taught spellings as passing. Validation: `bash tests/run.sh` passes.
- [x] Update `README.md` legible-bash hook table: the `FOO=1 cmd` row's replacement adds
  "`env FOO=1 cmd` for a one-off"; the multi-line row's replacement mentions read-only
  iteration via `find | xargs`. Validation: wording matches the hook's actual stderr
  (read both).
- [x] Update `templates/legible-shell-memory.md`: the env-prefix bullet gains the
  `env FOO=1 cmd` one-off spelling; the multi-statement bullet (or a new bullet) names
  `find | xargs` for read-only per-file iteration before reaching for a scratchpad
  script. Validation: vocabulary matches the hook messages verbatim.
- [x] Bump `version` in `.claude-plugin/plugin.json` (patch — message/doc improvement).
  Validation: `git diff .claude-plugin/plugin.json` shows the bump.
- [ ] Mark spec status `done`
