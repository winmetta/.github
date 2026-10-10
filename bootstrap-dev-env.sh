#!/usr/bin/env bash
# Win Metta developer environment bootstrap (macOS only). Safe to re-run.
#
# Compatibility: this must run on the bash 3.2 that ships with macOS (/bin/bash).
# Do not use associative arrays, mapfile/readarray, ${var,,} or ${var^^}, declare -n
# or other bash 4+ features. Check with: shellcheck -s bash bootstrap-dev-env.sh
#
# Installs the tools shared by every Win Metta repo: Xcode Command Line Tools
# (which provides git, curl and the compiler), mise (the tool and version
# manager), the CLI tools gh, shellcheck, shfmt, the AI coding agents claude and codex, the
# starship prompt, the latest Node.js LTS and the latest stable Python 3 and vim (via mise), and the required
# VS Code extensions listed in VSCODE_EXTENSIONS below. It also copies the
# JetBrains Mono Nerd Font .ttf files into ~/Library/Fonts (no Homebrew or admin
# rights needed) and installs iTerm2 (into ~/Applications) with the "winmetta" iTerm2 profile
# (iterm/winmetta.json, which uses that font) and makes it the default. It activates mise and
# starship in ~/.zshrc (the macOS default shell) and ~/.bashrc, and makes ~/.bash_profile
# load ~/.bashrc, because Terminal.app starts bash as a login shell. It also sets the
# git author (suggested from your GitHub account), installs shared git settings and
# aliases (git/winmetta.gitconfig) and installs `explain-*` shell helpers (run `explain` to list them). It sets up vim with a shared vimrc
# (vim/.vimrc) and the plugins in VIM_PLUGINS. Zed is downloaded into ~/Applications
# if missing, its `zed` command is linked into ~/.local/bin and git's editor is set to
# Zed or vim (asked once).
#
# VS Code and Antigravity CLI have no mise package and are installed by hand; see
# the README. Only the steps everything else depends on (platform
# check, Command Line Tools, mise) stop the script. If any other tool fails to
# install, the script keeps going and lists every failure with a manual fix at
# the end (exit code 1).
#
# Repo-specific setup (the pinned Node version, dependencies, browsers) belongs to each
# repo and is managed with mise there. Run that repo's own setup script
# afterwards, e.g. winmetta-platform/scripts/setup-local-dev.sh.
#
# Usage: ./.github/bootstrap-dev-env.sh
set -Eeuo pipefail

VSCODE_APP="/Applications/Visual Studio Code.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONT_DIR="$HOME/Library/Fonts"
ITERM_APPS=("/Applications/iTerm.app" "$HOME/Applications/iTerm.app")
ITERM_ZIP_URL="https://iterm2.com/downloads/stable/latest"
ITERM_PROFILE_SRC="$SCRIPT_DIR/iterm/winmetta.json"
ITERM_PROFILE_DEST="$HOME/Library/Application Support/iTerm2/DynamicProfiles/winmetta.json"
# Must match "Guid" in iterm/winmetta.json.
ITERM_PROFILE_GUID="202DEC0E-11DE-43C2-A8D2-6A2399F97A1B"
EXPLAIN_SRC="$SCRIPT_DIR/shell/explain.sh"
EXPLAIN_DEST="$HOME/.config/winmetta/explain.sh"
ZED_APPS=("/Applications/Zed.app" "$HOME/Applications/Zed.app")
VIMRC_SRC="$SCRIPT_DIR/vim/.vimrc"
VIMRC_DEST="$HOME/.config/winmetta/vimrc"
VIM_PACK_DIR="$HOME/.vim/pack/winmetta/start"
# "owner/repo" of vim plugins loaded at startup (vim 8+ native packages, no plugin manager).
VIM_PLUGINS=(
	tpope/vim-endwise
	tpope/vim-repeat
	tpope/vim-surround
	tpope/vim-unimpaired
	tpope/vim-commentary
	github/copilot.vim
)
GIT_CONFIG_SRC="$SCRIPT_DIR/git/winmetta.gitconfig"
GIT_CONFIG_DEST="$HOME/.config/git/winmetta.gitconfig"
GIT_GLOBAL_CONFIG="${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}"
STARSHIP_CONFIG_SRC="$SCRIPT_DIR/starship/starship.toml"
STARSHIP_CONFIG_DEST="${STARSHIP_CONFIG:-$HOME/.config/starship.toml}"
# "tool:command"; the command is used to warn about non-mise copies on PATH.
MISE_TOOLS=(gh:gh shellcheck:shellcheck shfmt:shfmt claude:claude codex:codex starship:starship node@lts:node python@latest:python3 vim:vim)
# Required VS Code extensions (the full recommended set is .vscode/extensions.json).
VSCODE_EXTENSIONS=(
	dbaeumer.vscode-eslint
	esbenp.prettier-vscode
	astro-build.astro-vscode
	timonwong.shellcheck
	mkhl.shfmt
	editorconfig.editorconfig
	davidanson.vscode-markdownlint
	ms-playwright.playwright
	anthropic.claude-code
)

