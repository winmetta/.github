# Win Metta "explain-*" shell helpers. bootstrap-dev-env.sh copies this file to
# ~/.config/winmetta/explain.sh and sources it from ~/.zshrc and ~/.bashrc.
# Works in zsh and bash. Run `explain` to list them.

explain() {
	cat <<'HELP'
explain-git-aliases   every git alias with a description and the command it runs
explain-git-config    each shared git setting with its current value and what it does
explain-aliases       shell aliases defined in this shell
explain-command CMD   where CMD comes from (all matches on PATH, and mise's copy)
explain-path          the directories in PATH, one per line, in lookup order
explain-starship      what the starship prompt is showing right now
HELP
}

explain-git-aliases() {
	local file="$HOME/.config/git/winmetta.gitconfig" pairs="" names=" " name desc key value
	if [ -f "$file" ]; then
		# "name<TAB>description" for each "#: description" line above an alias in the shared config.
		pairs="$(awk '/^[[:space:]]*#:/ { sub(/^[[:space:]]*#:[[:space:]]*/, ""); d = $0; next }
			/^[[:space:]]+[A-Za-z0-9_-]+ = / { if (d != "") print $1 "\t" d; d = ""; next }
			{ d = "" }' "$file")"
	fi
	names="$names$(printf '%s\n' "$pairs" | cut -f1 | tr '\n' ' ')"
	printf '%s\n' "$pairs" | while IFS="$(printf '\t')" read -r name desc; do
		[ -n "$name" ] || continue
		printf '%s\n    %s\n    runs: %s\n\n' "$name" "$desc" "$(git config --get "alias.$name")"
	done
	# Aliases from your own config that have no description.
	git config --get-regexp '^alias\.' | while read -r key value; do
		name="${key#alias.}"
		case "$names" in *" $name "*) ;; *) printf '%s\n    runs: %s\n\n' "$name" "$value" ;; esac
	done
}

explain-git-config() {
	local file="$HOME/.config/git/winmetta.gitconfig" key desc
	[ -f "$file" ] || return 0
	# "section.key<TAB>description" for each "#: description" line above a setting.
	awk '/^\[[A-Za-z]+\]/ { s = tolower(substr($1, 2, length($1) - 2)); d = ""; next }
		s == "alias" { next }
		/^[[:space:]]*#:/ { sub(/^[[:space:]]*#:[[:space:]]*/, ""); d = $0; next }
		/^[[:space:]]+[A-Za-z0-9_-]+ = / { if (d != "") print s "." $1 "\t" d; d = ""; next }
		{ d = "" }' "$file" | while IFS="$(printf '\t')" read -r key desc; do
		printf '%s = %s\n    %s\n\n' "$key" "$(git config --get "$key")" "$desc"
	done
	echo "(values shown are what git uses now; anything set below the [include] in ~/.gitconfig or in a repo overrides the shared one)"
}

explain-aliases() {
	alias
}

explain-command() {
	if [ -z "$1" ]; then
		echo "usage: explain-command <command>" >&2
		return 1
	fi
	type -a "$1"
	if command -v mise >/dev/null 2>&1; then
		mise which "$1" 2>/dev/null | sed 's/^/mise: /'
	fi
}

explain-path() {
	printf '%s\n' "$PATH" | tr ':' '\n' | nl -w2 -s'  '
}

explain-starship() {
	starship explain
}
