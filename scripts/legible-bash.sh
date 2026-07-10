#!/usr/bin/env bash
# legible-bash.sh — PreToolUse guard for the Bash tool.
#
# Doctrine: every Bash call must be statically legible to the permission matcher —
# allowlisted first token, literal arguments, one statement per call. Illegible calls
# force manual permission prompts and break autonomous flow; this hook rejects them
# with the fix, so the model course-corrects instead of prompting the user.
#
# Exit codes (PreToolUse protocol): 0 = allow; 2 = block, stderr goes back to the model;
# 1 = allow, stderr shown to the user (warn mode).
#
# Modes via the LEGIBLE_BASH env var (set it in settings.json "env" to change):
#   block (default) — reject violations
#   warn            — report but allow
#   off             — disabled
#
# JSON parsing: jq if present, else python3, else fail open — never break Bash for
# want of a parser.

mode="${LEGIBLE_BASH:-block}"
if [ "$mode" = "off" ]; then exit 0; fi

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
else
  exit 0
fi
if [ -z "$cmd" ]; then exit 0; fi

# Judge shell *structure*, not string contents:
# 1. truncate at a heredoc opener (its body is data, not shell),
# 2. join backslash-continued lines,
# 3. strip single- and double-quoted spans.
judged="$(printf '%s\n' "$cmd" \
  | awk '/<<-?["'"'"']?[A-Za-z_]/ { print; exit } { print }' \
  | awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }' \
  | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g')"

msgs=""
hit() { msgs="${msgs}  - ${1}
"; }

if printf '%s\n' "$judged" | grep -Eq ';|&&|\|\|'; then
  hit "compound statement (';', '&&', '||'): one statement per Bash call — make separate calls"
fi
if [ "$(printf '%s\n' "$judged" | grep -c .)" -gt 1 ]; then
  hit "multi-line script: write it to the session scratchpad and run it as 'bash <path>'"
fi
if printf '%s\n' "$judged" | grep -Eq '^[[:space:]]*cd([[:space:]]|$)'; then
  hit "'cd': use absolute paths or -C flags instead (git -C, go -C, make -C)"
fi
if printf '%s\n' "$judged" | grep -Eq '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*='; then
  hit "env-var prefix (FOO=1 cmd): move it into a script or a project task-runner recipe"
fi
if printf '%s\n' "$judged" | grep -Fq '$(' || printf '%s\n' "$judged" | grep -q '`'; then
  hit "command substitution (\$(...) or backticks): resolve the value first, paste the literal"
fi
if printf '%s\n' "$judged" | grep -Eq '\$[A-Za-z_{]'; then
  hit "variable expansion (\$VAR): paste the literal value"
fi
if printf '%s\n' "$judged" | grep -Eq '^[[:space:]]*sleep([[:space:]]|$)'; then
  hit "'sleep' polling: use run_in_background and let the harness notify you"
fi
if printf '%s\n' "$judged" | grep -Eq '(^|[^&])&[[:space:]]*$'; then
  hit "trailing '&': use the Bash tool's run_in_background parameter instead"
fi

if [ -z "$msgs" ]; then exit 0; fi

{
  echo "legible-bash: rejected — every Bash call must be statically legible to the permission matcher."
  printf '%s' "$msgs"
  echo "Rewrite and retry. For genuinely complex shell, write a script into the session scratchpad and run: bash <script>."
  echo "(Set LEGIBLE_BASH=warn or =off in settings env to relax this guard.)"
} >&2

if [ "$mode" = "warn" ]; then exit 1; fi
exit 2
