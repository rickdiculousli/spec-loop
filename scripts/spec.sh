#!/usr/bin/env bash
# spec.sh — spec lifecycle git choreography for the spec-loop plugin.
# Deterministic so the skills never re-derive git steps by hand. Requires bash + git, nothing else.
#
#   spec.sh new   <slug>    open branch <slug> off the default branch, create specs/<slug>/
#   spec.sh save  <slug>    commit specs/<slug> on its branch; push with upstream if a remote exists
#   spec.sh start <slug>    begin implementation: checkout branch <slug>, flip status to in-progress
#   spec.sh done  <slug>    flip status to done and commit (lands on the default branch via merge)
#   spec.sh list            render the portfolio table from proposal.md frontmatter
#   spec.sh check           validate frontmatter across all specs
#   spec.sh brief <slug> <N> [outfile]           extract task N from tasks.md, print the path
#   spec.sh diff  <slug> <base> <head> [outfile] commit list + stat + diff for a task/branch range, print the path
#
# Conventions: branch name == spec folder name == <slug>. The default branch is never
# written directly — specs reach it only by merging their branch (PR-friendly by design).
#
# brief/diff write into .spec-loop/<slug>/ — a self-ignoring working-tree scratch dir
# (untracked, no .gitignore edits needed in the host repo) used to hand subagents their
# task text and review diffs as files instead of pasting them through session context.
# It survives session restarts but is ordinary untracked scratch: `git clean -fdx` wipes
# it like anything else untracked; recover state from `git log` if that happens.
#
# Config via env (set in settings.json "env"):
#   SPEC_LOOP_PUSH=auto (default) — push spec branches to origin when it exists
#   SPEC_LOOP_PUSH=off            — never push; branches stay local until you push them

set -euo pipefail

cmd="${1:-}"

die() { echo "spec.sh: $*" >&2; exit 1; }

git rev-parse --show-toplevel >/dev/null 2>&1 || die "not inside a git repository"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

tree_clean() { git diff --quiet && git diff --cached --quiet; }
has_remote() { git remote get-url origin >/dev/null 2>&1; }

case "${SPEC_LOOP_PUSH:-auto}" in
  auto|off) ;;
  *) die "SPEC_LOOP_PUSH must be 'auto' or 'off' (got '${SPEC_LOOP_PUSH}')" ;;
esac
should_push() { [[ "${SPEC_LOOP_PUSH:-auto}" == "auto" ]] && has_remote; }

case "${SPEC_LOOP_SPECS:-git}" in
  git|local) ;;
  *) die "SPEC_LOOP_SPECS must be 'git' or 'local' (got '${SPEC_LOOP_SPECS}')" ;;
esac
is_local() { [[ "${SPEC_LOOP_SPECS:-git}" == "local" ]]; }
current_branch() { git rev-parse --abbrev-ref HEAD; }

default_branch() {
  local b
  b="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$b" ]]; then
    echo "${b#origin/}"
    return
  fi
  for b in main master; do
    if git show-ref --verify --quiet "refs/heads/$b"; then
      echo "$b"
      return
    fi
  done
  die "cannot determine the default branch (no origin/HEAD, no local main/master)"
}

