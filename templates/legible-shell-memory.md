---
name: legible-shell-doctrine
description: Every Bash call must be statically legible to the permission matcher — the rules and their replacements
metadata:
  type: feedback
---

Every Bash call must be statically legible to the permission matcher: allowlisted first token, literal arguments, one statement per call.

- No `cd` when the command targets the current directory — just run it directly (cwd persists across calls). Reach for absolute paths or `-C` flags (`git -C`, `go -C`, `make -C`) only when a command must target a *different* directory.
- No `git -C <dir>` when `<dir>` is already the current directory (or `.`) — drop the flag and run the git command directly.
- No env-var prefixes (`FOO=1 cmd`) — for a one-off, spell it `env FOO=1 cmd` (fully literal, passes the hook); recurring setups belong in a script or a project task-runner recipe.
- No `$(...)` / `$VAR` — resolve the value once, paste the literal.
- No `& / sleep / tail` polling — use the Bash tool's background mode.
- Read-only per-file iteration — pipes are legible: `find . -name <glob> | xargs <cmd>`.
- Complex multi-statement shell — write a script to the session scratchpad, run `bash <script>`.
- Temp files — always the session scratchpad, never `/tmp`.

**Why:** illegible commands force manual permission prompts and break autonomous flow; the spec-loop plugin's PreToolUse hook rejects violations outright.

**How to apply:** compose every command to pass on the first try instead of learning from hook rejections; when a command wants environment setup or sequencing, reach for a scratchpad script immediately.
