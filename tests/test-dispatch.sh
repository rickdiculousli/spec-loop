#!/usr/bin/env bash
# spec.sh brief/diff: extract a task's text and capture a review-package diff into
# .spec-loop/<slug>/, a working-tree dir that must stay invisible to git status.
set -euo pipefail

SPEC="$(cd "$(dirname "$0")/.." && pwd)/scripts/spec.sh"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

git init -q -b main "$SANDBOX/work"
cd "$SANDBOX/work"
git config user.email test@example.com
git config user.name test
echo hi > README.md
git add README.md
git commit -qm init

bash "$SPEC" new demo >/dev/null
printf -- '---\ntitle: Demo\nstatus: proposed\npriority: P2\neffort: S\ncreated: 2026-07-10\ndepends_on: "-"\nsequencing: standalone\n---\n\n## Why\ntest\n' > specs/demo/proposal.md
printf -- '# Tasks — demo\n\n- [ ] Task one: add hello.py.\n  Validate: `test -f hello.py`\n- [ ] Task two: add goodbye.py.\n  Validate: `test -f goodbye.py`\n- [ ] Mark spec status `done`\n' > specs/demo/tasks.md
bash "$SPEC" save demo >/dev/null

# brief: extracts the right task, including its continuation line
out="$(bash "$SPEC" brief demo 1 | awk '{print $NF}')"
grep -q "Task one: add hello.py" "$out" || fail "brief 1 missing task-one text"
grep -q 'Validate.*test -f hello.py' "$out" || fail "brief 1 missing its continuation line"
grep -q "Task two" "$out" && fail "brief 1 leaked task two's text"
echo "ok: brief 1 extracts exactly task one"

out2="$(bash "$SPEC" brief demo 2 | awk '{print $NF}')"
grep -q "Task two: add goodbye.py" "$out2" || fail "brief 2 missing task-two text"
grep -q "Task one" "$out2" && fail "brief 2 leaked task one's text"
echo "ok: brief 2 extracts exactly task two"

out3="$(bash "$SPEC" brief demo 3 | awk '{print $NF}')"
grep -q 'Mark spec status' "$out3" || fail "brief 3 missing the closing task"
echo "ok: brief 3 extracts the closing task"

# brief: out-of-range and non-numeric both die with a clear message
if bash "$SPEC" brief demo 99 2>err.txt; then fail "brief accepted an out-of-range task number"; fi
grep -q "task 99 not found" err.txt || fail "wrong error for out-of-range: $(cat err.txt)"
echo "ok: out-of-range task number rejected"

if bash "$SPEC" brief demo abc 2>err.txt; then fail "brief accepted a non-numeric task number"; fi
grep -q "must be a positive integer" err.txt || fail "wrong error for non-numeric: $(cat err.txt)"
echo "ok: non-numeric task number rejected"

# diff: commit list, stat, and diff all present; base/head validated
base="$(git rev-parse HEAD)"
echo "print('hi')" > hello.py
git add hello.py
git commit -qm "task 1: add hello.py"
head="$(git rev-parse HEAD)"

diffout="$(bash "$SPEC" diff demo "$base" "$head" | awk '{print $3}')"
grep -q "^## Commits" "$diffout" || fail "diff package missing Commits section"
grep -q "^## Files changed" "$diffout" || fail "diff package missing Files changed section"
grep -q "^## Diff" "$diffout" || fail "diff package missing Diff section"
grep -q "add hello.py" "$diffout" || fail "diff package missing the commit subject"
grep -q "print('hi')" "$diffout" || fail "diff package missing the actual diff content"
echo "ok: diff package has commit list, stat, and full diff"

if bash "$SPEC" diff demo bogus-ref "$head" 2>err.txt; then fail "diff accepted a bad BASE"; fi
grep -q "bad BASE" err.txt || fail "wrong error for bad BASE: $(cat err.txt)"
echo "ok: bad BASE rejected"

# self-ignore: .spec-loop/ (including its own .gitignore) must be invisible to git status
rm -f err.txt
if [ -n "$(git status --porcelain)" ]; then
  fail ".spec-loop/ leaked into git status: $(git status --porcelain)"
fi
echo "ok: .spec-loop/ is invisible to git status"

echo "PASS: test-dispatch"
