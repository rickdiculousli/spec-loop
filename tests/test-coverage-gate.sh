#!/usr/bin/env bash
# Coverage-gate heuristic in `spec.sh check`: warns (never fails) when a Success-criteria
# bullet's significant words are absent from tasks.md.
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
printf -- '---\ntitle: Demo\nstatus: proposed\npriority: P2\neffort: S\ncreated: 2026-07-10\ndepends_on: "-"\nsequencing: standalone\n---\n\n## Success criteria\n\n- The widget must render correctly in under 200ms\n' > specs/demo/proposal.md
printf -- '# Tasks — demo\n\n- [ ] Write documentation\n' > specs/demo/tasks.md

run_check() {
  if out="$(bash "$SPEC" check 2>&1)"; then
    status=0
  else
    status=$?
  fi
}

# (a) bullet's significant words absent from tasks.md -> warn, exit 0
run_check
echo "$out" | grep -q "may not be covered by any task" || fail "case a: expected coverage warning missing. Output: $out"
[ "$status" -eq 0 ] || fail "case a: check must exit 0 (warn-only), got $status"
echo "ok: uncovered success-criteria bullet warns, exit 0"

# (b) tasks.md now overlaps the bullet's significant words -> no coverage warning
printf -- '# Tasks — demo\n\n- [ ] Ensure component renders within a 200ms budget\n' > specs/demo/tasks.md
run_check
echo "$out" | grep -q "may not be covered by any task" && fail "case b: coverage warning fired despite overlap. Output: $out"
[ "$status" -eq 0 ] || fail "case b: check must exit 0, got $status"
echo "ok: covered success-criteria bullet does not warn"

# (c) no '## Success criteria' section at all -> no coverage warning
printf -- '---\ntitle: Demo\nstatus: proposed\npriority: P2\neffort: S\ncreated: 2026-07-10\ndepends_on: "-"\nsequencing: standalone\n---\n\n## Why\ntest\n' > specs/demo/proposal.md
run_check
echo "$out" | grep -q "may not be covered by any task" && fail "case c: coverage warning fired with no Success criteria section. Output: $out"
[ "$status" -eq 0 ] || fail "case c: check must exit 0, got $status"
echo "ok: no Success criteria section produces no coverage warning"

echo "PASS: test-coverage-gate"
