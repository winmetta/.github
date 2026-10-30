#!/usr/bin/env bash
# Tests for bootstrap-winmetta-dev.sh, run in a throwaway workspace with a stub `gh` and
# `lefthook`, so nothing is cloned or installed. Run: bash scripts/bootstrap-winmetta-dev.test.sh
# (exits non-zero on failure).
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bootstrap-winmetta-dev.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
FAILURES=0

pass() { echo "ok - $1"; }
fail() {
    echo "not ok - $1"
    FAILURES=$((FAILURES + 1))
}

# expect_status <name> <wanted> <got>
expect_status() {
    if [[ "$3" -eq "$2" ]]; then pass "$1"; else fail "$1 (exit $3, wanted $2)"; fi
}

# check <name> <command...>: passes when the command succeeds.
check() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then pass "${name}"; else fail "${name}"; fi
}

# new_workspace: a fresh workspace root with a copy of the script in .github/ and stub tools in bin/.
# Sets WS, BIN and CLONE_LOG.
new_workspace() {
    WS="$(mktemp -d "${TMP}/ws.XXXXXX")"
    BIN="${WS}/bin"
    CLONE_LOG="${WS}/clone.log"
    mkdir -p "${WS}/.github" "${BIN}"
    cp "${SRC}" "${WS}/.github/bootstrap-winmetta-dev.sh"
    : >"${CLONE_LOG}"
    # gh: `auth status` succeeds unless GH_NO_LOGIN is set; `repo clone winmetta/<name> <name>`
    # creates a fake clone (winmetta-platform gets its two skills) unless GH_FAIL lists the name.
    cat >"${BIN}/gh" <<STUB
#!/usr/bin/env bash
if [[ "\$1 \$2" == "auth status" ]]; then [[ -z "\${GH_NO_LOGIN:-}" ]]; exit; fi
if [[ "\$1 \$2" == "repo clone" ]]; then
	name="\${4}"
	echo "\${name}" >>"${CLONE_LOG}"
	case " \${GH_FAIL:-} " in *" \${name} "*) exit 1 ;; esac
	mkdir -p "\${name}/.git"
	if [[ "\${name}" == "winmetta-platform" ]]; then
		for s in add-dhamma-post bash-scripting; do
			mkdir -p "\${name}/.agents/skills/\${s}" "\${name}/.claude/skills"
			touch "\${name}/.agents/skills/\${s}/SKILL.md"
			ln -s "../../.agents/skills/\${s}" "\${name}/.claude/skills/\${s}"
		done
	fi
	exit 0
fi
exit 1
STUB
    printf '#!/usr/bin/env bash\nexit 0\n' >"${BIN}/lefthook"
    # npx: `npx --yes skills@latest add winmetta/agent-skills --skill <name> ... -g` records the
    # call and creates the user-level skill folder and link, like the real installer.
    cat >"${BIN}/npx" <<STUB