# "what failed|how to fix it" lines, reported at the end.
FAILURES=()
# Follow-up steps the user must do by hand, reported at the end.
NOTES=()

# --- logging -----------------------------------------------------------------

if [[ -t 1 ]]; then
	c_blue=$'\033[34m' c_green=$'\033[32m' c_yellow=$'\033[33m' c_red=$'\033[31m' c_off=$'\033[0m'
else
	c_blue="" c_green="" c_yellow="" c_red="" c_off=""
fi
step=0
log_step() {
	step=$((step + 1))
	printf '\n%s==> [%d] %s%s\n' "$c_blue" "$step" "$*" "$c_off"
}
log_info() { printf '    %s\n' "$*"; }
log_ok() { printf '    %s✔ %s%s\n' "$c_green" "$*" "$c_off"; }
log_warn() { printf '    %s! %s%s\n' "$c_yellow" "$*" "$c_off" >&2; }
die() {
	printf '    %s✖ %s%s\n' "$c_red" "$*" "$c_off" >&2
	exit 1
}
trap 'printf "%s✖ bootstrap-dev-env stopped at line %s (exit %s)%s\n" "$c_red" "$LINENO" "$?" "$c_off" >&2' ERR

# Record a non-fatal failure and keep going.
record_failure() {
	FAILURES+=("$1|$2")
	log_warn "$1: failed; continuing (see summary at the end)"
}

# Run a command; on failure record it instead of stopping the script.
# Pass a single simple command: set -e does not apply inside an `if` condition.
attempt() {
	local label="$1" hint="$2"
	shift 2
	if "$@"; then
		log_ok "$label: ok"
	else
		record_failure "$label" "$hint"
		return 0
	fi
}

# --- steps -------------------------------------------------------------------

check_platform() {
	log_step "Checking platform"
	if [[ "$(uname -s)" != Darwin ]]; then
		die "This script supports macOS only. Install the tools listed in the .github README by hand."
	fi
	log_ok "macOS $(sw_vers -productVersion) ($(uname -m))"
}

install_command_line_tools() {
	log_step "Xcode Command Line Tools"
	if xcode-select -p >/dev/null 2>&1; then
		log_ok "already installed at $(xcode-select -p)"
		return
	fi
	log_info "starting installer"
	xcode-select --install || true
	die "Complete the Command Line Tools installer, then rerun this script."
}

# Prefer mise on PATH; fall back to the location the mise.run installer uses.
find_mise() {
	if command -v mise >/dev/null 2>&1; then
		command -v mise
	elif [[ -x "$HOME/.local/bin/mise" ]]; then
		echo "$HOME/.local/bin/mise"
	else
		return 1
	fi
}

# Append `eval "$(mise activate <shell>)"` to a startup file unless it already
# activates mise (any path), so re-runs and a later reinstall add no duplicates.
activate_mise_in() {
	local rc="$1" shell_name="$2" mise_bin="$3" activation
	activation="eval \"\$(\"$mise_bin\" activate $shell_name)\""
	mkdir -p "$(dirname "$rc")"
	if grep -q 'mise.*activate' "$rc" 2>/dev/null; then
		log_ok "mise already activated in $rc"
	else
		printf '%s\n' "$activation" >>"$rc"
		log_ok "activated mise in $rc"
	fi
}

