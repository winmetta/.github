# winmetta/.github

Org-wide defaults, shared AI-agent context, and the **starting point for workspace setup** for every repo in the [Win Metta](https://winmetta.org/about/) GitHub organization.

- [AGENTS.md](AGENTS.md): context for AI coding agents about Win Metta and the local workspace (`CLAUDE.md` is a symlink to it)
- [bootstrap-winmetta-dev.sh](bootstrap-winmetta-dev.sh): sets up everything for developing `winmetta-platform` and the related repos: workspace symlinks, repo clones, shared dev tools, git hooks, the platform's dependencies and its agent skills
- [scripts/bootstrap-winmetta-dev.test.sh](scripts/bootstrap-winmetta-dev.test.sh): tests for that script, run in a throwaway workspace with stub tools
- Machine setup (tools, git, shell, vim, terminal) is not here: it lives in [winmetta/bootstrap-dev-env](https://github.com/winmetta/bootstrap-dev-env)
- [.editorconfig](.editorconfig): shared indentation, line-ending and column settings for Markdown and shell scripts
- [.markdownlint.json](.markdownlint.json): shared markdownlint rules (long lines allowed)
- [.prettierrc.json](.prettierrc.json): Prettier settings for the Markdown in this repo (long lines are not re-wrapped)
- [lefthook.yml](lefthook.yml): git hooks for this repo: pre-commit checks (shellcheck, shfmt, markdownlint, prettier, gitleaks secret scan) and a Conventional Commits check on the commit message
- [.github/workflows/ci.yml](.github/workflows/ci.yml): the CI job `checks` that runs the same checks on every pull request
- [scripts/conventional-commit.sh](scripts/conventional-commit.sh): the Conventional Commits check shared by the git hook and CI
- [rulesets/default.json](rulesets/default.json): the branch ruleset for the default branch, the same as `winmetta-platform`'s
- [.vscode/extensions.json](.vscode/extensions.json): recommended (optional) VS Code extensions, shared by the whole workspace
- [winmetta.code-workspace](winmetta.code-workspace): the VS Code workspace file (settings and tasks for the whole workspace)

## Developer setup

Do these steps once, in order, then follow the README / `CONTRIBUTING.md` of the repo you want to work on.

### 1. Install tools

#### Required

- [Git](https://git-scm.com/downloads)
- [GitHub CLI (`gh`)](https://cli.github.com/)

#### Recommended

- [Visual Studio Code](https://code.visualstudio.com/download)
- [Claude desktop app](https://claude.com/download)
- [ChatGPT desktop app](https://openai.com/chatgpt/download/)

### 2. Run the setup script

All Win Metta repos are cloned side by side under one **workspace root**. The recommended path is `~/winmetta`, but any path works (e.g. `~/Projects/winmetta`). The workspace root itself is not a git repo. It is just the folder that holds this `.github` clone and the other repo clones.

Clone this repo into the workspace root and run the setup script. It does everything below in one go:

```bash
WORKSPACE=~/winmetta   # or ~/Projects/winmetta, etc.
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
gh auth login          # if not already logged in
gh repo clone winmetta/.github
./.github/bootstrap-winmetta-dev.sh
```

It is safe to re-run: finished steps are skipped, and a failing step does not stop the others (every failure is listed at the end, with exit code 1). Steps, in order:

1. Checks that `git` and `gh` are installed and `gh` is logged in.
2. Links the shared workspace files into the workspace root (layout below), so editors and AI agents opened anywhere in the workspace pick up the shared context.
3. Clones `agent-skills`, `bootstrap-dev-env` and `winmetta-platform`, plus the private `winmetta-platform-private` if you have access (it is skipped with a warning if you do not). Existing clones are left alone.
4. Runs [`bootstrap-dev-env/bootstrap.sh`](https://github.com/winmetta/bootstrap-dev-env#readme): mise, the CLI tools, shared git settings, the shell prompt and helpers, editors and the terminal profile (macOS; Linux and Windows are planned). Run it with the `--containers` option by hand if you need Docker.
5. Installs this repo's git hooks (`lefthook install`).
6. Runs `winmetta-platform/scripts/setup-local-dev.sh`: Node, locked dependencies and the Playwright browser.
7. Checks that the `winmetta-platform` agent skills are installed: `add-dhamma-post` (part of that repo) and `bash-scripting` (from [`winmetta/agent-skills`](https://github.com/winmetta/agent-skills)). A missing catalog skill is installed with `npx skills`.
8. Installs the shared skills `bash-scripting`, `pr-description` and `skill-maintainer` for your user (`npx skills ... -g`), so Claude Code and Codex have them in every repo under the workspace and anywhere else. Skills you already have are skipped.

Options: `--skip-tools` (step 4, when the machine is already set up), `--skip-platform` (step 6), `--dry-run` (print what would change and change nothing). If the Command Line Tools installer asks you to finish, do that and rerun the script. Open a new terminal afterwards so mise is active.

```text
<workspace>/
├── .github/                          # this repo
├── .editorconfig -> .github/.editorconfig
├── .markdownlint.json -> .github/.markdownlint.json
├── .vscode/extensions.json -> ../.github/.vscode/extensions.json
├── AGENTS.md -> .github/AGENTS.md
├── CLAUDE.md -> AGENTS.md
├── agent-skills/                     # the shared skill catalog
├── bootstrap-dev-env/                # machine setup
├── winmetta-platform/
├── winmetta-platform-private/        # if you have access
└── <repo-name>/                      # other winmetta repos, cloned as needed
```

#### Open the workspace in VS Code

Open the workspace file from one location only, `.github/`. The setup script never links it into the workspace root, and it removes the link that an earlier version created at `<workspace>/winmetta.code-workspace`:

```bash
code "$WORKSPACE/.github/winmetta.code-workspace"
```

Or, in VS Code, use **File → Open Workspace from File…** and choose `winmetta.code-workspace` inside `.github/`. VS Code resolves symlinks, so a copy or link at the workspace root would still make `.` the `.github` folder; that is why the file lists its folders relative to `.github`, sorted by name: `.` (this repo, shown as `.github`), `../agent-skills`, `../bootstrap-dev-env`, `../winmetta-platform` and `../winmetta-platform-private`. Keep that order when you add a `{ "name": "<repo>", "path": "../<repo>" }` entry for another repo. The tasks run from the workspace root (`options.cwd` is `${workspaceFolder:.github}/..`), so their commands such as `./bootstrap-dev-env/bootstrap.sh` are relative to it. Opening the workspace gives you the shared editor settings, a prompt for the recommended extensions, and **Tasks: Run Task** entries for the setup scripts.

### 3. Clone other repos

The script clones the repos above. For any other org repo, clone from the workspace root, so it lands in `<workspace>/<repo-name>/`:

```bash
cd "$WORKSPACE"
gh repo list winmetta --limit 100          # see what exists
gh repo clone winmetta/<repo-name>         # clone one repo
```

### 4. Agent skills

Skills useful in more than one repo live in [`winmetta/agent-skills`](https://github.com/winmetta/agent-skills). The setup script installs `bash-scripting`, `pr-description` and `skill-maintainer` from it for your user: the files go in `~/.agents/skills/<name>/` (read by Codex) and `~/.claude/skills/<name>` links to them (read by Claude Code). `winmetta-platform` also ships `bash-scripting` next to its own `add-dhamma-post`, so contributors who skip the script still get it from the repo. Start a new agent session after installing. Update the user-level skills with `npx skills update -g`. To add another catalog skill by hand:

```bash
npx skills@latest add winmetta/agent-skills --skill <name> -a claude-code -a codex -g
```

### 5. Set up the repo

Each repo owns its own setup (language runtime, dependencies, browsers), documented in its `README.md` / `CONTRIBUTING.md` / `AGENTS.md`. These override this file. For example, `winmetta-platform` provides `./scripts/setup-local-dev.sh`.

| Repo                | Start here                                                                                                                                                                                                                                                                                                 |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `winmetta-platform` | [CONTRIBUTING.md](https://github.com/winmetta/winmetta-platform/blob/main/CONTRIBUTING.md), [developer guide](https://github.com/winmetta/winmetta-platform/blob/main/docs/developer-guide.md), [implementation plan](https://github.com/winmetta/winmetta-platform/blob/main/docs/implementation-plan.md) |

## Reference

### Checks, CI and branch rules

The same checks run in two places, so a skipped hook cannot get past them:

- **Locally**, as git hooks ([lefthook.yml](lefthook.yml)); install them once in each clone with `lefthook install`.
- **In GitHub Actions** ([.github/workflows/ci.yml](.github/workflows/ci.yml)), as one job called `checks` on every pull request and push to `main`. It installs the same tools with mise at pinned versions, runs `lefthook run pre-commit --all-files` (shellcheck, shfmt, markdownlint, prettier, actionlint and gitleaks), scans the whole git history with gitleaks, and checks that the PR title and every commit subject follow [Conventional Commits](https://www.conventionalcommits.org/) with [scripts/conventional-commit.sh](scripts/conventional-commit.sh). The PR title is checked because a squash merge turns it into the commit subject. To update a pinned tool, look up the latest version (`mise latest <tool>`) and change it in the workflow.

The default branch follows the same rules as `winmetta-platform`, kept in [rulesets/default.json](rulesets/default.json): no deleting it or force-pushing to it, changes only through a pull request that is squash-merged, stale approvals dismissed when new commits are pushed, all review threads resolved, and the `checks` job passing. It has no bypass list, so administrators follow the rules too. The repository settings that go with it are squash merge only, delete the branch after merge, the squash commit taking the PR title and description, and secret scanning with push protection on. A repository admin applies them once:

```bash
gh api -X POST repos/winmetta/.github/rulesets --input rulesets/default.json
gh api -X PATCH repos/winmetta/.github -F allow_merge_commit=false -F allow_rebase_merge=false -F delete_branch_on_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY
gh api -X PATCH repos/winmetta/.github -f 'security_and_analysis[secret_scanning][status]=enabled' -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
```

### Example: `winmetta-platform`

`winmetta-platform` is an [Astro](https://astro.build/) static site with React islands, Tailwind CSS and shadcn/ui, in an npm-workspaces monorepo run with Turborepo. Its own `./scripts/setup-local-dev.sh` installs Node 24 and npm 11 (from `.nvmrc` and `packageManager`), locked dependencies and the Playwright browser. Tooling: ESLint, Prettier, TypeScript, Vitest for unit tests and Playwright for browser smoke tests. No Docker, database or env file is needed for local work. Terraform and Azure tooling arrive with Phase 2 deployment and are not installed yet.

## Editing AGENTS.md

Edit `.github/AGENTS.md` (the workspace-root `AGENTS.md` is just a symlink to it), then commit and push from inside `.github/`. Other developers get the update with `git -C .github pull`.
