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
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
  cwd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)"
else
  echo "legible-bash: no jq or python3 found — allowing Bash call unchecked (install jq or python3 to restore the guard)" >&2
  exit 0
fi
if [ -z "$cmd" ]; then exit 0; fi

# Judge shell *structure*, not string contents:
# 1. truncate at a heredoc opener (its body is data, not shell),
# 2. join backslash-continued lines,
# 3. strip quoted spans before the structural checks (compound statement, cd,
#    env-var prefix, sleep, trailing '&') — both quote types are inert literal
#    data there, so stripping both avoids false positives like grep "a && b".
# For the expansion checks (command substitution, variable expansion) only
# single-quoted spans are stripped: unlike single quotes, double quotes do NOT
# block '$' expansion in bash — "$(cmd)" and "$VAR" really do expand — so a
# double-quoted span must stay visible for those two checks or the hook goes
# blind to substitutions hidden inside double quotes.
preprocessed="$(printf '%s\n' "$cmd" \
  | awk '/<<-?["'"'"']?[A-Za-z_]/ { print; exit } { print }' \
  | awk '{ if (sub(/\\$/, "")) printf "%s", $0; else print }')"
judged="$(printf '%s\n' "$preprocessed" | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g')"
judged_dq="$(printf '%s\n' "$preprocessed" | sed -e "s/'[^']*'//g")"

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
  hit "'cd': cwd persists across calls — just run the command directly. Only reach for -C/absolute paths (git -C, go -C, make -C) when you already know the target is a genuinely *different* directory — don't pre-emptively add -C to guard against a rejection"
fi
cdirc_match="$(printf '%s\n' "$preprocessed" | grep -oE '(^|[^A-Za-z0-9_.-])(git|go|make)[[:space:]]+-C[[:space:]]*("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)' | head -n1)"
if [ -n "$cdirc_match" ]; then
  cdirc_tool="$(printf '%s' "$cdirc_match" | sed -E 's/^[^A-Za-z]*//; s/[[:space:]].*$//')"
  cdirc_path="$(printf '%s' "$cdirc_match" | sed -E 's/^.*-C[[:space:]]*//')"
  cdirc_path="$(printf '%s' "$cdirc_path" | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')"
  cdirc_norm="${cdirc_path%/}"
  cwd_norm="${cwd%/}"
  if [ "$cdirc_path" = "." ] || { [ -n "$cwd" ] && [ "$cdirc_norm" = "$cwd_norm" ]; }; then
    hit "'${cdirc_tool} -C ${cdirc_path}': already the current directory — drop the '-C ${cdirc_path}' and run '${cdirc_tool}' directly"
  fi
fi
if printf '%s\n' "$judged" | grep -Eq '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*='; then
  hit "env-var prefix (FOO=1 cmd): for a one-off, spell it 'env FOO=1 cmd' (fully literal, passes this hook); recurring setups belong in a script or a project task-runner recipe"
fi
if printf '%s\n' "$judged_dq" | grep -Fq '$(' || printf '%s\n' "$judged_dq" | grep -q '`'; then
  hit "command substitution (\$(...) or backticks): resolve the value first, paste the literal"
fi
if printf '%s\n' "$judged_dq" | grep -Eq '\$[A-Za-z_{]'; then
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
  echo "Rewrite and retry. For read-only per-file iteration, pipes are legible: find . -name <glob> | xargs <cmd>. For genuinely complex shell, write a script into the session scratchpad and run: bash <script>."
  echo "(Set LEGIBLE_BASH=warn or =off in settings env to relax this guard.)"
} >&2

if [ "$mode" = "warn" ]; then exit 1; fi
exit 2
