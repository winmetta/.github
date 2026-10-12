#!/usr/bin/env bash
# Sets up the Win Metta workspace root (the parent directory of this repo).
# Creates symlinks there for AGENTS.md, CLAUDE.md, .editorconfig,
# .markdownlint.json and .vscode/extensions.json. Safe to re-run.
# The VS Code workspace file is NOT linked: VS Code resolves symlinks, so a link
# would make "." the .github folder anyway. Open .github/winmetta.code-workspace.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_name="$(basename "$repo_dir")"
workspace="$(dirname "$repo_dir")"

link() {
	local target="$1" path="$workspace/$2"
	if [ -L "$path" ] && [ "$(readlink "$path")" = "$target" ]; then
		echo "ok       $path -> $target"
	elif [ -e "$path" ] || [ -L "$path" ]; then
		echo "skipped  $path already exists and is not a symlink to $target; move it aside and re-run" >&2
	else
		mkdir -p "$(dirname "$path")"
		ln -s "$target" "$path"
		echo "created  $path -> $target"
	fi
}

# Older versions of this script linked the workspace file into the root.
stale="$workspace/winmetta.code-workspace"
if [ -L "$stale" ] && [ "$(readlink "$stale")" = "$repo_name/winmetta.code-workspace" ]; then
	echo "note     $stale is no longer used; open $repo_dir/winmetta.code-workspace instead and remove the link: unlink \"$stale\"" >&2
fi

link "../$repo_name/.vscode/extensions.json" .vscode/extensions.json
link "$repo_name/.editorconfig" .editorconfig
link "$repo_name/.markdownlint.json" .markdownlint.json
link "$repo_name/AGENTS.md" AGENTS.md
link AGENTS.md CLAUDE.md

echo
echo "Workspace root: $workspace"
echo "Clone repos with: cd \"$workspace\" && gh repo clone winmetta/<repo-name>"