# Terminal.app starts bash as a login shell, which reads ~/.bash_profile and
# never ~/.bashrc, so make the profile load ~/.bashrc. bash reads only the first
# of ~/.bash_profile, ~/.bash_login and ~/.profile, so if one of the latter two
# is in use, creating ~/.bash_profile would shadow it: leave a note instead.
ensure_bash_profile_loads_bashrc() {
	local profile="$HOME/.bash_profile" snippet='[ -f ~/.bashrc ] && . ~/.bashrc'
	if [[ -f "$profile" ]]; then
		if grep -q '\.bashrc' "$profile"; then
			log_ok "$profile already loads ~/.bashrc"
		else
			printf '\n%s\n' "$snippet" >>"$profile"
			log_ok "$profile now loads ~/.bashrc"
		fi
	elif [[ -f "$HOME/.bash_login" || -f "$HOME/.profile" ]]; then
		NOTES+=("bash reads ~/.bash_login or ~/.profile here, not ~/.bash_profile: add this line to that file so bash loads mise: $snippet")
	else
		printf '%s\n' "$snippet" >"$profile"
		log_ok "created $profile that loads ~/.bashrc"
	fi
}

install_mise() {
	log_step "mise (tool version manager)"
	local mise_bin
	if ! mise_bin="$(find_mise)"; then
		log_info "installing to ~/.local/bin/mise"
		# Runs the installer script published by mise; it is not pinned to a version.
		if ! curl -fsSL https://mise.run | sh; then
			die "mise failed to install. Install it by hand, then rerun: curl -fsSL https://mise.run | sh"
		fi
		mise_bin="$HOME/.local/bin/mise"
		log_ok "installed: $mise_bin"
	else
		log_ok "already installed: $mise_bin"
	fi

	# zsh is the macOS default shell; bash is configured too for people who use it.
	activate_mise_in "${ZDOTDIR:-$HOME}/.zshrc" zsh "$mise_bin"
	activate_mise_in "$HOME/.bashrc" bash "$mise_bin"
	ensure_bash_profile_loads_bashrc

	case "${SHELL##*/}" in
	zsh | bash) ;;
	*) NOTES+=("Your login shell is '${SHELL:-unknown}', which this script does not configure. Add mise activation to its startup file: $mise_bin activate <shell>") ;;
	esac
}

# Add the starship prompt to a startup file unless it is already set up there.
# Guarded by `command -v`, so the shell still starts if starship is missing; it
# must come after mise activation, which puts starship on PATH.
configure_starship_in() {
	local rc="$1" shell_name="$2" line
	line="command -v starship >/dev/null 2>&1 && eval \"\$(starship init $shell_name)\""
	if grep -q 'starship init' "$rc" 2>/dev/null; then
		log_ok "starship already set up in $rc"
	else
		printf '%s\n' "$line" >>"$rc"
		log_ok "set up starship in $rc"
	fi
}

configure_starship() {
	log_step "starship prompt"
	configure_starship_in "${ZDOTDIR:-$HOME}/.zshrc" zsh
	configure_starship_in "$HOME/.bashrc" bash
	attempt "install starship config" \
		"copy .github/starship/starship.toml to '$STARSHIP_CONFIG_DEST'" \
		install_starship_config
}

# Keep ~/.config/starship.toml in step with the shared config. Missing: copy it.
# Identical: nothing to do. Different: show the diff and ask before replacing it
# (the old file is backed up first, only in this case). Non-interactive runs
# never replace it and leave a note instead.
install_starship_config() {
	local answer backup
	if [[ ! -e "$STARSHIP_CONFIG_DEST" ]]; then
		mkdir -p "$(dirname "$STARSHIP_CONFIG_DEST")" && cp "$STARSHIP_CONFIG_SRC" "$STARSHIP_CONFIG_DEST"
		log_info "copied the shared config to $STARSHIP_CONFIG_DEST"
		return
	fi
	if cmp -s "$STARSHIP_CONFIG_SRC" "$STARSHIP_CONFIG_DEST"; then
		log_ok "$STARSHIP_CONFIG_DEST is up to date"
		return
	fi
	log_info "$STARSHIP_CONFIG_DEST differs from the shared config (- yours, + shared):"
	diff -u "$STARSHIP_CONFIG_DEST" "$STARSHIP_CONFIG_SRC" | sed 's/^/      /' || true
	if [[ -t 0 ]]; then
		read -r -p "    Replace it with the shared config? Yours is backed up first. [y/N] " answer || answer=""
	else
		answer=""
	fi
	case "$answer" in
	[yY] | [yY][eE][sS])
		backup="$STARSHIP_CONFIG_DEST.bak-$(date +%Y%m%d-%H%M%S)"
		cp "$STARSHIP_CONFIG_DEST" "$backup" && cp "$STARSHIP_CONFIG_SRC" "$STARSHIP_CONFIG_DEST"
		log_info "backed up your config to $backup and installed the shared one"
		;;
	*)
		NOTES+=("$STARSHIP_CONFIG_DEST was left as is and differs from the shared config. To update it: cp '$STARSHIP_CONFIG_SRC' '$STARSHIP_CONFIG_DEST' (back up yours first).")
		;;
	esac
}