#!/usr/bin/env bash
echo "\$*" >>"${WS}/npx.log"
while [[ \$# -gt 0 ]]; do
	if [[ "\$1" == "--skill" ]]; then name="\$2"; fi
	shift
done
mkdir -p "\${HOME}/.agents/skills/\${name}" "\${HOME}/.claude/skills"
touch "\${HOME}/.agents/skills/\${name}/SKILL.md"
ln -s "../../.agents/skills/\${name}" "\${HOME}/.claude/skills/\${name}"
STUB
    chmod +x "${BIN}/gh" "${BIN}/lefthook" "${BIN}/npx"
}

# run_bootstrap <args...>: run the copied script in the current workspace with stubs first on PATH.
run_bootstrap() {
    HOME="${WS}/home" PATH="${BIN}:${PATH}" bash "${WS}/.github/bootstrap-winmetta-dev.sh" "$@"
}

test_unknown_option_fails() {
    new_workspace
    run_bootstrap --nope >/dev/null 2>&1
    expect_status "unknown option exits 1" 1 $?
}

test_help_prints_usage() {
    new_workspace
    check "--help prints usage" bash -c "bash '${WS}/.github/bootstrap-winmetta-dev.sh' --help | grep -q '^Usage:'"
}

test_not_logged_in_fails() {
    new_workspace
    GH_NO_LOGIN=1 run_bootstrap --skip-tools --skip-platform >/dev/null 2>&1
    expect_status "gh not logged in exits 1" 1 $?
}

test_full_run_links_and_clones() {
    new_workspace
    run_bootstrap --skip-tools --skip-platform >/dev/null 2>&1
    local status=$?
    expect_status "run exits 0" 0 "${status}"
    check "AGENTS.md is linked" test "$(readlink "${WS}/AGENTS.md")" = ".github/AGENTS.md"
    check "CLAUDE.md is linked" test "$(readlink "${WS}/CLAUDE.md")" = "AGENTS.md"
    check ".vscode/extensions.json is linked" test -L "${WS}/.vscode/extensions.json"
    local repo
    for repo in agent-skills bootstrap-dev-env winmetta-platform winmetta-platform-private; do
        check "${repo} is cloned" test -d "${WS}/${repo}/.git"
    done
}

test_user_skills_are_installed_once() {
    new_workspace
    run_bootstrap --skip-tools --skip-platform >/dev/null 2>&1
    local name
    for name in bash-scripting pr-description skill-maintainer; do
        check "user skill ${name} is installed" test -f "${WS}/home/.agents/skills/${name}/SKILL.md"
        check "user skill ${name} is linked for Claude" test -e "${WS}/home/.claude/skills/${name}/SKILL.md"
    done
    check "installs with -g" grep -q -- " -g " "${WS}/npx.log"
    : >"${WS}/npx.log"
    run_bootstrap --skip-tools --skip-platform >/dev/null 2>&1
    check "re-run installs no skill" test ! -s "${WS}/npx.log"
}

test_second_run_changes_nothing() {
    new_workspace
    run_bootstrap --skip-tools --skip-platform >/dev/null 2>&1
    : >"${CLONE_LOG}"
    run_bootstrap --skip-tools --skip-platform >/dev/null 2>&1
    local status=$?
    expect_status "re-run exits 0" 0 "${status}"
    check "re-run clones nothing" test ! -s "${CLONE_LOG}"
}

test_private_clone_failure_is_a_warning() {
    new_workspace
    GH_FAIL="winmetta-platform-private" run_bootstrap --skip-tools --skip-platform >/dev/null 2>&1
    local status=$?
    expect_status "private clone failure still exits 0" 0 "${status}"
}

test_public_clone_failure_is_reported() {
    new_workspace
    local out
    out="$(GH_FAIL="agent-skills" run_bootstrap --skip-tools --skip-platform 2>&1)"
    local status=$?
    expect_status "public clone failure exits 1" 1 "${status}"
    check "failure names the repo" grep -q "clone winmetta/agent-skills" <<<"${out}"
    check "later repos are still cloned" test -d "${WS}/winmetta-platform/.git"
}

test_dry_run_changes_nothing() {
    new_workspace
    run_bootstrap --dry-run --skip-tools --skip-platform >/dev/null 2>&1
    local status=$?
    expect_status "dry run exits 0" 0 "${status}"
    check "dry run creates no links" test ! -e "${WS}/AGENTS.md"
    check "dry run clones nothing" test ! -s "${CLONE_LOG}"
}

test_old_workspace_link_is_removed() {
    new_workspace
    ln -s .github/winmetta.code-workspace "${WS}/winmetta.code-workspace"
    run_bootstrap --skip-tools --skip-platform >/dev/null 2>&1
    check "old workspace link is removed" test ! -e "${WS}/winmetta.code-workspace" -a ! -L "${WS}/winmetta.code-workspace"
    check "workspace file is never linked" test ! -L "${WS}/winmetta.code-workspace"
}

test_real_workspace_file_is_kept() {
    new_workspace
    echo "mine" >"${WS}/winmetta.code-workspace"
    run_bootstrap --skip-tools --skip-platform >/dev/null 2>&1
    check "a real file at the root is kept" test "$(cat "${WS}/winmetta.code-workspace")" = "mine"
}

test_existing_file_is_not_overwritten() {
    new_workspace
    echo "mine" >"${WS}/.editorconfig"
    run_bootstrap --skip-tools --skip-platform >/dev/null 2>&1
    check "existing .editorconfig is kept" test "$(cat "${WS}/.editorconfig")" = "mine"
}

main() {
    test_unknown_option_fails
    test_help_prints_usage
    test_not_logged_in_fails
    test_full_run_links_and_clones
    test_user_skills_are_installed_once
    test_second_run_changes_nothing
    test_private_clone_failure_is_a_warning
    test_public_clone_failure_is_reported
    test_dry_run_changes_nothing
    test_old_workspace_link_is_removed
    test_real_workspace_file_is_kept
    test_existing_file_is_not_overwritten
    if [[ "${FAILURES}" -gt 0 ]]; then
        echo "${FAILURES} failed"
        exit 1
    fi
    echo "all passed"
}

main
