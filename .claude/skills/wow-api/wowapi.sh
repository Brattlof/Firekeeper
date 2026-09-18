#!/usr/bin/env bash
# The references the wow-api skill searches, kept in a cache outside the repository so
# they are neither linted nor linked into the game:
#   - Blizzard's UI source for Forever: the forever branch of Gethe/wow-ui-source
#   - forever_api.json: a community capture of the globals the client exposes at
#     runtime, from Thunderz96/forever-addon-kit
#
#   wowapi.sh status        what is downloaded, against the installed client
#   wowapi.sh sync          download or update both
#   wowapi.sh lookup NAME   Function, C_Namespace.Function, EVENT_NAME or TemplateName
set -u

cache="${FIREKEEPER_CACHE:-$HOME/.cache/firekeeper}"
src="$cache/wow-ui-source"
ui="$src/Interface/AddOns"
docs="$ui/Blizzard_APIDocumentationGenerated"
capture="$cache/forever_api.json"
wow="${WOW_DIR:-C:/Program Files (x86)/World of Warcraft}"

installed_version() {
	awk -F'|' 'NR == 1 { for (i = 1; i <= NF; i++) { if ($i ~ /^Product!/) p = i; if ($i ~ /^Version!/) v = i } }
		NR > 1 && $p == "wow_classic_beta" { print $v; exit }' "$wow/.build.info" 2>/dev/null
}

status() {
	echo "Installed client:  $(installed_version || true)"
	if [ -f "$src/version.txt" ]; then
		echo "UI source:         $(cat "$src/version.txt")"
	else
		echo "UI source:         missing, run: wowapi.sh sync"
	fi
	if [ -f "$capture" ]; then
		echo "Runtime capture:   $(grep -oE '"client": \{[^}]*\}' "$capture")"
	else
		echo "Runtime capture:   missing, run: wowapi.sh sync"
	fi
}

sync() {
	set -e
	mkdir -p "$cache"
	if [ -d "$src/.git" ]; then
		git -C "$src" fetch -q --depth 1 origin forever
		git -C "$src" reset -q --hard FETCH_HEAD
	else
		git clone -q --depth 1 --branch forever https://github.com/Gethe/wow-ui-source "$src"
	fi
	curl -fsSL -o "$capture" https://raw.githubusercontent.com/Thunderz96/forever-addon-kit/HEAD/data/forever_api.json
	status
}

# Prints each documentation entry whose Name or LiteralName is exactly $1, from the
# line naming it to the end of that entry.
doc_entries() {
	local name=$1 namespace=$2 file ns
	for file in $(grep -lE "^[[:space:]]*(Name|LiteralName) = \"$name\",[[:space:]]*$" "$docs"/*.lua); do
		ns=$(grep -m1 -oE 'Namespace = "[^"]+"' "$file" | cut -d'"' -f2)
		if [ -n "$namespace" ] && [ "$ns" != "$namespace" ]; then
			continue
		fi
		echo "-- ${file##*/}${ns:+ (namespace $ns)}"
		awk -v name="$name" '
			!inside && $0 ~ "^[[:space:]]*(Name|LiteralName) = \"" name "\",[[:space:]]*$" { inside = 1; depth = 1 }
			inside {
				print
				depth += gsub(/\{/, "{") - gsub(/\}/, "}")
				if (depth <= 0) { inside = 0; print "" }
			}' "$file"
	done
}

in_capture() {
	local name=$1 namespace=$2
	if [ -n "$namespace" ]; then
		grep -oE "\"$namespace\": \[[^]]*\]" "$capture" | grep -q "\"$name\""
	else
		grep -oE '"(functions|frames)": \[[^]]*\]' "$capture" | grep -q "\"$name\""
	fi
}

lookup() {
	local query=${1:?usage: wowapi.sh lookup NAME} namespace="" name
	name=$query
	case $query in
		*.*) namespace=${query%%.*} name=${query#*.} ;;
	esac
	if [ ! -d "$docs" ] || [ ! -f "$capture" ]; then
		status
		exit 1
	fi

	echo "== Declared: Blizzard API documentation, build $(cat "$src/version.txt")"
	local entries
	entries=$(doc_entries "$name" "$namespace")
	echo "${entries:-not declared}"

	echo
	echo "== Present at runtime: capture of build $(grep -oE '"build": "[0-9]+"' "$capture" | cut -d'"' -f4)"
	local label="global $name"
	[ -n "$namespace" ] && label="$namespace.$name"
	if [[ $name =~ ^[A-Z0-9_]+$ ]]; then
		echo "not applicable: the capture records functions and frames, not events"
	elif in_capture "$name" "$namespace"; then
		echo "present: $label"
	else
		echo "not present: $label"
	fi

	echo
	echo "== Defined in Blizzard's XML (templates and named frames)"
	local defined
	defined=$(grep -rn --include=*.xml "name=\"$name\"" "$ui" | cut -c1-220 | sed "s|^$ui/||")
	echo "${defined:-not defined}"

	echo
	echo "== Used by Blizzard's UI code (first 15 of $(grep -rlw --include=*.lua --include=*.xml "$name" "$ui" | grep -vc APIDocumentationGenerated) files)"
	grep -rnw --include=*.lua --include=*.xml "$name" "$ui" | grep -v APIDocumentationGenerated | cut -c1-220 | sed "s|^$ui/||" | head -15
}

case ${1:-} in
	status) status ;;
	sync) sync ;;
	lookup) shift; lookup "$@" ;;
	*) sed -n '2,10p' "$0" >&2; exit 2 ;;
esac
