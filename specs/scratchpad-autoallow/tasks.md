# Tasks — scratchpad-autoallow

- [ ] Restructure `scripts/legible-bash.sh`'s early exit: move the JSON-parsing block
  (jq/python3 extraction of `.tool_input.command` and `.session_id`) so it runs *before*
  the `if [ "$mode" = "off" ]; then exit 0; fi` check, not after. Keep the existing
  fail-open-loud behavior (warn + exit 0) when neither `jq` nor `python3` is present, and
  keep the existing empty-`cmd` fast exit. Extract `session_id` the same way `cmd` is
  extracted (`.session_id // empty` for jq; `.get("session_id","")` for the python3
  fallback). Validate: `bash tests/test-legible-bash.sh` still passes unchanged (no
  regressions from reordering).

- [ ] In `scripts/legible-bash.sh`, add the match check against the pre-quote-stripped
  command text (`preprocessed`, not `judged`/`judged_dq`, since real paths may be quoted):
  true if `preprocessed` contains the literal substring `/${session_id}/scratchpad/` (only
  when `session_id` is non-empty) or contains the literal substring `.spec-loop/`. Add
  `autoallow="${SPEC_LOOP_SCRATCHPAD_AUTOALLOW:-on}"` near the top alongside `mode`. Add a
  small helper, e.g. `emit_allow() { [ "$autoallow" != "off" ] && [ "$match" = "1" ] && printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"spec-loop: command references this session'\''s scratchpad or .spec-loop scratch dir"}}'; }`
  (adjust quoting as needed for a valid, statically-legible bash one-liner). Validate: read
  the diff and confirm `match`/`emit_allow` are defined before any point that calls them.

- [ ] Wire `emit_allow` into the three allow paths in `scripts/legible-bash.sh`: (1) the
  `mode = off` fast path — call `emit_allow` then `exit 0`; (2) the existing
  `if [ -z "$msgs" ]; then exit 0; fi` clean-pass path — call `emit_allow` first; (3) the
  `warn` mode path (currently `exit 1` after printing `msgs`) — call `emit_allow` before
  that `exit 1`. Do **not** call `emit_allow` on the final `block`-mode `exit 2` path.
  Validate: `printf '{"session_id":"abc123","tool_input":{"command":"bash /x/abc123/scratchpad/a.sh"}}' | bash scripts/legible-bash.sh` prints a `permissionDecision":"allow"` JSON line on stdout and exits `0`.

- [ ] Add the `SPEC_LOOP_SCRATCHPAD_AUTOALLOW` knob to the doctrine comment block at the
  top of `scripts/legible-bash.sh` (same style as the existing `LEGIBLE_BASH` modes
  comment), documenting default `on` and the `off` value. Validate: reread the comment
  block against the actual code for accuracy.

- [ ] Add `tests/test-scratchpad-autoallow.sh` with a `check_allow <want-substring-present:0|1> <env-vars...> <json-payload> <label>` style helper (capture stdout, don't discard it) covering: (a) command containing `/<session_id>/scratchpad/` → stdout contains `"permissionDecision":"allow"`; (b) command containing `.spec-loop/some-slug/brief-1.md` → same; (c) command with a path that matches neither pattern (e.g. `bash /tmp/other/script.sh`) → stdout does not contain `permissionDecision`; (d) same as (a) but with `SPEC_LOOP_SCRATCHPAD_AUTOALLOW=off` → stdout does not contain `permissionDecision`; (e) same as (a) but with `LEGIBLE_BASH=off` → stdout still contains `"permissionDecision":"allow"`; (f) command `bash /x/<sid>/scratchpad/a.sh && bash /x/<sid>/scratchpad/b.sh` (compound, same session_id) → exit code `2`, stdout does not contain `permissionDecision`. Validate: `bash tests/test-scratchpad-autoallow.sh` passes; it's auto-discovered by `tests/run.sh`'s `test-*.sh` glob (confirmed by reading `tests/run.sh` — no separate registration needed).

- [ ] Update `README.md`: add `SPEC_LOOP_SCRATCHPAD_AUTOALLOW` to the Configuration table
  (values `on` (default) / `off`, controls: the legible-bash hook's permission-prompt
  auto-allow for scratchpad/`.spec-loop` paths) and add one sentence to the legible-bash
  section noting that a legible call referencing this session's scratchpad or a
  `.spec-loop/<slug>/` path also skips the interactive permission prompt, with explicit
  deny/ask rules in settings still taking precedence. Validate:
  `grep -F "SPEC_LOOP_SCRATCHPAD_AUTOALLOW" README.md` matches.

- [ ] Update `CLAUDE.md`'s Core invariants section: add a short bullet or extend the
  existing hook-exit-code-protocol bullet to mention the `SPEC_LOOP_SCRATCHPAD_AUTOALLOW`
  knob and that it must never bypass the structural block path. Validate: reread the
  paragraph against the actual code in `scripts/legible-bash.sh` after the fix.

- [ ] Bump `version` in `.claude-plugin/plugin.json` (minor — new knob and hook behavior).
  Validate: `grep '"version"' .claude-plugin/plugin.json` shows the bumped value.

- [ ] Run the full suite and confirm everything passes together: `bash tests/run.sh`.

- [ ] Mark spec status `done`