resolve_slug() {
  SLUG="${1:?spec.sh: slug required}"
  if [[ ! "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    die "slug must be lowercase letters, digits, hyphens: '$SLUG'"
  fi
  SPEC_DIR="specs/$SLUG"
  PROPOSAL="$SPEC_DIR/proposal.md"
}

# Ensure the self-ignoring scratch dir for <slug> exists; print its path.
workspace_dir() {
  local dir=".spec-loop/$1"
  mkdir -p "$dir"
  if [[ ! -f ".spec-loop/.gitignore" ]]; then
    # Unnegated '*' hides the whole dir, including this file, from git status —
    # a negated '!.gitignore' would leave the .gitignore itself untracked and
    # drag the directory back in as untracked.
    printf '*\n' > ".spec-loop/.gitignore"
  fi
  echo "$dir"
}

# Write a self-ignoring .gitignore for specs/<slug>/ (SPEC_LOOP_SPECS=local mode), if absent.
ignore_spec_dir() {
  local dir="specs/$1"
  if [[ ! -f "$dir/.gitignore" ]]; then
    # Unnegated '*' hides the whole dir, including this file, from git status —
    # a negated '!.gitignore' would leave the .gitignore itself untracked and
    # drag the directory back in as untracked.
    printf '*\n' > "$dir/.gitignore"
  fi
}

# Extract task N (1-based, by position) from a flat tasks.md checkbox list: the Nth
# top-level "- [ ]"/"- [x]" line plus any indented continuation lines up to the next
# top-level checkbox. Assumes tasks.md's documented convention of a flat list with no
# nested checkboxes.
extract_task() { # $1=tasks.md $2=N
  awk -v n="$2" '
    /^- \[[ xX]\]/ { count++; intask = (count == n) }
    intask { print }
    count > n { exit }
  ' "$1"
}

# Read one frontmatter value: fm_get <file> <key> → value on stdout (empty if absent).
fm_get() {
  awk -v k="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      gsub(/^"|"$/, "", v)
      print v
      exit
    }
  ' "$1"
}

# Rewrite the status: line inside the frontmatter block only.
set_status() { # $1=proposal.md $2=new-status
  if [[ ! -f "$1" ]]; then die "missing $1"; fi
  if awk -v st="$2" '
    NR == 1 { infm = ($0 == "---"); print; next }
    infm && $0 == "---" { infm = 0; print; next }
    infm && $0 ~ /^status:/ { print "status: " st; changed = 1; next }
    { print }
    END { if (!changed) exit 3 }
  ' "$1" > "$1.tmp"; then
    mv "$1.tmp" "$1"
  else
    rm -f "$1.tmp"
    die "$1: no 'status:' line in frontmatter"
  fi
}

# Extract bullet lines ("- " or "-<tab>") under a '## Success criteria' heading in a
# proposal.md, stopping at the next '## ' heading or end of file. Prints one bullet per
# line (empty output if there's no such heading or it has no bullets).
success_criteria_bullets() { # $1=proposal.md
  awk '
    /^## Success criteria/ { insec=1; next }
    /^## / { insec=0 }
    insec && /^-[ \t]/ { print }
  ' "$1"
}

case "$cmd" in

  new)
    resolve_slug "${2:-}"
    if [[ -d "$SPEC_DIR" ]]; then die "$SPEC_DIR already exists"; fi
    if git show-ref --verify --quiet "refs/heads/$SLUG"; then die "branch '$SLUG' already exists locally"; fi
    tree_clean || die "working tree not clean — commit or stash first"
    DEFAULT="$(default_branch)"
    cur="$(current_branch)"
    if [[ "$cur" != "$DEFAULT" ]]; then
      die "run from '$DEFAULT' (currently on '$cur') so the spec branches off the latest default"
    fi
    if has_remote; then
      git pull --ff-only origin "$DEFAULT"
    fi
    git checkout -b "$SLUG"
    mkdir -p "$SPEC_DIR"
    if is_local; then
      ignore_spec_dir "$SLUG"
      echo "spec.sh: on branch '$SLUG' — write $SPEC_DIR/proposal.md + tasks.md, then run: spec.sh save $SLUG (SPEC_LOOP_SPECS=local — $SPEC_DIR is git-ignored and won't be committed)"
    else
      echo "spec.sh: on branch '$SLUG' — write $SPEC_DIR/proposal.md + tasks.md, then run: spec.sh save $SLUG"
    fi
    ;;

  save)
    resolve_slug "${2:-}"
    cur="$(current_branch)"
    if [[ "$cur" != "$SLUG" ]]; then die "save must run on branch '$SLUG' (currently on '$cur')"; fi
    if [[ ! -f "$PROPOSAL" ]]; then die "missing $PROPOSAL"; fi
    if [[ ! -f "$SPEC_DIR/tasks.md" ]]; then die "missing $SPEC_DIR/tasks.md"; fi
    if is_local; then
      echo "spec.sh: SPEC_LOOP_SPECS=local — specs/$SLUG stays local, nothing committed"
    else
      git add "$SPEC_DIR"
      if git diff --cached --quiet; then die "nothing to commit in $SPEC_DIR"; fi
      if [[ "$(git rev-list --count HEAD -- "$SPEC_DIR")" == "0" ]]; then
        git commit -m "spec($SLUG): proposed"
      else
        git commit -m "spec($SLUG): revise"
      fi
      if should_push; then
        git push -u origin "$SLUG"
      elif has_remote; then
        echo "spec.sh: SPEC_LOOP_PUSH=off — branch '$SLUG' stays local"
      else
        echo "spec.sh: no 'origin' remote — branch '$SLUG' stays local"
      fi
    fi
    ;;

  start)
    resolve_slug "${2:-}"
    tree_clean || die "working tree not clean — commit or stash first"
    if git show-ref --verify --quiet "refs/heads/$SLUG"; then
      git checkout "$SLUG"
    elif has_remote && git fetch origin "$SLUG" >/dev/null 2>&1; then
      git checkout -b "$SLUG" --track "origin/$SLUG"
    elif [[ -d "$SPEC_DIR" ]]; then
      if is_local; then
        echo "spec.sh: specs folder found locally; reopening its branch"
      fi
      git checkout -b "$SLUG"    # spec already merged to the default branch; reopen its branch
    else
      die "no branch or spec folder for '$SLUG' — run /brainstorm first"
    fi
    if [[ ! -f "$PROPOSAL" ]]; then die "missing $PROPOSAL on branch '$SLUG'"; fi
    st="$(fm_get "$PROPOSAL" status)"
    if [[ "$st" == "in-progress" ]]; then
      echo "spec.sh: '$SLUG' already in-progress — resuming on its branch"
      exit 0
    fi
    set_status "$PROPOSAL" "in-progress"
    if is_local; then
      : # SPEC_LOOP_SPECS=local — status flip stays uncommitted
    else
      git add "$PROPOSAL"
      git commit -m "spec($SLUG): in-progress"
      if should_push; then
        git push -u origin "$SLUG" || echo "spec.sh: push failed — push branch '$SLUG' manually later" >&2
      fi
    fi
    echo "spec.sh: on branch '$SLUG' — all work (incl. spec deviations) stays here until merge"
    ;;

  done)
    resolve_slug "${2:-}"
    cur="$(current_branch)"
    if [[ "$cur" != "$SLUG" ]]; then die "done must run on branch '$SLUG' (currently on '$cur')"; fi
    set_status "$PROPOSAL" "done"
    if is_local; then
      : # SPEC_LOOP_SPECS=local — status flip stays uncommitted
    else
      git add "$PROPOSAL"
      git commit -m "spec($SLUG): done"
    fi
    echo "spec.sh: '$SLUG' marked done — open a PR / merge the branch to land it"
    ;;

  untrack)
    resolve_slug "${2:-}"
    cur="$(current_branch)"
    if [[ "$cur" != "$SLUG" ]]; then die "untrack must run on branch '$SLUG' (currently on '$cur')"; fi
    git ls-files --error-unmatch "$SPEC_DIR" >/dev/null 2>&1 || die "$SPEC_DIR is not git-tracked"
    git rm -r --cached "$SPEC_DIR" >/dev/null
    git commit -m "spec($SLUG): untrack — local only from here"
    ignore_spec_dir "$SLUG"
    echo "spec.sh: '$SLUG' untracked — specs/$SLUG stays local from here"
    ;;

  list)
    shopt -s nullglob
    files=(specs/*/proposal.md)
    if [[ ${#files[@]} -eq 0 ]]; then
      echo "spec.sh: no specs yet (specs/*/proposal.md)"
      exit 0
    fi
    {
      printf 'SPEC\tSTATUS\tPRI\tEFF\tTITLE\tDEPENDS ON\n'
      for f in "${files[@]}"; do
        d="${f%/proposal.md}"
        slug="${d#specs/}"
        st="$(fm_get "$f" status)"
        pri="$(fm_get "$f" priority)"
        eff="$(fm_get "$f" effort)"
        title="$(fm_get "$f" title)"
        dep="$(fm_get "$f" depends_on)"
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$slug" "${st:--}" "${pri:--}" "${eff:--}" "${title:--}" "${dep:--}"
      done
    } | awk -F'\t' '
      {
        for (i = 1; i <= NF; i++) {
          if (length($i) > w[i]) w[i] = length($i)
          cell[NR, i] = $i
        }
        nf = NF; nr = NR
      }
      END {
        for (r = 1; r <= nr; r++) {
          line = ""
          for (i = 1; i <= nf; i++) line = line sprintf("%-*s  ", w[i], cell[r, i])
          sub(/ +$/, "", line)
          print line
          if (r == 1) {
            line = ""
            for (i = 1; i <= nf; i++) {
              s = sprintf("%-*s", w[i], "")
              gsub(/ /, "-", s)
              line = line s "  "
            }
            sub(/ +$/, "", line)
            print line
          }
        }
      }'
    seq_shown=0
    for f in "${files[@]}"; do
      d="${f%/proposal.md}"
      slug="${d#specs/}"
      s="$(fm_get "$f" sequencing)"
      if [[ -n "$s" ]]; then
        if [[ $seq_shown -eq 0 ]]; then
          echo
          echo "Sequencing:"
          seq_shown=1
        fi
        printf '  %-24s %s\n' "$slug" "$s"
      fi
    done
    ;;

  check)
    shopt -s nullglob
    errors=0
    warnings=0
    fail() { echo "FAIL: $*" >&2; errors=$((errors + 1)); }
    warn() { echo "warn: $*" >&2; warnings=$((warnings + 1)); }

    count=0
    for d in specs/*/; do
      base="$(basename "$d")"
      if [[ ! "$base" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        warn "$base: folder name is not a lowercase slug (branch == folder convention needs one)"
      fi
      if [[ ! -f "$d/proposal.md" ]]; then
        fail "$base: missing proposal.md"
        continue
      fi
      if [[ ! -f "$d/tasks.md" ]]; then
        warn "$base: missing tasks.md"
      fi
      f="$d/proposal.md"
      count=$((count + 1))
      for k in title status priority effort; do
        if [[ -z "$(fm_get "$f" "$k")" ]]; then
          fail "$base: missing frontmatter '$k'"
        fi
      done
      st="$(fm_get "$f" status)"
      case "$st" in
        proposed|in-progress|done|iceboxed|"") ;;
        *) fail "$base: status '$st' not in proposed|in-progress|done|iceboxed" ;;
      esac
      dep="$(fm_get "$f" depends_on)"
      if [[ -n "$dep" && "$dep" != "-" && "$dep" != "—" && "$dep" != "none" ]]; then
        cleaned="$(printf '%s' "$dep" | sed 's/([^)]*)//g')"
        IFS=',' read -ra toks <<< "$cleaned"
        for t in "${toks[@]}"; do
          t="$(printf '%s' "$t" | tr -d '[:space:]')"
          if [[ -z "$t" ]]; then continue; fi
          if [[ "$t" =~ ^[a-z0-9][a-z0-9-]*$ && ! -d "specs/$t" ]]; then
            warn "$base: depends_on '$t' has no spec folder here (merged under another name, or a typo?)"
          fi
        done
      fi

      # Coverage-gate heuristic (warn-only, never fails): for each Success-criteria
      # bullet, flag it if none of its significant words (>=4 chars, stop-words
      # excluded) appear anywhere in this spec's tasks.md.
      if [[ -f "$d/tasks.md" ]]; then
        tasks_lc="$(tr '[:upper:]' '[:lower:]' < "$d/tasks.md")"
        while IFS= read -r bullet; do
          [[ -z "$bullet" ]] && continue
          clean="$(printf '%s' "$bullet" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:] ' ' ')"
          sig=()
          for w in $clean; do
            if [[ ${#w} -lt 4 ]]; then continue; fi
            case "$w" in
              this|that|with|from|must|have|been|every|when|where|their|there|while|about|which|would|could|should) continue ;;
            esac
            sig+=("$w")
          done
          if [[ ${#sig[@]} -eq 0 ]]; then continue; fi
          covered=0
          for w in "${sig[@]}"; do
            if [[ "$tasks_lc" == *"$w"* ]]; then covered=1; break; fi
          done
          if [[ $covered -eq 0 ]]; then
            disp="$bullet"
            if [[ ${#disp} -gt 60 ]]; then disp="${disp:0:60}..."; fi
            warn "$base: Success-criteria bullet may not be covered by any task: \"$disp\""
          fi
        done < <(success_criteria_bullets "$f")
      fi
    done

    if [[ $errors -gt 0 ]]; then
      echo "spec.sh: $count specs, $errors error(s), $warnings warning(s)" >&2
      exit 1
    fi
    echo "spec.sh: $count specs OK ($warnings warning(s))"
    ;;

  brief)
    resolve_slug "${2:-}"
    n="${3:?spec.sh: task number required}"
    if [[ ! "$n" =~ ^[0-9]+$ ]]; then die "task number must be a positive integer: '$n'"; fi
    if [[ ! -f "$SPEC_DIR/tasks.md" ]]; then die "missing $SPEC_DIR/tasks.md"; fi
    ws="$(workspace_dir "$SLUG")"
    out="${4:-$ws/task-$n-brief.md}"
    extract_task "$SPEC_DIR/tasks.md" "$n" > "$out.tmp"
    if [[ ! -s "$out.tmp" ]]; then rm -f "$out.tmp"; die "task $n not found in $SPEC_DIR/tasks.md"; fi
    mv "$out.tmp" "$out"
    echo "spec.sh: wrote $out"
    ;;

  diff)
    resolve_slug "${2:-}"
    base="${3:?spec.sh: BASE required}"
    head="${4:?spec.sh: HEAD required}"
    git rev-parse --verify --quiet "$base" >/dev/null 2>&1 || die "bad BASE: $base"
    git rev-parse --verify --quiet "$head" >/dev/null 2>&1 || die "bad HEAD: $head"
    ws="$(workspace_dir "$SLUG")"
    out="${5:-$ws/review-$(git rev-parse --short "$base")..$(git rev-parse --short "$head").diff}"
    {
      echo "# Review package: $base..$head"
      echo
      echo "## Commits"
      git log --oneline "$base..$head"
      echo
      echo "## Files changed"
      git diff --stat "$base..$head"
      echo
      echo "## Diff"
      git diff -U10 "$base..$head"
    } > "$out"
    commits="$(git rev-list --count "$base..$head")"
    echo "spec.sh: wrote $out ($commits commit(s))"
    ;;

  *)
    die "usage: spec.sh {new|save|start|done|untrack|list|check|brief|diff} [args]"
    ;;
esac
