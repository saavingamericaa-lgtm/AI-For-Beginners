#!/usr/bin/env bash
# Catches the two things that have actually caused trouble in this repo:
#   1. A folder name repeating inside its own path (Lil.Jarvis/Lil.Jarvis,
#      memory/memory, etc.) - the exact signature of every recursive-copy
#      incident so far (see memory/log.md, 2026-07-14 and 2026-07-16).
#   2. Filenames with characters/names that break on Windows (see the
#      SOUL.md filename rule - a colon in a filename broke every Windows
#      clone on 2026-07-15).
# Implemented as a single awk pass so it stays fast on large repos
# (the original bash-loop version timed out on a 13k-file repo).
set -euo pipefail

# -z: NUL-separated raw paths, so git never quote-escapes non-ASCII
# names (quoting made legal chars like the middle dot in "DALL·E ..."
# false-positive as illegal quote characters).
git ls-tree -r HEAD --name-only -z | awk '
BEGIN { RS = "\0"; fail = 0 }
{
  path = $0
  n = split(path, parts, "/")

  # Check 1: repeated folder name within the same path (case-insensitive).
  delete seen
  for (i = 1; i < n; i++) {
    lower = tolower(parts[i])
    if (lower in seen) {
      printf "::error::Repeated folder name %s in path: %s\n", parts[i], path
      fail = 1
      break
    }
    seen[lower] = 1
  }

  # Check 2: Windows-unsafe names.
  if (path ~ /[:<>"|?*]/) {
    printf "::error::Windows-illegal character in path: %s\n", path
    fail = 1
  }
  for (i = 1; i <= n; i++) {
    if (parts[i] ~ /[ .]$/) {
      printf "::error::Path component ends with space or period: %s\n", path
      fail = 1
    }
    base = parts[i]
    sub(/\..*$/, "", base)
    upper = toupper(base)
    if (upper ~ /^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/) {
      printf "::error::Windows reserved name in path: %s\n", path
      fail = 1
    }
  }
}
END {
  if (fail) { print ""; print "FAILED - see errors above."; exit 1 }
  print "All checks passed."
}
'
