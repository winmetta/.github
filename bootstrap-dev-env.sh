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
# starship prompt and the latest Node.js LTS (via mise), and the required
# VS Code extensions listed in VSCODE_EXTENSIONS below. It also copies the
# JetBrains Mono Nerd Font and Cascadia Code .ttf files into ~/Library/Fonts (no
# Homebrew or admin rights needed). It activates mise and
# starship in ~/.zshrc (the macOS default shell) and ~/.bashrc, and makes ~/.bash_profile
# load ~/.bashrc, because Terminal.app starts bash as a login shell.
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
FONT_DIR="$HOME/Library/Fonts"
# "tool:command"; the command is what we look for on PATH to skip installs.
MISE_TOOLS=(gh:gh shellcheck:shellcheck shfmt:shfmt claude:claude codex:codex starship:starship node@lts:node)
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

# Print the download URL of the latest Cascadia Code release zip. The asset name
# contains the version, so resolve the latest tag from the redirect (no API, no rate limit).
cascadia_zip_url() {
	local final tag
	final="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/microsoft/cascadia-code/releases/latest)" || return 1
	tag="${final##*/}"
	[[ "$tag" == v* ]] || return 1
	echo "https://github.com/microsoft/cascadia-code/releases/download/$tag/CascadiaCode-${tag#v}.zip"
}

install_fonts() {
	log_step "Fonts (JetBrains Mono Nerd Font, Cascadia Code)"
	local url
	attempt "install JetBrains Mono Nerd Font" \
		"download JetBrainsMono.zip from https://github.com/ryanoasis/nerd-fonts/releases/latest and copy the .ttf files to ~/Library/Fonts" \
		install_font_zip "JetBrains Mono Nerd Font" \
		"https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
		'JetBrainsMonoNerdFont*.ttf'
	if url="$(cascadia_zip_url)"; then
		attempt "install Cascadia Code" \
			"download CascadiaCode-<version>.zip from https://github.com/microsoft/cascadia-code/releases/latest and copy the .ttf files to ~/Library/Fonts" \
			install_font_zip "Cascadia Code" "$url" 'CascadiaCode*.ttf'
	else
		record_failure "install Cascadia Code (could not find the latest release)" \
			"download CascadiaCode-<version>.zip from https://github.com/microsoft/cascadia-code/releases/latest and copy the .ttf files to ~/Library/Fonts"
	fi
	log_info "Set your terminal font to 'JetBrainsMono Nerd Font' (starship icons) or 'Cascadia Code'."
}

# True if the tool's command is already on PATH (e.g. installed without mise).
already_installed() {
	command -v "$1" >/dev/null 2>&1
}

# Install "tool:command" entries globally with mise, skipping tools already on PATH.
mise_install_all() {
	local entry tool cmd mise_bin
	mise_bin="$(find_mise)" || {
		record_failure "CLI tools (mise not found)" "install mise, then re-run this script"
		return
	}
	for entry in "$@"; do
		tool="${entry%%:*}" cmd="${entry#*:}"
		if already_installed "$cmd"; then
			log_ok "$tool already installed"
		else
			log_info "installing $tool"
			attempt "install $tool" "mise use -g $tool" "$mise_bin" use -g "$tool"
		fi
	done
}

install_cli_tools() {
	log_step "CLI tools (gh, shellcheck, shfmt, claude, codex, starship, Node.js LTS)"
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
	configure_starship
	install_fonts
	note_manual_apps
	install_vscode_extensions
	print_summary || exit 1
}

main "$@"
