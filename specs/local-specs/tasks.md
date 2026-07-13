# Tasks — local-specs

- [x] In `scripts/spec.sh`, add the `SPEC_LOOP_SPECS` knob: a `case` block validating
  `git` (default) or `local` — die with a message containing `SPEC_LOOP_SPECS must be`
  for anything else, mirroring the existing `SPEC_LOOP_PUSH` block. Add an `is_local()`
  helper mirroring `should_push()`. Add an `ignore_spec_dir <slug>` helper that writes
  `specs/<slug>/.gitignore` containing a single unnegated `*` if the file doesn't already
  exist (same self-ignoring trick `workspace_dir()` uses for `.spec-loop/`, scoped to one
  slug's folder — copy its explanatory comment, adapted). Wire it into `new`: after
  `mkdir -p "$SPEC_DIR"`, call `ignore_spec_dir "$SLUG"` when `is_local`; adjust the
  command's final `echo` to mention local mode when active. Validate:
  `SPEC_LOOP_SPECS=local bash scripts/spec.sh new demo` in a sandbox repo, then
  `git status --porcelain` prints nothing.

- [x] In `scripts/spec.sh`'s `save` case, keep the existing `$PROPOSAL`/`tasks.md`
  existence checks but skip `git add`/`git diff --cached --quiet`/`commit`/push entirely
  when `is_local`; print `spec.sh: SPEC_LOOP_SPECS=local — specs/$SLUG stays local,
  nothing committed` instead. Validate: after task 1's `new`, write minimal
  `proposal.md`/`tasks.md`, run `SPEC_LOOP_SPECS=local bash scripts/spec.sh save demo`,
  confirm `git log --oneline` is unchanged (no new commit) and the message above appears.

- [x] In `scripts/spec.sh`'s `start` case, keep the branch-checkout logic and
  `set_status "$PROPOSAL" "in-progress"` but skip the `git add`/`commit`/push for that
  flip when `is_local`. Reword the `elif [[ -d "$SPEC_DIR" ]]` fallback's echo so it
  doesn't claim the spec was "already merged" when in local mode — branch on `is_local`
  and say "specs folder found locally; reopening its branch" instead. Validate: `git
  checkout main` (or the sandbox's default branch), then
  `SPEC_LOOP_SPECS=local bash scripts/spec.sh start demo`; confirm `git log --oneline`
  has no new commit and `specs/demo/proposal.md` now reads `status: in-progress`.

- [x] In `scripts/spec.sh`'s `done` case, run `set_status "$PROPOSAL" "done"` but skip
  `git add`/`commit` when `is_local`. Validate:
  `SPEC_LOOP_SPECS=local bash scripts/spec.sh done demo`; confirm `git log --oneline` has
  no new commit and `specs/demo/proposal.md` now reads `status: done`.

- [x] Add an `untrack` subcommand to `scripts/spec.sh`: `resolve_slug`; die unless the
  current branch equals `$SLUG` (mirror `save`'s check); die with a message containing
  `is not git-tracked` unless `git ls-files --error-unmatch "$SPEC_DIR" >/dev/null 2>&1`
  succeeds; then `git rm -r --cached "$SPEC_DIR" >/dev/null`, commit
  `"spec($SLUG): untrack — local only from here"`, then call `ignore_spec_dir "$SLUG"`.
  Validate: in a sandbox repo, `spec.sh new t2` → write proposal/tasks → `spec.sh save
  t2` (default git mode, so it's committed) → `spec.sh untrack t2`; confirm `git ls-files
  specs/t2` is empty and `git log --oneline` gained a commit mentioning `untrack`.

- [x] Add a `track` subcommand to `scripts/spec.sh` (reverse of `untrack`):
  `resolve_slug`; die unless the current branch equals `$SLUG`; die with a message
  containing `is not in local mode` unless `specs/$SLUG/.gitignore` exists; then
  `rm -f "$SPEC_DIR/.gitignore"`, `git add "$SPEC_DIR"`, commit
  `"spec($SLUG): track — git-tracked from here"`. Also update `scripts/spec.sh`'s
  top-of-file header comment (the numbered subcommand list) and the final
  `*) die "usage: ..."` line to include `untrack`/`track`, and add a `SPEC_LOOP_SPECS`
  line to the header's `Config via env` block alongside the existing `SPEC_LOOP_PUSH`
  line. Validate: continuing from the previous task's sandbox, `spec.sh track t2`;
  confirm `git ls-files specs/t2` is non-empty again and `git log --oneline` gained a
  `track` commit. Then `bash scripts/spec.sh` (no args) prints usage mentioning both new
  subcommands.

- [x] Update `skills/brainstorm/SKILL.md`: in step 3, after the sentence about running
  `spec.sh save <slug>` to commit the folder, add a sentence noting that under
  `SPEC_LOOP_SPECS=local` nothing is committed or pushed — the folder stays local-only on
  disk. Adjust the intro paragraph's "the terminal state is a spec branch (pushed if a
  remote exists)" sentence with a short clause covering the local-mode variant. Validate:
  reread both spots for accuracy against task 1-2's actual `spec.sh` behavior.

- [x] Update `skills/implement/SKILL.md`: in step 1, after the sentence about running
  `spec.sh start <slug>`, add one clause noting that under `SPEC_LOOP_SPECS=local` the
  in-progress flip is written to disk but not committed. Validate: reread against task 3's
  actual behavior.

- [x] Restructure `skills/spec-setup/SKILL.md`'s "Configuration knobs" section: replace
  the single bundled "keep or customize" question (which prior use reported as friction —
  can't accept one knob's default while changing another without an extra round-trip)
  with one AskUserQuestion call containing three separate per-knob questions, in this
  order: `SPEC_LOOP_SPECS` first, then `LEGIBLE_BASH`, then `SPEC_LOOP_PUSH`. Each
  question's options are that knob's actual values, current default labeled
  "(recommended)" — `SPEC_LOOP_SPECS`: `git` (recommended) / `local`; `LEGIBLE_BASH`:
  `block` (recommended) / `warn` / `off`; `SPEC_LOOP_PUSH`: `auto` (recommended) / `off`.
  Update the intro sentence (currently names only two knobs as "already live") to name
  all three. Keep the existing settings-scope question as a single shared follow-up,
  asked once and only if at least one answer differed from its default — do not turn it
  into a per-knob question too. Update the "merge into that scope's env object" closing
  guidance to merge only the values that changed. Validate: reread the section —
  it presents three independent per-knob questions (not one combined keep/customize
  choice) followed by at most one scope question, with `SPEC_LOOP_SPECS` listed first.

- [ ] Update `README.md`: add a third row to the Configuration table for
  `SPEC_LOOP_SPECS` (`git` default / `local`, controls whether `new/save/start/done`
  touch git under `specs/`); update the sentence introducing the table ("Both knobs" →
  wording that covers three); add `spec.sh untrack <slug>` / `spec.sh track <slug>` lines
  to the `spec.sh reference` section with one-line descriptions; add a sentence near the
  `save`/`start`/`done` lines noting the local-mode git-skip behavior. Also update
  `templates/specs-README.md`'s lifecycle bullet ("The default branch is never written
  directly...") with a clause covering local mode: under it, the spec itself never lands
  in git at all — only the branch's code commits do. Validate: reread both files for
  consistency with `scripts/spec.sh`'s actual behavior from the tasks above.

- [ ] Update `CLAUDE.md`: add `SPEC_LOOP_SPECS` to the "Config knobs are env vars read at
  runtime..." bullet under Core invariants, alongside `LEGIBLE_BASH`/`SPEC_LOOP_PUSH`; add
  `untrack`/`track` wherever the "Cross-file coupling" paragraph names the `spec.sh`
  subcommand surface; add a bullet to the Testing changes section describing
  `tests/test-local-specs.sh`, matching the one-line style used for
  `test-push-knob.sh`/`test-coverage-gate.sh`. Validate: reread each spot against the
  actual `scripts/spec.sh` changes and the new test file from the next task.

- [ ] Add `tests/test-local-specs.sh`, mirroring `tests/test-push-knob.sh`'s sandbox
  pattern (`mktemp -d`, bare origin + work clone, `trap` cleanup). Cover: (a)
  `SPEC_LOOP_SPECS=local spec.sh new` leaves `git status --porcelain` empty and
  `specs/<slug>/.gitignore` present; (b) `save`/`start`/`done` under local make no new
  commits (`git rev-parse HEAD` unchanged across each call) while `proposal.md`'s
  `status:` line still flips each time; (c) a bogus `SPEC_LOOP_SPECS` value is rejected
  with a message containing `SPEC_LOOP_SPECS must be`; (d) on a spec created and
  committed under default `git` mode, `untrack` leaves `git ls-files specs/<slug>` empty
  with a new commit in `git log`, and a subsequent edit to that spec's `tasks.md` does not
  appear in `git status --porcelain`; (e) `track` afterward makes
  `git ls-files specs/<slug>` non-empty again. Validate: `bash tests/test-local-specs.sh`
  exits 0.

- [ ] Bump `version` in `.claude-plugin/plugin.json` from `0.5.2` to `0.6.0` (minor — new
  `SPEC_LOOP_SPECS` knob and two new `spec.sh` subcommands). Validate:
  `grep '"version"' .claude-plugin/plugin.json` shows `0.6.0`.

- [ ] Run the full suite and confirm everything passes together, proving default-mode
  behavior is unchanged: `bash tests/run.sh`.

- [ ] Mark spec status `done`
