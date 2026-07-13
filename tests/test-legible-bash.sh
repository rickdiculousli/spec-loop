#!/usr/bin/env bash
# legible-bash hook: exit 0 = allow, 2 = block (stderr to model), 1 = warn (allow,
# stderr to user). Payloads are the PreToolUse JSON the harness pipes to the hook.
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/scripts/legible-bash.sh"

# check <want-exit> <mode> <json-escaped command> <label> [cwd]
check() {
  local want="$1" mode="$2" jcmd="$3" label="$4" cwd="${5:-}" got=0
  printf '{"tool_input":{"command":"%s"},"cwd":"%s"}' "$jcmd" "$cwd" \
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
check 2 block 'git -C /repo status'        "git -C matching cwd blocked" '/repo'
check 2 block 'git -C /repo/ status'       "git -C matching cwd with trailing slash blocked" '/repo'
check 2 block 'git -C . status'            "git -C . blocked regardless of cwd" '/anywhere'
check 2 block 'FOO=1 make'                 "env-var prefix blocked"
check 2 block 'echo $(date)'               "command substitution blocked"
check 2 block 'echo $HOME'                 "variable expansion blocked"
check 2 block 'echo \"$(date)\"'           "command substitution inside double quotes blocked"
check 2 block 'echo \"$HOME\"'             "variable expansion inside double quotes blocked"
check 2 block 'sleep 5'                    "sleep blocked"
check 2 block 'make serve &'               "trailing ampersand blocked"
check 2 block 'echo one\necho two'         "multi-line script blocked"

# legible calls pass
check 0 block 'git status'                 "bare command in cwd allowed, no cd/-C needed"
check 0 block 'git -C /repo status'        "plain single statement allowed"
check 0 block 'git -C /repo status'        "git -C to a different dir than cwd allowed" '/home/user'
check 0 block 'git -C /repo/ status'       "git -C with trailing slash but different cwd allowed" '/home/user'
check 0 block 'grep \"a && b\" file.txt'   "operators inside quotes ignored"
check 0 block 'bash /path/to/script.sh'    "scratchpad-script pattern allowed"
check 0 block 'env FOO=1 make test'        "env-wrapped one-off allowed"
check 0 block 'find . -name *.txt | xargs wc -l' "find|xargs pipeline allowed"

# rejection stderr must teach the passing idioms it points to
got=0
out="$(printf '{"tool_input":{"command":"FOO=1 make test"}}' | LEGIBLE_BASH=block bash "$HOOK" 2>&1 1>/dev/null)" || got=$?
if [ "$got" != "2" ]; then
  echo "FAIL: idiom-teaching stderr — want exit 2, got $got" >&2
  exit 1
fi
if ! printf '%s' "$out" | grep -Fq 'env FOO=1'; then
  echo "FAIL: env-prefix rejection should teach the 'env FOO=1' spelling: $out" >&2
  exit 1
fi
echo "ok: env-prefix rejection teaches env FOO=1 spelling"
if ! printf '%s' "$out" | grep -Fq 'xargs'; then
  echo "FAIL: rejection footer should teach the xargs idiom: $out" >&2
  exit 1
fi
echo "ok: footer teaches xargs idiom"

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

# fail-open must be loud when neither jq nor python3 is on PATH: build a
# restricted PATH that excludes jq's and python3's real directories (computed
# via command -v, not hardcoded), then confirm the hook still allows the call
# (exit 0) but now warns on stderr, naming both tools.
# Resolve bash's own absolute path *before* restricting PATH: a leading
# `VAR=val bash ...` prefix still resolves the bare name "bash" by searching
# the (now-restricted) PATH, so if jq/python3 shared bash's directory, the
# re-invocation below would fail with 127 for reasons unrelated to this test.
# Invoking the interpreter by absolute path sidesteps that entirely.
bash_bin="$(command -v bash)"

jq_dir="" py_dir=""
jq_path="$(command -v jq 2>/dev/null || true)"
py_path="$(command -v python3 2>/dev/null || true)"
[ -n "$jq_path" ] && jq_dir="$(dirname "$jq_path")"
[ -n "$py_path" ] && py_dir="$(dirname "$py_path")"

restricted=""
IFS=':' read -r -a parts <<< "$PATH"
for p in "${parts[@]}"; do
  if [ "$p" != "$jq_dir" ] && [ "$p" != "$py_dir" ]; then
    restricted="${restricted:+$restricted:}$p"
  fi
done

got=0
out="$(printf '{"tool_input":{"command":"rm -rf /"}}' | PATH="$restricted" "$bash_bin" "$HOOK" 2>&1 1>/dev/null)" || got=$?
if [ "$got" != "0" ]; then
  echo "FAIL: fail-open-loud — want exit 0, got $got" >&2
  exit 1
fi
if ! printf '%s' "$out" | grep -q 'jq' || ! printf '%s' "$out" | grep -q 'python3'; then
  echo "FAIL: fail-open-loud — stderr did not mention both jq and python3: $out" >&2
  exit 1
fi
echo "ok: fail-open is loud when jq and python3 are both missing"

echo "PASS: test-legible-bash"
