#!/usr/bin/env bash
# Win Metta developer environment bootstrap (macOS only). Safe to re-run.
#
# Installs the tools shared by every Win Metta repo: Xcode Command Line Tools,
# Homebrew, git, curl, gh, shellcheck, shfmt, nvm, VS Code (plus the required
# extensions listed in VSCODE_EXTENSIONS below), Claude Code, Codex CLI and Antigravity CLI.
# Other extensions are optional: see .github/.vscode/extensions.json.
#
# Only the steps everything else depends on (platform check, Command Line Tools,
# Homebrew) stop the script. If any other tool fails to install, the script keeps
# going and lists every failure with a manual fix at the end (exit code 1).
#
# Repo-specific setup (Node version, dependencies, browsers) belongs to each repo.
# Run that repo's own setup script afterwards, e.g. winmetta-platform/scripts/setup-local-dev.sh.
#
# Usage: ./.github/bootstrap-dev-env.sh
set -Eeuo pipefail

NVM_VERSION="v0.40.3"
VSCODE_APP="/Applications/Visual Studio Code.app"
# "name:command[:app path]"; the command (or app) is what we look for to skip installs.
BREW_FORMULAE=(git:git curl:curl gh:gh shellcheck:shellcheck shfmt:shfmt)
BREW_CASKS=("visual-studio-code:code:$VSCODE_APP" claude-code:claude codex:codex antigravity-cli:agy)
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

# Existing Homebrew may not yet be in this shell's PATH.
load_brew_env() {
	if [[ -x /opt/homebrew/bin/brew ]]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [[ -x /usr/local/bin/brew ]]; then
		eval "$(/usr/local/bin/brew shellenv)"
	else
		return 1
	fi
}

# brew is only on PATH for this run; new terminals need it in the shell profile.
note_brew_profile() {
	NOTES+=("Add Homebrew to your shell: echo 'eval \"\$($(command -v brew) shellenv)\"' >> ~/.zprofile, then open a new terminal.")
}

install_homebrew() {
	log_step "Homebrew"
	if command -v brew >/dev/null 2>&1; then
		log_ok "already available: $(command -v brew)"
		return
	fi
	if load_brew_env; then
		log_ok "found and added to PATH for this run: $(command -v brew)"
		note_brew_profile
		return
	fi
	log_info "installing Homebrew"
	local installer
	installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	/bin/bash -c "$installer"
	load_brew_env || die "Homebrew installed but brew was not found."
	log_ok "installed: $(command -v brew)"
	note_brew_profile
}

# True if the tool is already available: its command is on PATH or, for casks
# with an app bundle, the app already exists (brew refuses to overwrite it).
already_installed() {
	local cmd="$1" app="${2:-}"
	command -v "$cmd" >/dev/null 2>&1 || [[ -n "$app" && -d "$app" ]]
}

# Install "name:command[:app path]" entries with brew, skipping tools already
# present (e.g. installed earlier through npm or a direct download).
brew_install_all() {
	local kind="$1" entry name cmd app rest
	shift
	for entry in "$@"; do
		name="${entry%%:*}" rest="${entry#*:}"
		cmd="${rest%%:*}" app=""
		[[ "$rest" == *:* ]] && app="${rest#*:}"
		if already_installed "$cmd" "$app"; then
			log_ok "$name already installed"
		elif [[ "$kind" == cask ]]; then
			log_info "installing $name"
			attempt "install $name" "brew install --cask $name" brew install --cask "$name"
		else
			log_info "installing $name"
			attempt "install $name" "brew install $name" brew install "$name"
		fi
	done
}

install_cli_tools() {
	log_step "CLI tools (git, curl, gh, shellcheck, shfmt)"
	brew_install_all formula "${BREW_FORMULAE[@]}"
}

install_editor_and_ai_tools() {
	log_step "VS Code, Claude Code, Codex CLI and Antigravity CLI"
	brew_install_all cask "${BREW_CASKS[@]}"
	log_info "sign in later with: gh auth login, claude, codex, agy"
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

# nvm's installer is run from a downloaded copy; any failure returns non-zero.
download_and_install_nvm() {
	local installer
	mkdir -p "$NVM_DIR" || return 1
	installer="$(curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh")" || return 1
	bash -c "$installer" || return 1
	[[ -s "$NVM_DIR/nvm.sh" ]]
}

install_nvm() {
	log_step "nvm $NVM_VERSION"
	export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
	if [[ -s "$NVM_DIR/nvm.sh" ]]; then
		log_ok "already installed at $NVM_DIR"
		return
	fi
	log_info "installing into $NVM_DIR"
	attempt "install nvm" "see https://github.com/nvm-sh/nvm#installing-and-updating" download_and_install_nvm
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
	log_info "Next: sign in with 'gh auth login', 'claude', 'codex' and 'agy'."
	log_info "Then clone a repo and run its own setup script (see that repo's README)."
	((${#FAILURES[@]} == 0))
}

main() {
	check_platform
	install_command_line_tools
	install_homebrew
	install_cli_tools
	install_editor_and_ai_tools
	install_vscode_extensions
	install_nvm
	# `||` keeps the ERR trap quiet; the summary already reported the problems.
	print_summary || exit 1
}

main "$@"
