#!/usr/bin/env bash
# PostToolUse hook for Edit and Write. After a Lua file changes, it runs the checks CI
# runs: luacheck over the project, then the tests. Problems go to stderr with exit code
# 2, which Claude reads as feedback on its edit. A tool that is not installed is skipped.
input=$(cat)
printf '%s' "$input" | grep -qE '"file_path": ?"[^"]*\.lua"' || exit 0
cd "$CLAUDE_PROJECT_DIR" || exit 0

problems=""
if command -v luacheck >/dev/null; then
	if ! out=$(luacheck -q --formatter plain . 2>&1); then
		problems+="luacheck:"$'\n'"$out"$'\n'
	fi
fi

lua=$(command -v lua5.1 || command -v luajit)
if [ -n "$lua" ]; then
	if ! out=$("$lua" tests/run.lua 2>&1); then
		problems+="tests/run.lua:"$'\n'"$(printf '%s\n' "$out" | grep -v '^  ok ')"$'\n'
	fi
fi

[ -z "$problems" ] && exit 0
printf '%s' "$problems" >&2
exit 2
