# Win Metta "explain-*" shell helpers. bootstrap-dev-env.sh copies this file to
# ~/.config/winmetta/explain.sh and sources it from ~/.zshrc and ~/.bashrc.
# Works in zsh and bash. Run `explain` to list them.

explain() {
	cat <<'HELP'
explain-tools         every tool the bootstrap installs: what it is and an example
explain-git-aliases   every git alias with a description and the command it runs
explain-git-config    each shared git setting with its current value and what it does
explain-aliases       shell aliases defined in this shell
explain-command CMD   where CMD comes from (all matches on PATH, and mise's copy)
explain-path          the directories in PATH, one per line, in lookup order
explain-starship      what the starship prompt is showing right now
HELP
}

# command | what it is | example. Kept in a function, not in a $( ), because the
# bash 3.2 that ships with macOS cannot parse a heredoc with an apostrophe inside $( ).
_explain_tools_data() {
	cat <<'TOOLS'
mise|manages every tool below and their versions, instead of Homebrew or nvm|mise ls ; mise use -g <tool> ; mise latest <tool>
gh|GitHub from the terminal: clone, pull requests, issues, API calls|gh repo clone winmetta/<repo> ; gh pr create ; gh auth status
git|version control; shared settings and aliases are in ~/.config/git/winmetta.gitconfig|explain-git-aliases ; explain-git-config
shellcheck|finds bugs in shell scripts|shellcheck script.sh
shfmt|formats shell scripts consistently|shfmt -d script.sh   (diff) ; shfmt -w script.sh   (rewrite)
gitleaks|scans for secrets (tokens, keys, passwords) in files and git history|gitleaks git --staged --redact ; gitleaks dir .
lefthook|runs the git hooks in lefthook.yml (checks before each commit, commit-message check)|lefthook install ; lefthook run pre-commit
markdownlint-cli2|checks Markdown files for style problems (rules in .markdownlint.json); --fix repairs what it can|markdownlint-cli2 README.md ; markdownlint-cli2 --fix README.md
prettier|formats Markdown (and JSON, CSS, JS, ...) where a repo has a prettier config|prettier --check README.md ; prettier --write README.md
claude|Claude Code, an AI coding agent|claude
codex|Codex CLI, an AI coding agent|codex
starship|the shell prompt: path, git branch, ahead/behind counts and a green check when synced|edit ~/.config/starship.toml ; explain-starship
node|JavaScript runtime (latest LTS; repos pin their own version)|node --version ; mise use node@22
python3|Python 3 (latest stable; repos pin their own version)|python3 --version ; python3 -m venv .venv
vim|terminal editor with the shared ~/.config/winmetta/vimrc and plugins (surround, commentary, Copilot)|vim file ; :help surround
bash|bash 5 (macOS ships 3.2): test scripts on both versions|bash --version ; /bin/bash --version
wget|download files from the web|wget https://example.com/file.zip
rg|ripgrep: fast text search that respects .gitignore (a better grep -r)|rg "TODO" ; rg -t py "import" ; rg -l foo
fd|fast file finder with simple syntax (a better find)|fd readme ; fd -e md ; fd -t d src
sd|find and replace with normal regex, the same on macOS and Linux (a better sed)|sd 'old' 'new' file ; fd -e md -x sd 'a' 'b'
bat|cat with syntax highlighting and git markers|bat file ; bat -n file ; bat -l json
fzf|fuzzy finder: Ctrl-R history, Ctrl-T files, Alt-C folders|Ctrl-R ; git branch | fzf ; fd | fzf
zoxide|smarter cd that learns the folders you use|z winmetta ; z foo bar ; zi
iTerm|terminal app with the winmetta profile|open ~/Applications/iTerm.app
zed|Zed editor; its zed command is also git's commit-message editor|zed . ; zed --wait file
TOOLS
}

explain-tools() {
	local cmd desc try mark
	# Alphabetical, case ignored.
	_explain_tools_data | sort -f -t'|' -k1,1 | while IFS='|' read -r cmd desc try; do
		[ -n "$cmd" ] || continue
		if command -v "${cmd%% *}" >/dev/null 2>&1 || [ -d "/Applications/$cmd.app" ] || [ -d "$HOME/Applications/$cmd.app" ]; then
			mark="+"
		else
			mark="-"
		fi
		printf '%s %s\n    %s\n    try: %s\n\n' "$mark" "$cmd" "$desc" "$try"
	done
	echo "(+ installed, - not found on PATH; run the bootstrap script again to install what is missing)"
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
