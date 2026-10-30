#!/usr/bin/env bash
# Sets up everything needed to develop winmetta-platform and the related repos. Safe to re-run.
#
# Run it from a clone of this repo, which sits inside the workspace root (the parent directory,
# usually ~/winmetta). Steps, in order:
#   1. check git and gh (logged in) are available
#   2. link the shared workspace files into the workspace root: AGENTS.md, CLAUDE.md,
#      .editorconfig, .markdownlint.json and .vscode/extensions.json. The VS Code workspace file is
#      never linked into the root (VS Code resolves symlinks, so a link would make "." the
#      .github folder anyway): open it only from .github/winmetta.code-workspace. An old link
#      from an earlier version of this setup is removed.
#   3. clone the repos below next to this one (existing clones are left alone)
#   4. run bootstrap-dev-env/bootstrap.sh: mise, CLI tools, git, shell, editors (macOS)
#   5. install this repo's git hooks (lefthook)
#   6. run winmetta-platform/scripts/setup-local-dev.sh: Node, dependencies, Playwright
#   7. make sure the winmetta-platform agent skills are installed (add-dhamma-post, bash-scripting)
#   8. install the shared agent skills for your user (bash-scripting, pr-description,
#      skill-maintainer), so Claude Code and Codex have them in every repo under the workspace
#
# A failure in steps 4-8 does not stop the script: every failure is listed at the end with
# the exit code 1, so one broken tool does not block the rest of the setup.
#
# Usage: ./bootstrap-winmetta-dev.sh [--skip-tools] [--skip-platform] [--dry-run] [-h]
#   --skip-tools     skip step 4 (machine-wide tools; already done on this machine)
#   --skip-platform  skip step 6 (winmetta-platform dependencies)
#   --dry-run        print what would change and change nothing
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_NAME="$(basename "${REPO_DIR}")"
WORKSPACE="$(dirname "${REPO_DIR}")"

# Public repos are cloned for everyone; the private ones need access to the org and are skipped
# with a warning when you do not have it.
readonly PUBLIC_REPOS="agent-skills bootstrap-dev-env winmetta-platform"
readonly PRIVATE_REPOS="winmetta-platform-private"
readonly PLATFORM_DIR="${WORKSPACE}/winmetta-platform"
# Skills winmetta-platform ships. add-dhamma-post is its own; the others come from
# winmetta/agent-skills.
readonly PLATFORM_OWN_SKILLS="add-dhamma-post"
readonly PLATFORM_CATALOG_SKILLS="bash-scripting"
# Catalog skills installed for the user (~/.agents/skills, linked from ~/.claude/skills), so they
# are available in every repo, not just winmetta-platform.
readonly USER_CATALOG_SKILLS="bash-scripting pr-description skill-maintainer"

SKIP_TOOLS=0
SKIP_PLATFORM=0
DRY_RUN=0
FAILURES=""

usage() {
    sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//'
}

log_step() { printf '\n==> %s\n' "$*"; }
log_info() { printf '    %s\n' "$*"; }
log_warn() { printf '    warning: %s\n' "$*" >&2; }
die() {
    printf '%s: error: %s\n' "${0##*/}" "$*" >&2
    exit 1
}

add_failure() { FAILURES="${FAILURES}  - $*"$'\n'; }

# Run a command, or only print it with --dry-run.
run() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        log_info "would run: $*"
    else
        "$@"
    fi
}

# Run a step that must not stop the script: record a failure and carry on.
run_step() {
    local description="$1"
    shift
    if ! "$@"; then
        add_failure "${description}"
        log_warn "${description} failed"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --skip-tools) SKIP_TOOLS=1 ;;
        --skip-platform) SKIP_PLATFORM=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *) die "unknown option: $1 (see --help)" ;;
        esac
        shift
    done
}

check_prerequisites() {
    local tool
    for tool in git gh; do
        command -v "${tool}" >/dev/null 2>&1 ||
            die "${tool} is required. Install it first (see the README's \"Install tools\" section)."
    done
    gh auth status >/dev/null 2>&1 || die "gh is not logged in. Run: gh auth login"
}

