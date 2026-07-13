#!/usr/bin/env bash
# SPEC_LOOP_SPECS knob: unset/git is unchanged default behavior, local keeps the whole
# specs/ directory git-ignored and uncommitted across new/save/start/done; untrack/track
# flip a spec (or, with --all, everything under specs/) between git-tracked and
# local-only, one commit each.
set -euo pipefail

SPEC="$(cd "$(dirname "$0")/.." && pwd)/scripts/spec.sh"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- sandbox 1: SPEC_LOOP_SPECS=local, exercised through new/save/start/done/list ---

git init -q -b main "$SANDBOX/work1"
cd "$SANDBOX/work1"
git config user.email test@example.com
git config user.name test
echo hi > README.md
git add README.md
git commit -qm init

# a. new under local mode: clean tree, blanket .gitignore created at specs/ root
SPEC_LOOP_SPECS=local bash "$SPEC" new demo >/dev/null
[ -z "$(git status --porcelain)" ] || fail "new under local left the tree dirty: $(git status --porcelain)"
[ -f specs/.gitignore ] || fail "new under local did not write specs/.gitignore"
grep -qxF '*' specs/.gitignore || fail "specs/.gitignore does not contain '*'"
echo "ok: new under local stays untracked and writes a blanket self-ignoring specs/.gitignore"

# b. save under local mode: no commit, explicit stays-local message
printf -- '---\ntitle: Demo\nstatus: proposed\npriority: P2\neffort: S\ncreated: 2026-07-10\ndepends_on: "-"\nsequencing: standalone\n---\n\n## Why\ntest\n' > specs/demo/proposal.md
printf -- '# Tasks — demo\n\n- [ ] Mark spec status `done`\n' > specs/demo/tasks.md
count_before="$(git rev-list --count HEAD)"
out="$(SPEC_LOOP_SPECS=local bash "$SPEC" save demo)"
count_after="$(git rev-list --count HEAD)"
[ "$count_before" = "$count_after" ] || fail "save under local created a commit"
echo "$out" | grep -qF "SPEC_LOOP_SPECS=local — specs/demo stays local, nothing committed" || fail "save under local: wrong message: $out"
echo "ok: save under local commits nothing and says so"

# c. start under local mode: no commit, status flips to in-progress on disk
git checkout -q main
count_before="$(git rev-list --count HEAD)"
SPEC_LOOP_SPECS=local bash "$SPEC" start demo >/dev/null
count_after="$(git rev-list --count HEAD)"
[ "$count_before" = "$count_after" ] || fail "start under local created a commit"
grep -q "status: in-progress" specs/demo/proposal.md || fail "start under local did not flip status to in-progress"
echo "ok: start under local flips status locally without committing"

# d. done under local mode: no commit, status flips to done on disk
count_before="$(git rev-list --count HEAD)"
SPEC_LOOP_SPECS=local bash "$SPEC" done demo >/dev/null
count_after="$(git rev-list --count HEAD)"
[ "$count_before" = "$count_after" ] || fail "done under local created a commit"
grep -q "status: done" specs/demo/proposal.md || fail "done under local did not flip status to done"
echo "ok: done under local flips status locally without committing"

# e. bogus SPEC_LOOP_SPECS value dies up front, on any subcommand
if SPEC_LOOP_SPECS=bogus bash "$SPEC" list 2>err.txt; then
  fail "bogus SPEC_LOOP_SPECS accepted"
fi
grep -q "SPEC_LOOP_SPECS must be" err.txt || fail "wrong error for bogus value: $(cat err.txt)"
echo "ok: bogus SPEC_LOOP_SPECS value rejected with a clear message"

# --- sandbox 2: default git mode, exercising untrack/track on a single already-committed spec ---

git init -q -b main "$SANDBOX/work2"
cd "$SANDBOX/work2"
git config user.email test@example.com
git config user.name test
echo hi > README.md
git add README.md
git commit -qm init

bash "$SPEC" new t2 >/dev/null
printf -- '---\ntitle: T2\nstatus: proposed\npriority: P2\neffort: S\ncreated: 2026-07-10\ndepends_on: "-"\nsequencing: standalone\n---\n\n## Why\ntest\n' > specs/t2/proposal.md
printf -- '# Tasks — t2\n\n- [ ] Mark spec status `done`\n' > specs/t2/tasks.md
bash "$SPEC" save t2 >/dev/null

# f. untrack <slug> removes specs/t2 from git's index, commits the removal, blanket-ignores specs/
count_before="$(git rev-list --count HEAD)"
bash "$SPEC" untrack t2 >/dev/null
count_after="$(git rev-list --count HEAD)"
[ "$count_after" = "$((count_before + 1))" ] || fail "untrack did not create exactly one commit"
untrack_sha="$(git rev-parse HEAD)"
untrack_msg="$(git log -1 --format=%s)"
[ -z "$(git ls-files specs/t2)" ] || fail "untrack left specs/t2 tracked: $(git ls-files specs/t2)"
echo "$untrack_msg" | grep -qF "untrack" || fail "untrack commit message missing 'untrack': $untrack_msg"
[ -f specs/.gitignore ] || fail "untrack did not write specs/.gitignore"
echo "more" >> specs/t2/tasks.md
[ -z "$(git status --porcelain)" ] || fail "editing tasks.md after untrack showed up in git status: $(git status --porcelain)"
echo "ok: untrack <slug> drops specs/t2 from the index, commits it, and blanket-ignores specs/"

