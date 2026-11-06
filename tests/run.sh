#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
format_tmp=$(mktemp -d)
trap 'rm -rf "$format_tmp"' EXIT HUP INT TERM
export XDG_STATE_HOME="$format_tmp/state"
export XDG_CACHE_HOME="$format_tmp/cache"
export NVIM_LOG_FILE="$format_tmp/nvim.log"
for test in tests/core.lua tests/adapters.lua tests/lsp.lua tests/real.lua; do
  if test -f "$test"; then
    "${NVIM:-nvim}" --headless -u tests/minimal_init.lua -i NONE -n -l "$test"
  fi
done
if test -f tests/tui.py; then python3 tests/tui.py; fi