# link <target> <path relative to the workspace root>
link() {
    local target="$1" path="${WORKSPACE}/$2"
    if [[ -L "${path}" && "$(readlink "${path}")" == "${target}" ]]; then
        log_info "ok       ${path} -> ${target}"
    elif [[ -e "${path}" || -L "${path}" ]]; then
        log_warn "skipped  ${path} already exists and is not a symlink to ${target}; move it aside and re-run"
    else
        run mkdir -p "$(dirname "${path}")"
        run ln -s "${target}" "${path}"
        [[ "${DRY_RUN}" -eq 1 ]] || log_info "created  ${path} -> ${target}"
    fi
}

link_workspace_files() {
    # The workspace file is opened only from .github/. Older versions of this setup linked it into
    # the root; remove that link (only when it is exactly the old link, never a real file).
    local stale="${WORKSPACE}/winmetta.code-workspace"
    if [[ -L "${stale}" && "$(readlink "${stale}")" == "${REPO_NAME}/winmetta.code-workspace" ]]; then
        run rm "${stale}"
        log_info "removed  ${stale} (old link; open ${REPO_DIR}/winmetta.code-workspace instead)"
    fi
    link "../${REPO_NAME}/.vscode/extensions.json" .vscode/extensions.json
    link "${REPO_NAME}/.editorconfig" .editorconfig
    link "${REPO_NAME}/.markdownlint.json" .markdownlint.json
    link "${REPO_NAME}/AGENTS.md" AGENTS.md
    link AGENTS.md CLAUDE.md
}

# clone_repo <name> <required|optional>: an optional repo that cannot be cloned is only a warning.
clone_repo() {
    local name="$1" kind="$2" dest="${WORKSPACE}/$1"
    if [[ -d "${dest}/.git" ]]; then
        log_info "ok       ${name} is already cloned"
    elif [[ -e "${dest}" ]]; then
        add_failure "${dest} exists but is not a git clone; move it aside and re-run"
    elif [[ "${DRY_RUN}" -eq 1 ]]; then
        log_info "would run: gh repo clone winmetta/${name} ${dest}"
    elif (cd "${WORKSPACE}" && gh repo clone "winmetta/${name}" "${name}"); then
        log_info "cloned   ${name}"
    elif [[ "${kind}" == "optional" ]]; then
        log_warn "could not clone winmetta/${name} (private repo? ask an org admin for access); skipped"
    else
        add_failure "clone winmetta/${name}"
    fi
}

clone_repos() {
    local name
    for name in ${PUBLIC_REPOS}; do clone_repo "${name}" required; done
    for name in ${PRIVATE_REPOS}; do clone_repo "${name}" optional; done
}

# A step that needs a repo cloned earlier: with --dry-run nothing was cloned, so just say what would run.
dry_run_skips() {
    [[ "${DRY_RUN}" -eq 1 ]] || return 1
    log_info "would run: $*"
}

# Make the tools that bootstrap-dev-env installs reachable in this shell, before a new terminal
# has activated mise.
add_tool_paths() {
    export PATH="${HOME}/.local/bin:${HOME}/.local/share/mise/shims:${PATH}"
}

install_machine_tools() {
    local script="${WORKSPACE}/bootstrap-dev-env/bootstrap.sh"
    if [[ ! -x "${script}" ]]; then
        dry_run_skips "${script}" && return 0
        log_warn "${script} not found; clone it first"
        return 1
    fi
    run "${script}" || return 1
    add_tool_paths
}

install_git_hooks() {
    add_tool_paths
    if command -v lefthook >/dev/null 2>&1; then
        (cd "${REPO_DIR}" && run lefthook install)
    else
        log_warn "lefthook is not installed; run bootstrap-dev-env/bootstrap.sh, then: cd ${REPO_DIR} && lefthook install"
        return 1
    fi
}

setup_platform() {
    local script="${PLATFORM_DIR}/scripts/setup-local-dev.sh"
    if [[ ! -x "${script}" ]]; then
        dry_run_skips "${script}" && return 0
        log_warn "${script} not found; is winmetta-platform cloned?"
        return 1
    fi
    run "${script}"
}

