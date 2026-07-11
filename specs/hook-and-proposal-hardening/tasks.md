# Tasks — hook-and-proposal-hardening

- [x] Fix the double-quote blind spot in `scripts/legible-bash.sh`. Split the single
  `judged` pipeline into two: keep the existing both-quotes-stripped variable (rename or
  keep as `judged`) for the compound-statement check (`;`/`&&`/`||`) and the other
  structural checks (`cd`, env-var prefix, `sleep`, trailing `&`) — those are unaffected.
  Add a second variable, stripped of single-quoted spans only (double-quoted spans left
  intact), and point the command-substitution (`$(`/backtick) and variable-expansion
  (`\$[A-Za-z_{]`) checks at it instead. Update the doctrine comment block (lines ~34-37)
  to describe the split and why (only single quotes neutralize `$` in bash). Validate:
  `printf '{"tool_input":{"command":"echo \"$(cat /etc/passwd)\""}}' | bash scripts/legible-bash.sh; echo $?`
  must print `2` on the last line.

- [x] Extend `tests/test-legible-bash.sh` with cases for the fix above: a `check 2 block`
  case for `echo \"$(date)\"` (command substitution inside double quotes now rejected)
  and one for `echo \"$HOME\"` (variable expansion inside double quotes now rejected).
  Confirm the existing `grep \"a && b\" file.txt` passing case still passes unchanged
  (double-quoted literal `&&` has no `$`, so it's unaffected by the split). Validate:
  `bash tests/test-legible-bash.sh` exits 0 and prints `ok:` for both new cases.

- [x] Fix the silent fail-open in `scripts/legible-bash.sh`: in the `else` branch that
  runs when neither `jq` nor `python3` is on `PATH` (currently a bare `exit 0`), print an
  stderr line naming both missing tools before exiting 0, e.g.
  `echo "legible-bash: no jq or python3 found — allowing Bash call unchecked (install jq or python3 to restore the guard)" >&2`.
  Validate: `printf '{"tool_input":{"command":"cd /x && make"}}' | PATH=/usr/bin bash scripts/legible-bash.sh; echo $?`
  (a `PATH` with neither tool) prints the warning on stderr and `0` as the exit code —
  confirm both by running once with `2>&1 >/dev/null` to isolate stderr.

- [x] Add a test case to `tests/test-legible-bash.sh` for the fail-open-loud fix: invoke
  the hook with a `PATH` containing neither `jq` nor `python3` (find a minimal real
  directory on the test machine with neither, or construct one with `mktemp -d` containing
  no binaries) and assert stderr is non-empty and mentions both `jq` and `python3`, while
  the exit code is still `0`. Validate: `bash tests/test-legible-bash.sh` passes with the
  new case included.

- [x] Add a coverage-gate warning to `spec.sh check` in `scripts/spec.sh`. For each spec
  directory already being validated, extract bullet lines (`^- `) under the `## Success
  criteria` heading of `proposal.md` (stop at the next `## ` heading or EOF). For each
  bullet, lowercase it, strip punctuation, split on whitespace, keep tokens with length
  >= 4 excluding a short stop-word list (e.g. `this that with from must have been every
  when where`), and warn (via the existing `warn()` helper — never `fail()`) if none of
  those tokens (as case-insensitive substrings) appear anywhere in that spec's
  `tasks.md`. Skip specs with no `## Success criteria` section or no bullets under it
  (nothing to check). Validate: build a throwaway spec via `spec.sh new` in a sandbox repo
  whose Success-criteria bullet shares no significant word with its `tasks.md`, then
  confirm `spec.sh check` prints a `warn:` line for it and exits `0`.

- [x] Add `tests/test-coverage-gate.sh`, mirroring the sandbox-repo pattern in
  `tests/test-push-knob.sh` (bare origin + work clone in `mktemp -d`, trap cleanup). Cover:
  (a) a proposal whose Success-criteria bullet's keywords are absent from tasks.md
  produces a `warn:` line and `spec.sh check` still exits 0; (b) a proposal whose bullet's
  keywords do appear in tasks.md produces no warning for that spec; (c) a proposal with no
  `## Success criteria` section at all produces no coverage-related warning (only
  whatever other checks already apply). Add this script to whatever `tests/run.sh` uses to
  discover `test-*.sh` files (confirm no registration step is needed beyond the filename
  pattern — read `tests/run.sh` first). Validate: `bash tests/run.sh` picks it up and it
  passes.

- [x] Tighten `skills/brainstorm/SKILL.md` for the Current/Target/Acceptance triad.
  Update the interrogation list's success-criteria line (around line 29) to ask for a
  falsifiable Current/Target/Acceptance per criterion, not just "checkable, not vibes."
  Update the proposal-writing section (around line 43) so the `## Success criteria`
  description requires the triad, with a one-line example format (Current: ...; Target:
  ...; Acceptance: a runnable command or precisely observable check). Validate: re-read
  the file and confirm no remaining wording describes Success criteria as free prose.

- [x] Update `README.md` in three spots to stay accurate: (1) the Requirements section's
  fail-open line (~line 19) to mention the hook now warns before allowing; (2) the
  legible-bash section (~line 86) to describe the split quote-handling — single-quoted
  spans always stripped, double-quoted spans stripped only for the compound-statement
  check, so `$(...)`/`$VAR` inside double quotes is still caught; (3) the `spec.sh
  reference` section's `check` line (~line 113) to mention the new Success-criteria
  coverage warning. Validate: reread each updated line in context for accuracy.

- [x] Update `CLAUDE.md`'s description of the hook's quote-stripping (the "judges shell
  *structure*, not content" paragraph) to describe the split behavior, and confirm the
  existing fail-open sentence ("fails open without them — preserve that") still holds and
  now additionally implies "loudly." Validate: reread the paragraph against the actual
  code in `scripts/legible-bash.sh` after the fix.

- [x] Bump `version` in `.claude-plugin/plugin.json` from `0.3.0` to `0.4.0` (minor —
  new `spec.sh check` behavior and a template/skill change, alongside the two bug fixes).
  Validate: `grep '"version"' .claude-plugin/plugin.json` shows `0.4.0`.

- [x] Run the full suite and confirm everything passes together: `bash tests/run.sh`.

- [x] Mark spec status `done`