# g. track <slug> re-adds specs/t2 to git's index and commits it, in a distinct commit
count_before="$(git rev-list --count HEAD)"
bash "$SPEC" track t2 >/dev/null
count_after="$(git rev-list --count HEAD)"
[ "$count_after" = "$((count_before + 1))" ] || fail "track did not create exactly one commit"
track_sha="$(git rev-parse HEAD)"
track_msg="$(git log -1 --format=%s)"
[ -n "$(git ls-files specs/t2)" ] || fail "track left specs/t2 untracked"
[ "$track_sha" != "$untrack_sha" ] || fail "track commit is the same as the untrack commit"
echo "$track_msg" | grep -qF "track" || fail "track commit message missing 'track': $track_msg"
[ "$track_msg" != "$untrack_msg" ] || fail "track commit message is identical to the untrack commit message"
echo "ok: track <slug> re-adds specs/t2 to the index and commits it in a distinct commit"

# --- sandbox 3: --all sweeps the WHOLE specs/ directory (root files + every spec folder) ---

git init -q -b main "$SANDBOX/work3"
cd "$SANDBOX/work3"
git config user.email test@example.com
git config user.name test
echo hi > README.md
git add README.md
git commit -qm init

mkdir -p specs
echo "# Specs" > specs/README.md
git add specs/README.md
git commit -qm "add specs readme"

bash "$SPEC" new s1 >/dev/null
printf -- '---\ntitle: S1\nstatus: proposed\npriority: P2\neffort: S\ncreated: 2026-07-10\ndepends_on: "-"\nsequencing: standalone\n---\n\n## Why\ntest\n' > specs/s1/proposal.md
printf -- '# Tasks — s1\n\n- [ ] Mark spec status `done`\n' > specs/s1/tasks.md
bash "$SPEC" save s1 >/dev/null
git checkout -q main
git merge -q --no-ff s1 -m "merge s1"

bash "$SPEC" new s2 >/dev/null
printf -- '---\ntitle: S2\nstatus: proposed\npriority: P2\neffort: S\ncreated: 2026-07-10\ndepends_on: "-"\nsequencing: standalone\n---\n\n## Why\ntest\n' > specs/s2/proposal.md
printf -- '# Tasks — s2\n\n- [ ] Mark spec status `done`\n' > specs/s2/tasks.md
bash "$SPEC" save s2 >/dev/null
git checkout -q main
git merge -q --no-ff s2 -m "merge s2"

# h. untrack --all sweeps specs/README.md + every spec folder in one commit
count_before="$(git rev-list --count HEAD)"
bash "$SPEC" untrack --all >/dev/null
count_after="$(git rev-list --count HEAD)"
[ "$count_after" = "$((count_before + 1))" ] || fail "untrack --all did not create exactly one commit"
[ -z "$(git ls-files specs)" ] || fail "untrack --all left tracked files under specs/: $(git ls-files specs)"
[ -f specs/.gitignore ] || fail "untrack --all did not write specs/.gitignore"
echo "ok: untrack --all removes specs/README.md and every spec folder from git in one commit"

# i. the whole tree — existing files, edits, and brand-new dirs — is now invisible to git status
echo "more" >> specs/s1/tasks.md
echo "new content" > specs/README.md
mkdir -p specs/s3
echo "brand new spec dir" > specs/s3/scratch.txt
[ -z "$(git status --porcelain)" ] || fail "specs/ still shows up in git status after untrack --all: $(git status --porcelain)"
echo "ok: entire specs/ tree (existing content, edits, and new dirs) invisible to git status after untrack --all"
rm -rf specs/s3

# j. a brand-new spec under default git mode still commits via -f, despite the blanket ignore
bash "$SPEC" new s4 >/dev/null
printf -- '---\ntitle: S4\nstatus: proposed\npriority: P2\neffort: S\ncreated: 2026-07-10\ndepends_on: "-"\nsequencing: standalone\n---\n\n## Why\ntest\n' > specs/s4/proposal.md
printf -- '# Tasks — s4\n\n- [ ] Mark spec status `done`\n' > specs/s4/tasks.md
bash "$SPEC" save s4 >/dev/null
git checkout -q main
git merge -q --no-ff s4 -m "merge s4"
[ -n "$(git ls-files specs/s4)" ] || fail "save under default git mode did not track specs/s4 despite a blanket specs/.gitignore"
echo "ok: save under default git mode still tracks a new spec via -f, even with a blanket specs/.gitignore present"

# k. track --all re-tracks everything under specs/ in one commit
count_before="$(git rev-list --count HEAD)"
bash "$SPEC" track --all >/dev/null
count_after="$(git rev-list --count HEAD)"
[ "$count_after" = "$((count_before + 1))" ] || fail "track --all did not create exactly one commit"
[ -n "$(git ls-files specs/README.md)" ] || fail "track --all did not re-track specs/README.md"
[ -n "$(git ls-files specs/s1)" ] || fail "track --all did not re-track specs/s1"
[ -n "$(git ls-files specs/s2)" ] || fail "track --all did not re-track specs/s2"
echo "ok: track --all re-tracks specs/README.md and every spec folder in one commit"

echo "PASS: test-local-specs"