# A skill is installed when .agents/skills/<name>/SKILL.md exists and .claude/skills/<name> resolves.
skill_installed() {
    local repo="$1" name="$2"
    [[ -f "${repo}/.agents/skills/${name}/SKILL.md" && -e "${repo}/.claude/skills/${name}/SKILL.md" ]]
}

install_platform_skills() {
    local name status=0
    if [[ ! -d "${PLATFORM_DIR}" ]]; then
        dry_run_skips "check the winmetta-platform agent skills" && return 0
        log_warn "winmetta-platform is not cloned; skipping its agent skills"
        return 1
    fi
    for name in ${PLATFORM_OWN_SKILLS}; do
        if skill_installed "${PLATFORM_DIR}" "${name}"; then
            log_info "ok       skill ${name}"
        else
            log_warn "skill ${name} is missing from winmetta-platform; it is part of that repo, so run: git -C ${PLATFORM_DIR} status"
            status=1
        fi
    done
    for name in ${PLATFORM_CATALOG_SKILLS}; do
        if skill_installed "${PLATFORM_DIR}" "${name}"; then
            log_info "ok       skill ${name}"
        else
            add_tool_paths
            command -v npx >/dev/null 2>&1 || {
                log_warn "npx not found (Node is installed by bootstrap-dev-env); cannot install skill ${name}"
                status=1
                continue
            }
            (cd "${PLATFORM_DIR}" && run npx --yes skills@latest add winmetta/agent-skills --skill "${name}" -a claude-code -a codex -y) || status=1
            [[ "${DRY_RUN}" -eq 1 ]] || log_info "installed skill ${name}; review and commit .agents/skills/${name} and .claude/skills/${name} in winmetta-platform"
        fi
    done
    return "${status}"
}

# Same test as skill_installed, for the user-level folders.
user_skill_installed() {
    [[ -f "${HOME}/.agents/skills/$1/SKILL.md" && -e "${HOME}/.claude/skills/$1/SKILL.md" ]]
}

install_user_skills() {
    local name status=0
    add_tool_paths
    for name in ${USER_CATALOG_SKILLS}; do
        if user_skill_installed "${name}"; then
            log_info "ok       user skill ${name}"
        elif ! command -v npx >/dev/null 2>&1 && [[ "${DRY_RUN}" -eq 0 ]]; then
            log_warn "npx not found (Node is installed by bootstrap-dev-env); cannot install skill ${name}"
            status=1
        else
            run npx --yes skills@latest add winmetta/agent-skills --skill "${name}" -a claude-code -a codex -g -y || status=1
        fi
    done
    return "${status}"
}

print_summary() {
    printf '\nWorkspace root: %s\n' "${WORKSPACE}"
    if [[ -n "${FAILURES}" ]]; then
        printf '\nSome steps failed:\n%s' "${FAILURES}" >&2
        printf 'Fix the cause and re-run this script; finished steps are skipped.\n' >&2
        return 1
    fi
    printf 'Done. Open a new terminal so mise is active, then open %s/winmetta.code-workspace in VS Code.\n' "${REPO_DIR}"
}

main() {
    parse_args "$@"
    log_step "Check prerequisites"
    check_prerequisites
    log_step "Link the shared workspace files"
    link_workspace_files
    log_step "Clone the repos"
    clone_repos
    if [[ "${SKIP_TOOLS}" -eq 0 ]]; then
        log_step "Install the shared dev tools (bootstrap-dev-env)"
        run_step "bootstrap-dev-env/bootstrap.sh" install_machine_tools
    fi
    log_step "Install this repo's git hooks"
    run_step "lefthook install in ${REPO_NAME}" install_git_hooks
    if [[ "${SKIP_PLATFORM}" -eq 0 ]]; then
        log_step "Set up winmetta-platform"
        run_step "winmetta-platform/scripts/setup-local-dev.sh" setup_platform
    fi
    log_step "Install the winmetta-platform agent skills"
    run_step "winmetta-platform agent skills" install_platform_skills
    log_step "Install the shared agent skills for your user"
    run_step "agent skills for your user" install_user_skills
    print_summary
}

main "$@"
