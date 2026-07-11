# Tasks — dry-run-command-verification

- [ ] Write `scripts/foreach.sh`: usage `bash foreach.sh '<glob>' <cmd> [args…]`. Enable
  `nullglob` + `globstar`; skip non-file matches; refuse with exit 2 and a stderr reason
  when `<cmd>` contains `/` (path-shaped) or is not in the hardcoded read-only allowlist
  (`grep, wc, head, tail, cat, file, stat` — a comment states the growth criterion: no
  flag that writes to the filesystem); exec `"$cmd" "${args[@]}" "$file"` per match under a
  `== <file> ==` stdout header; continue past nonzero inner exits (e.g. `grep` no-match); a
  completed sweep exits 0, noting zero matches on stderr. Validation:
  `bash scripts/foreach.sh '*.md' wc -l` in this repo prints per-file counts;
  `bash scripts/foreach.sh '*.md' rm -f` exits 2.
- [ ] Add `tests/test-foreach.sh` (picked up by `tests/run.sh`), sandboxed in `mktemp -d`:
  allowlisted command runs across matches; refusal (exit 2 + stderr message) for
  non-allowlisted `rm -f` and path-shaped `/bin/cat`; directory matches skipped; zero-match
  glob exits 0; a `grep` no-match on one file does not abort the sweep. Validation:
  `bash tests/run.sh` passes.
- [ ] Update `scripts/legible-bash.sh` stderr text only (no rule-logic change): the
  env-var-prefix hit message adds the one-off spelling `env FOO=1 cmd` (recurring setups
  still: script or task-runner recipe); the footer line adds read-only iteration idioms —
  `find … | xargs …` and the absolute runner path resolved via `$(dirname "$0")/foreach.sh`.
  Validation: `bash tests/run.sh` (existing `tests/test-legible-bash.sh` still passes).
- [ ] Extend `tests/test-legible-bash.sh`: rejection stderr for a `FOO=1 cmd` payload
  contains `env FOO=1`; any rejection footer contains `xargs` and `foreach.sh`; a payload
  whose command is `bash <abs-repo-path>/scripts/foreach.sh *.md wc -l` exits 0.
  Validation: `bash tests/run.sh` passes.
- [ ] Update `README.md`: in the legible-bash hook table, the `FOO=1 cmd` replacement adds
  "`env FOO=1 cmd` for a one-off"; the multi-line row's replacement mentions read-only
  iteration via `find | xargs` or `scripts/foreach.sh`; the components table gains a
  `scripts/foreach.sh` row. Validation: wording matches the hook's actual stderr and the
  runner's actual allowlist (read both).
- [ ] Update `templates/legible-shell-memory.md`: env-prefix bullet gains the
  `env FOO=1 cmd` one-off spelling; new bullet for read-only per-file iteration
  (`find | xargs`, or the plugin's `foreach.sh` with its allowlist named). Validation:
  vocabulary matches the hook messages verbatim.
- [ ] Update `skills/spec-setup/SKILL.md` menu item 2 (permission allowlist) to also seed
  `Bash(bash <abs-plugin-root>/scripts/foreach.sh *)` with the literal resolved path,
  mirroring the `spec.sh` entry's wording. Validation: read-through against README's
  description of the runner.
- [ ] Bump `version` in `.claude-plugin/plugin.json` (minor — new feature). Validation:
  `git diff .claude-plugin/plugin.json` shows the bump.
- [ ] Mark spec status `done`