# Run gh from PATH, or through mise when this shell has not activated mise yet.
run_gh() {
	local mise_bin
	if command -v gh >/dev/null 2>&1; then
		gh "$@"
	elif mise_bin="$(find_mise)"; then
		"$mise_bin" exec gh -- gh "$@"
	else
		return 1
	fi
}

# Suggest an author from the signed-in GitHub account (needs `gh auth login`):
# "<name or login>" and the private "<id>+<login>@users.noreply.github.com"
# address, which GitHub links to the account without exposing a real email.
# Prints "name|email", or nothing when gh is missing or not signed in.
github_identity() {
	local id login name
	id="$(run_gh api user --jq .id 2>/dev/null)" || return 0
	login="$(run_gh api user --jq .login 2>/dev/null)" || return 0
	name="$(run_gh api user --jq '.name // empty' 2>/dev/null)" || name=""
	[[ -n "$id" && -n "$login" ]] || return 0
	echo "${name:-$login}|$id+$login@users.noreply.github.com"
}

# When gh is installed but not signed in, offer to run `gh auth login` now.
# Returns 0 only if gh is signed in afterwards.
offer_gh_login() {
	local answer
	run_gh --version >/dev/null 2>&1 || return 1
	run_gh auth status >/dev/null 2>&1 && return 0
	read -r -p "    gh is not signed in to GitHub. Sign in now to use your GitHub name and email? [Y/n] " answer || answer=n
	case "$answer" in
	[nN]*) return 1 ;;
	esac
	run_gh auth login && run_gh auth status >/dev/null 2>&1
}

# Make sure git has a commit author. Without user.name/user.email git guesses
# them from the OS user and hostname (e.g. "alo <alo@mac.local>"), which ends up
# in every commit. Missing values are saved globally (all repos), suggesting the
# GitHub account's name and noreply email (offering to run `gh auth login` first
# if gh is not signed in); press Enter to
# accept the suggestion or type another value. Values already set (globally or
# in the repo) are left alone.
configure_git_identity() {
	log_step "git identity (user.name, user.email)"
	local key value suggestion label gh_identity=""
	local missing=0
	for key in name email; do
		if [[ -z "$(git -C "$SCRIPT_DIR" config --get "user.$key" 2>/dev/null || true)" ]]; then
			missing=1
		fi
	done
	if ((missing)); then
		gh_identity="$(github_identity)"
		if [[ -z "$gh_identity" && -t 0 ]]; then
			offer_gh_login && gh_identity="$(github_identity)"
		fi
	fi
	for key in name email; do
		value="$(git -C "$SCRIPT_DIR" config --get "user.$key" 2>/dev/null || true)"
		if [[ -n "$value" ]]; then
			log_ok "user.$key = $value"
			continue
		fi
		if [[ "$key" == name ]]; then
			suggestion="${gh_identity%%|*}" label="your full name"
		else
			suggestion="${gh_identity#*|}" label="your email"
		fi
		[[ -n "$gh_identity" ]] || suggestion=""
		if [[ -t 0 ]]; then
			read -r -p "    git user.$key is not set. Enter $label${suggestion:+ [$suggestion]} (blank to skip): " value || value=""
			value="${value:-$suggestion}"
		else
			value=""
		fi
		if [[ -n "$value" ]]; then
			attempt "set git user.$key" "git config --global user.$key '<value>'" \
				git config --global "user.$key" "$value"
		else
			NOTES+=("git user.$key is not set: run git config --global user.$key '<value>' (after gh auth login, re-running this script suggests your GitHub name and noreply email). Until then git guesses it from your OS user and hostname.")
		fi
	done
}

