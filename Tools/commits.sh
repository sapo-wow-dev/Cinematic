#!/usr/bin/env bash
# Writes every commit's date and message, newest first and grouped by the
# release it went out in, as Lua for the What's new > All changes page.
#   Tools/commits.sh                       -> ChangelogCommits.dev.lua (the dev copy's, not packaged)
#   Tools/commits.sh ChangelogCommits.lua  -> the released file (the release workflow runs this)
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-ChangelogCommits.dev.lua}"

{
	echo "-- Made by Tools/commits.sh: every commit, newest first. Don't edit by hand."
	echo "local _, ns = ..."
	echo "ns.CHANGELOG_COMMITS = {"
	# Each release's commits: from the tag before it up to its tag (the newest
	# tag's are followed by any not released yet, as "next").
	prev=""
	ranges=()
	for tag in $(git tag --list 'v*' --sort=v:refname); do
		ranges+=("${prev:+$prev..}$tag ${tag#v}")
		prev="$tag"
	done
	ranges+=("${prev:+$prev..}HEAD next")
	# (A change released alone off the last tag, then merged into main, is in
	# main's history twice: the tag's commit and main's, the same change.
	# Listed once, under the release it went out in, the oldest: each line
	# keyed by its change (git patch-id), newest first, so the last is kept.)
	declare -A pid=()
	while read -r id commit; do pid[$commit]=$id; done < <(git log --no-merges -p --format='commit %H' HEAD | git patch-id --stable)
	for (( i = ${#ranges[@]} - 1; i >= 0; i-- )); do
		read -r range version <<< "${ranges[$i]}"
		git log --no-merges --format='%H%x09%as%x09%s' "$range" | while IFS=$'\t' read -r commit date subject; do
			# (a long string, so quotes and backslashes need no escaping)
			subject="${subject//]==]/] ==]}"
			printf '%s\t\t{ "%s", "%s", [==[%s]==] },\n' "${pid[$commit]:-$commit}" "$version" "$date" "$subject"
		done
	done | awk -F'\t' '{ key[NR] = $1; line[NR] = substr($0, length($1) + 2); last[$1] = NR }
		END { for (n = 1; n <= NR; n++) if (last[key[n]] == n) print line[n] }'
	echo "}"
} > "$out"
echo "wrote $out"
