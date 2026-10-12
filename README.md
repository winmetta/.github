# winmetta/.github

Org-wide defaults, shared AI-agent context, and the **starting point for workspace setup** for every repo in the [Win Metta](https://winmetta.org/about/) GitHub organization.

- [AGENTS.md](AGENTS.md): context for AI coding agents about Win Metta and the local workspace (`CLAUDE.md` is a symlink to it)
- [link-workspace.sh](link-workspace.sh): sets up the local workspace (symlinks into the workspace root)
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

### 2. Set up the workspace

All Win Metta repos are cloned side by side under one **workspace root**. The recommended path is `~/winmetta`, but any path works (e.g. `~/Projects/winmetta`). The workspace root itself is not a git repo. It is just the folder that holds this `.github` clone and the other repo clones.

```bash
WORKSPACE=~/winmetta   # or ~/Projects/winmetta, etc.
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
gh auth login          # if not already logged in
gh repo clone winmetta/.github
./.github/link-workspace.sh
```

`link-workspace.sh` creates these symlinks in the workspace root, so editors and AI agents opened anywhere in the workspace pick up the shared context:

```text
<workspace>/
├── .github/                          # this repo
├── .editorconfig -> .github/.editorconfig
├── .markdownlint.json -> .github/.markdownlint.json
├── .vscode/extensions.json -> ../.github/.vscode/extensions.json
├── winmetta.code-workspace -> .github/winmetta.code-workspace
├── AGENTS.md -> .github/AGENTS.md
├── CLAUDE.md -> AGENTS.md
└── <repo-name>/                      # other winmetta repos, cloned as needed
```

The script is safe to run more than once.

#### Open the workspace in VS Code

Always open the workspace through the link in the **workspace root**, not the copy inside `.github/`:

```bash
code "$WORKSPACE/winmetta.code-workspace"
```

Or, in VS Code, use **File → Open Workspace from File…** and choose `winmetta.code-workspace` in the workspace root (e.g. `~/winmetta`). The workspace's folder and its tasks are relative to the workspace root. Opening `.github/winmetta.code-workspace` directly makes `.github` the root instead, so you won't see the other repos and the tasks fail. The workspace lists `.` (the workspace root, which the tasks use) first, then `winmetta-platform` and `bootstrap-dev-env` as folders of their own, with paths relative to the workspace root; add a folder for each repo you want as a separate root. Opening the workspace gives you the shared editor settings, a prompt for the recommended extensions, and **Tasks: Run Task** entries for the setup scripts.

### 3. Clone the repos you need

Always clone from the workspace root, so each repo lands in `<workspace>/<repo-name>/`:

```bash
cd "$WORKSPACE"
gh repo list winmetta --limit 100          # see what exists
gh repo clone winmetta/<repo-name>         # clone one repo
```

To clone every active org repo you can access that is not already cloned:

```bash
cd "$WORKSPACE"
gh repo list winmetta --limit 100 --no-archived --json name -q '.[].name' |
  while read -r repo; do
    [ -d "$repo" ] || gh repo clone "winmetta/$repo"
  done
```

This includes sample and experimental repos such as `demo-repository`. Skip any you don't need.

### 4. Install the shared dev tools

Run once per machine. The setup lives in its own repo, [winmetta/bootstrap-dev-env](https://github.com/winmetta/bootstrap-dev-env), which is not specific to Win Metta. Clone it into the workspace root like any other repo and run it:

```bash
cd "$WORKSPACE"
gh repo clone winmetta/bootstrap-dev-env
./bootstrap-dev-env/bootstrap.sh
```

It is safe to re-run. On **macOS** it installs mise and the CLI tools, shared git settings, the starship prompt, shell helpers, vim, iTerm2, Zed and the Nerd Font. Linux and Windows are planned. See its [README](https://github.com/winmetta/bootstrap-dev-env#readme) for what it installs, every path it writes, and the `explain-*` commands that describe the tools afterwards. Then install this repo's git hooks once:

```bash
cd "$WORKSPACE/.github" && lefthook install
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