# Install the shared git settings and aliases. The file is copied to
# ~/.config/git/winmetta.gitconfig (replaced on every run, it is ours) and
# included at the TOP of the global git config, so your own settings further
# down still win.
install_git_config() {
	local tmp
	mkdir -p "$(dirname "$GIT_CONFIG_DEST")" && cp "$GIT_CONFIG_SRC" "$GIT_CONFIG_DEST" || return 1
	if git config --file "$GIT_GLOBAL_CONFIG" --get-all include.path 2>/dev/null | grep -qxF "$GIT_CONFIG_DEST"; then
		log_info "$GIT_GLOBAL_CONFIG already includes it"
		return 0
	fi
	tmp="$(mktemp)" || return 1
	{
		printf '[include]\n\tpath = %s\n\n' "$GIT_CONFIG_DEST"
		cat "$GIT_GLOBAL_CONFIG" 2>/dev/null || true
	} >"$tmp" && cat "$tmp" >"$GIT_GLOBAL_CONFIG"
	local rc=$?
	rm -f "$tmp"
	return $rc
}

configure_git() {
	log_step "git settings and aliases"
	attempt "install git settings and aliases" \
		"copy .github/git/winmetta.gitconfig to '$GIT_CONFIG_DEST' and add an [include] path for it at the top of ~/.gitconfig" \
		install_git_config
}

# Install the explain-* shell helpers: copy shell/explain.sh to
# ~/.config/winmetta/explain.sh (replaced on every run, it is ours) and source it
# from a startup file. Also removes the old `galias` alias that an earlier
# version of this script added.
configure_explain_in() {
	local rc="$1" line
	line="[ -f \"$EXPLAIN_DEST\" ] && . \"$EXPLAIN_DEST\""
	if [[ -f "$rc" ]] && grep -q '^alias galias=' "$rc"; then
		sed -i.bak '/^alias galias=/d' "$rc" && rm -f "$rc.bak"
		log_info "removed the old galias alias from $rc"
	fi
	if grep -qF "$EXPLAIN_DEST" "$rc" 2>/dev/null; then
		log_ok "explain helpers already sourced in $rc"
	else
		printf '%s\n' "$line" >>"$rc"
		log_ok "sourced the explain helpers in $rc"
	fi
}

install_explain() {
	mkdir -p "$(dirname "$EXPLAIN_DEST")" && cp "$EXPLAIN_SRC" "$EXPLAIN_DEST" || return 1
	configure_explain_in "${ZDOTDIR:-$HOME}/.zshrc"
	configure_explain_in "$HOME/.bashrc"
}

configure_explain() {
	log_step "shell helpers (explain-*)"
	attempt "install explain-* shell helpers" \
		"copy .github/shell/explain.sh to '$EXPLAIN_DEST' and add '. $EXPLAIN_DEST' to ~/.zshrc and ~/.bashrc" \
		install_explain
	log_info "Run 'explain' in a new terminal to list them."
}

# Path of an installed Zed.app (system-wide or in ~/Applications), if any.
find_zed_app() {
	local app
	for app in "${ZED_APPS[@]}"; do
		if [[ -d "$app" ]]; then
			echo "$app"
			return 0
		fi
	done
	return 1
}

# Download the latest stable Zed (the same dmg Zed's own install.sh uses) and copy
# Zed.app into ~/Applications (no admin rights needed). The dmg is always unmounted.
install_zed_app() {
	local arch tmp mount="" ok=1
	case "$(uname -m)" in
	arm64) arch=aarch64 ;;
	x86_64) arch=x86_64 ;;
	*) return 1 ;;
	esac
	tmp="$(mktemp -d)" || return 1
	if curl -fsSL -o "$tmp/Zed.dmg" "https://cloud.zed.dev/releases/stable/latest/download?asset=zed&os=macos&arch=$arch&source=install.sh" &&
		hdiutil attach -quiet -nobrowse -readonly -mountpoint "$tmp/mount" "$tmp/Zed.dmg" >/dev/null; then
		mount="$tmp/mount"
		mkdir -p "$HOME/Applications" && ditto "$mount/Zed.app" "$HOME/Applications/Zed.app" && ok=0
	fi
	[[ -n "$mount" ]] && hdiutil detach -quiet "$mount" >/dev/null 2>&1
	rm -rf "${tmp:?}"
	return $ok
}

# Link Zed's command-line tool as ~/.local/bin/zed (already on PATH via mise's installer).
link_zed_cli() {
	local app
	app="$(find_zed_app)" || return 1
	mkdir -p "$HOME/.local/bin" && ln -sf "$app/Contents/MacOS/cli" "$HOME/.local/bin/zed"
}

