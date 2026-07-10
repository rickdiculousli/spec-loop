#!/usr/bin/env bash
# SPEC_LOOP_PUSH knob: auto (default) pushes when origin exists, off never pushes,
# anything else dies up front on every subcommand.
set -euo pipefail

SPEC="$(cd "$(dirname "$0")/.." && pwd)/scripts/spec.sh"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

git init --bare -q "$SANDBOX/origin.git"
git init -q -b main "$SANDBOX/work"
cd "$SANDBOX/work"
git config user.email test@example.com
git config user.name test
git remote add origin "$SANDBOX/origin.git"
echo hi > README.md
git add README.md
git commit -qm init
git push -qu origin main

bash "$SPEC" new demo >/dev/null
printf -- '---\ntitle: Demo\nstatus: proposed\npriority: P2\neffort: S\ncreated: 2026-07-10\ndepends_on: "-"\nsequencing: standalone\n---\n\n## Why\ntest\n' > specs/demo/proposal.md
printf -- '# Tasks — demo\n\n- [ ] Mark spec status `done`\n' > specs/demo/tasks.md

# save with off must not push
SPEC_LOOP_PUSH=off bash "$SPEC" save demo | grep -q "stays local" || fail "save under off: no stays-local notice"
[ -z "$(git ls-remote origin demo)" ] || fail "save under off pushed the branch"
echo "ok: save under off stays local"

# save under default (auto) must push
echo "## What" >> specs/demo/proposal.md
bash "$SPEC" save demo >/dev/null 2>&1
[ -n "$(git ls-remote origin demo)" ] || fail "save under auto did not push"
echo "ok: save under auto pushes"

# invalid value dies up front, on any subcommand
if SPEC_LOOP_PUSH=bogus bash "$SPEC" list 2>err.txt; then
  fail "bogus SPEC_LOOP_PUSH accepted"
fi
grep -q "SPEC_LOOP_PUSH must be" err.txt || fail "wrong error for bogus value: $(cat err.txt)"
echo "ok: bogus value rejected with a clear message"

# start with off flips status + commits locally, must not push
git checkout -q main
SPEC_LOOP_PUSH=off bash "$SPEC" start demo >/dev/null
local_tip="$(git rev-parse demo)"
remote_tip="$(git ls-remote origin demo | cut -f1)"
[ "$local_tip" != "$remote_tip" ] || fail "start under off pushed the in-progress commit"
grep -q "status: in-progress" specs/demo/proposal.md || fail "start did not flip status"
echo "ok: start under off keeps the in-progress commit local"

echo "PASS: test-push-knob"
