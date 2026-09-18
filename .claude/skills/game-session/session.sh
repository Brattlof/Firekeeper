#!/usr/bin/env bash
# Prints what the Forever client last wrote to disk for Firekeeper: whether the game is
# running, Firekeeper's saved variables, Lua errors captured by BugGrabber, and the
# taint log when it is enabled. The client writes all of these only on /reload,
# logout or quit.
set -u
shopt -s nullglob

client="${WOW_DIR:-C:/Program Files (x86)/World of Warcraft}/_classic_beta_"
here=$(dirname "$0")
now=$(date +%s)

written() {
	echo "written $(( (now - $(stat -c %Y "$1")) / 60 )) min ago"
}

if tasklist 2>/dev/null | grep -qi '^WowB\.exe'; then
	echo "Client: running"
else
	echo "Client: not running"
fi

for file in "$client"/WTF/Account/*/SavedVariables/Firekeeper.lua \
	"$client"/WTF/Account/*/*/*/SavedVariables/Firekeeper.lua; do
	echo
	echo "== ${file#"$client/"} ($(written "$file"))"
	head -n 80 "$file"
done

bugs=("$client"/WTF/Account/*/SavedVariables/!BugGrabber.lua)
echo
if [ ${#bugs[@]} -eq 0 ]; then
	echo "== Lua errors: BugGrabber is not installed, so errors are only shown on screen"
fi
lua=$(command -v lua5.1 || command -v luajit || true)
for file in "${bugs[@]}"; do
	echo "== Lua errors: ${file#"$client/"} ($(written "$file"))"
	if [ -n "$lua" ]; then
		"$lua" "$here/bugs.lua" "$file"
	else
		echo "No lua5.1 or luajit to parse it; search the file for Firekeeper instead."
	fi
done

taint="$client/Logs/taint.log"
if [ -f "$taint" ]; then
	echo
	echo "== Logs/taint.log ($(written "$taint")), last lines naming Firekeeper"
	grep -i firekeeper "$taint" | tail -n 20
fi
exit 0