configure_zed() {
	log_step "Zed editor"
	if find_zed_app >/dev/null; then
		log_ok "Zed already installed at $(find_zed_app)"
	else
		log_info "downloading Zed (about 150 MB)"
		attempt "install Zed" \
			"download Zed from https://zed.dev/download and move Zed.app to ~/Applications" \
			install_zed_app
		find_zed_app >/dev/null || return 0
	fi
	attempt "link the zed command" \
		"ln -sf <path to Zed.app>/Contents/MacOS/cli ~/.local/bin/zed" \
		link_zed_cli
}

# Choose the editor git opens for commit messages and interactive rebases: Zed
# (`zed --wait`, so git waits for you to close the tab) or vim. Asked once and
# saved globally in ~/.gitconfig; an editor you already set is left alone.
# Without a terminal, Zed is used if installed, else git's own default stays.
configure_git_editor() {
	log_step "git editor (Zed or vim)"
	local current default choice="" answer=""
	current="$(git config --file "$GIT_GLOBAL_CONFIG" --get core.editor 2>/dev/null || true)"
	if [[ -n "$current" ]]; then
		log_ok "core.editor = $current (already set; change it with: git config --global core.editor vim)"
		return
	fi
	if command -v zed >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/zed" ]] || find_zed_app >/dev/null; then
		default=zed
	else
		default=vim
	fi
	if [[ -t 0 ]]; then
		read -r -p "    Editor for git commit messages: [z]ed or [v]im? [${default:0:1}] " answer || answer=""
		case "$answer" in
		[zZ]*) choice=zed ;;
		[vV]*) choice=vim ;;
		*) choice="$default" ;;
		esac
	elif [[ "$default" == zed ]]; then
		choice=zed
	fi
	case "$choice" in
	zed) attempt "set git editor to Zed" "git config --global core.editor 'zed --wait'" git config --global core.editor "zed --wait" ;;
	vim) attempt "set git editor to vim" "git config --global core.editor vim" git config --global core.editor vim ;;
	*) NOTES+=("git core.editor is not set: choose with git config --global core.editor 'zed --wait' (or vim).") ;;
	esac
}

# Run vim from mise when it has one, else whatever vim is on PATH.
run_vim() {
	local mise_bin
	if mise_bin="$(find_mise)" && mise_has "$mise_bin" vim; then
		"$mise_bin" exec vim -- vim "$@"
	else
		vim "$@"
	fi
}

# Clone a plugin into the package dir, or fast-forward it if already there, then
# build its help tags.
install_vim_plugin() {
	local repo="$1" dir
	dir="$VIM_PACK_DIR/${repo#*/}"
	if [[ -d "$dir/.git" ]]; then
		git -C "$dir" pull --ff-only --quiet || return 1
	else
		mkdir -p "$VIM_PACK_DIR" && git clone --depth 1 --quiet "https://github.com/$repo.git" "$dir" || return 1
	fi
	if [[ -d "$dir/doc" ]]; then
		run_vim -u NONE -es -c "helptags $dir/doc" -c q || true
	fi
}

# Copy the shared vimrc to ~/.config/winmetta/vimrc (replaced every run) and
# source it from the TOP of ~/.vimrc, so your own settings below it win.
install_vimrc() {
	local rc="$HOME/.vimrc" line tmp
	line="source $VIMRC_DEST"
	mkdir -p "$(dirname "$VIMRC_DEST")" && cp "$VIMRC_SRC" "$VIMRC_DEST" || return 1
	if grep -qxF "$line" "$rc" 2>/dev/null; then
		log_info "$rc already sources it"
		return 0
	fi
	tmp="$(mktemp)" || return 1
	{
		printf '%s\n\n' "$line"
		cat "$rc" 2>/dev/null || true
	} >"$tmp" && cat "$tmp" >"$rc"
	local status=$?
	rm -f "$tmp"
	return $status
}

configure_vim() {
	log_step "vim config and plugins"
	local repo
	attempt "install vimrc" \
		"copy .github/vim/.vimrc to '$VIMRC_DEST' and add 'source $VIMRC_DEST' at the top of ~/.vimrc" \
		install_vimrc
	for repo in "${VIM_PLUGINS[@]}"; do
		attempt "vim plugin $repo" \
			"git clone https://github.com/$repo.git '$VIM_PACK_DIR/${repo#*/}'" \
			install_vim_plugin "$repo"
	done
	NOTES+=("GitHub Copilot for vim needs a sign-in and a Copilot subscription: open vim and run :Copilot setup. Remove ~/.vim/pack/winmetta/start/copilot.vim to opt out.")
}

