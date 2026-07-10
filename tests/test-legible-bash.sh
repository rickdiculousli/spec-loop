#!/usr/bin/env bash
# legible-bash hook: exit 0 = allow, 2 = block (stderr to model), 1 = warn (allow,
# stderr to user). Payloads are the PreToolUse JSON the harness pipes to the hook.
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/scripts/legible-bash.sh"

# check <want-exit> <mode> <json-escaped command> <label>
check() {
  local want="$1" mode="$2" jcmd="$3" label="$4" got=0
  printf '{"tool_input":{"command":"%s"}}' "$jcmd" \
    | LEGIBLE_BASH="$mode" bash "$HOOK" >/dev/null 2>&1 || got=$?
  if [ "$got" != "$want" ]; then
    echo "FAIL: $label — want exit $want, got $got" >&2
    exit 1
  fi
  echo "ok: $label"
}

# blocked structures
check 2 block 'make && make test'          "compound statement blocked"
check 2 block 'cd /x'                      "cd blocked"
check 2 block 'FOO=1 make'                 "env-var prefix blocked"
check 2 block 'echo $(date)'               "command substitution blocked"
check 2 block 'echo $HOME'                 "variable expansion blocked"
check 2 block 'sleep 5'                    "sleep blocked"
check 2 block 'make serve &'               "trailing ampersand blocked"
check 2 block 'echo one\necho two'         "multi-line script blocked"

# legible calls pass
check 0 block 'git -C /repo status'        "plain single statement allowed"
check 0 block 'grep \"a && b\" file.txt'   "operators inside quotes ignored"
check 0 block 'bash /path/to/script.sh'    "scratchpad-script pattern allowed"

# modes
check 1 warn  'cd /x'                      "warn mode reports but allows (exit 1)"
check 0 off   'cd /x && make'              "off mode disables the guard"

# malformed / empty input fails open
got=0
printf '{}' | LEGIBLE_BASH=block bash "$HOOK" >/dev/null 2>&1 || got=$?
if [ "$got" != "0" ]; then
  echo "FAIL: empty tool_input should fail open — got exit $got" >&2
  exit 1
fi
echo "ok: empty payload fails open"

echo "PASS: test-legible-bash"
