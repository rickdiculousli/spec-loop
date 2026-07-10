#!/usr/bin/env bash
# Run every tests/test-*.sh; exit nonzero if any fails.
set -uo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
failed=0
for t in "$dir"/test-*.sh; do
  echo "=== $(basename "$t")"
  if ! bash "$t"; then
    failed=$((failed + 1))
  fi
  echo
done

if [ "$failed" -gt 0 ]; then
  echo "tests: $failed test file(s) FAILED"
  exit 1
fi
echo "tests: all passed"