# Download a font zip and copy its .ttf files into ~/Library/Fonts (per user, no
# admin rights). Skips static/ instances to avoid duplicate families. Skipped when
# a file matching the glob "$3" is already installed.
install_font_zip() {
	local label="$1" url="$2" installed_glob="$3" tmp file count=0
	if compgen -G "$FONT_DIR/$installed_glob" >/dev/null; then
		log_ok "$label already installed"
		return 0
	fi
	log_info "downloading $label"
	tmp="$(mktemp -d)" || return 1
	if ! curl -fsSL -o "$tmp/font.zip" "$url" || ! unzip -q "$tmp/font.zip" -d "$tmp/fonts"; then
		rm -rf "${tmp:?}"
		return 1
	fi
	mkdir -p "$FONT_DIR"
	while IFS= read -r -d '' file; do
		if ! cp "$file" "$FONT_DIR/"; then
			rm -rf "${tmp:?}"
			return 1
		fi
		count=$((count + 1))
	done < <(find "$tmp/fonts" -name '*.ttf' -not -path '*/static/*' -print0)
	rm -rf "${tmp:?}"
	if ((count == 0)); then
		return 1
	fi
	log_info "copied $count font file(s) to $FONT_DIR"
}

install_fonts() {
	log_step "Font (JetBrains Mono Nerd Font)"
	attempt "install JetBrains Mono Nerd Font" \
		"download JetBrainsMono.zip from https://github.com/ryanoasis/nerd-fonts/releases/latest and copy the .ttf files to ~/Library/Fonts" \
		install_font_zip "JetBrains Mono Nerd Font" \
		"https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
		'JetBrainsMonoNerdFont*.ttf'
}

# True if iTerm2 is installed system-wide or in ~/Applications.
iterm_installed() {
	local app
	for app in "${ITERM_APPS[@]}"; do
		[[ -d "$app" ]] && return 0
	done
	return 1
}

# Download the latest stable iTerm2 into ~/Applications (no admin rights needed).
# The URL redirects to the current iTerm2-<version>.zip; curl leaves no quarantine flag.
install_iterm_app() {
	local tmp dest="$HOME/Applications"
	tmp="$(mktemp -d)" || return 1
	if ! curl -fsSL -o "$tmp/iterm.zip" "$ITERM_ZIP_URL" || ! unzip -q "$tmp/iterm.zip" -d "$tmp/app"; then
		rm -rf "${tmp:?}"
		return 1
	fi
	mkdir -p "$dest"
	if ! cp -R "$tmp/app/iTerm.app" "$dest/"; then
		rm -rf "${tmp:?}"
		return 1
	fi
	rm -rf "${tmp:?}"
}

# Install iTerm2 if missing, add the "winmetta" profile as a Dynamic Profile
# (iTerm2 loads it without restarting) and make it the default profile. iTerm2
# may rewrite its preferences when it quits, so quit it before running this.
configure_iterm() {
	log_step "iTerm2 (app and winmetta profile)"
	if iterm_installed; then
		log_ok "iTerm2 already installed"
	else
		log_info "downloading iTerm2 (about 60 MB)"
		attempt "install iTerm2" \
			"download iTerm2 from https://iterm2.com/downloads.html and move iTerm.app to ~/Applications" \
			install_iterm_app
		if ! iterm_installed; then
			return
		fi
	fi
	attempt "install iTerm2 profile" \
		"copy .github/iterm/winmetta.json to '$ITERM_PROFILE_DEST'" \
		install_iterm_profile
	attempt "set winmetta as the default iTerm2 profile" \
		"iTerm2 > Settings > Profiles > winmetta > Other Actions > Set as Default" \
		defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$ITERM_PROFILE_GUID"
	if pgrep -x iTerm2 >/dev/null 2>&1; then
		NOTES+=("iTerm2 is running: if winmetta is not the default for new windows, quit iTerm2 (Cmd+Q) and reopen it, or re-run this script with iTerm2 closed.")
	fi
}

install_iterm_profile() {
	mkdir -p "$(dirname "$ITERM_PROFILE_DEST")" && cp "$ITERM_PROFILE_SRC" "$ITERM_PROFILE_DEST"
}

# True if mise has the tool installed. A copy on PATH from elsewhere (e.g.
# Homebrew) does not count, so every tool ends up managed by mise.
mise_has() {
	"$1" where "${2%%@*}" >/dev/null 2>&1
}

# Install "tool:command" entries globally with mise, skipping tools mise already has.
mise_install_all() {
	local entry tool cmd mise_bin
	mise_bin="$(find_mise)" || {
		record_failure "CLI tools (mise not found)" "install mise, then re-run this script"
		return
	}
	for entry in "$@"; do
		tool="${entry%%:*}" cmd="${entry#*:}"
		if mise_has "$mise_bin" "$tool"; then
			log_ok "$tool already installed with mise"
		else
			log_info "installing $tool"
			attempt "install $tool" "mise use -g $tool" "$mise_bin" use -g "$tool"
		fi
		warn_if_not_mise "$cmd"
	done
}

# Note when a command on PATH is not the mise-managed one (e.g. a Homebrew copy).
warn_if_not_mise() {
	local path
	path="$(command -v "$1" 2>/dev/null)" || return 0
	case "$path" in
	"$HOME"/.local/share/mise/*) ;;
	# macOS ships /usr/bin/python3 and friends: not removable, and mise's copy wins once mise is activated.
	/usr/bin/*) ;;
	*) NOTES+=("'$1' resolves to $path, not mise. Remove that copy (e.g. brew uninstall $1) so the mise one is used.") ;;
	esac
}

install_cli_tools() {
	log_step "CLI tools (gh, shellcheck, shfmt, claude, codex, starship, Node.js LTS, Python, vim)"
	mise_install_all "${MISE_TOOLS[@]}"
}

# Apps with no mise package are installed by hand, not by this script.
note_manual_apps() {
	log_step "Apps to install by hand"
	log_info "This script does not install VS Code or Antigravity CLI (no mise package)."
	log_info "Download and install them yourself (links in .github/README.md), then re-run this script."
}

# Prefer `code` on PATH; fall back to the CLI bundled in the app.
find_code() {
	if command -v code >/dev/null 2>&1; then
		command -v code
	elif [[ -x "$VSCODE_APP/Contents/Resources/app/bin/code" ]]; then
		echo "$VSCODE_APP/Contents/Resources/app/bin/code"
	else
		return 1
	fi
}

install_vscode_extensions() {
	log_step "VS Code extensions"
	local code_bin
	if ! code_bin="$(find_code)"; then
		record_failure "VS Code extensions (VS Code CLI not found)" "install VS Code, then re-run this script"
		return
	fi
	local installed ext
	installed="$("$code_bin" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')" || installed=""
	for ext in "${VSCODE_EXTENSIONS[@]}"; do
		if grep -qxF "$(tr '[:upper:]' '[:lower:]' <<<"$ext")" <<<"$installed"; then
			log_ok "$ext already installed"
		else
			log_info "installing $ext"
			attempt "install extension $ext" "code --install-extension $ext" \
				"$code_bin" --install-extension "$ext" --force
		fi
	done
}

print_summary() {
	local item
	if ((${#FAILURES[@]} == 0)); then
		printf '\n%sShared tooling is ready.%s\n' "$c_green" "$c_off"
	else
		printf '\n%sFinished with %d problem(s):%s\n' "$c_red" "${#FAILURES[@]}" "$c_off" >&2
		for item in "${FAILURES[@]}"; do
			printf '  %s✖ %s%s\n      fix: %s\n' "$c_red" "${item%%|*}" "$c_off" "${item#*|}" >&2
		done
		log_info "Fix the items above by hand, or fix this script, then re-run it (it skips what is installed)."
	fi
	for item in "${NOTES[@]+"${NOTES[@]}"}"; do
		log_warn "$item"
	done
	log_info "Next: install VS Code and Antigravity CLI by hand and open a new terminal so mise takes effect."
	log_info "Then sign in with 'gh auth login', 'claude', 'codex' and 'agy'."
	log_info "Then clone a repo and run its own setup script (see that repo's README)."
	((${#FAILURES[@]} == 0))
}

main() {
	check_platform
	install_command_line_tools
	install_mise
	install_cli_tools
	configure_git_identity
	configure_git
	configure_starship
	configure_explain
	configure_vim
	install_fonts
	configure_iterm
	configure_zed
	configure_git_editor
	note_manual_apps
	install_vscode_extensions
	print_summary || exit 1
}

main "$@"
