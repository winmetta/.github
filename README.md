# winmetta/.github

Org-wide defaults, shared AI-agent context, and the **starting point for developer setup** for every repo in the [Win Metta](https://winmetta.org/about/) GitHub organization.

- [AGENTS.md](AGENTS.md): context for AI coding agents about Win Metta and the local workspace (`CLAUDE.md` is a symlink to it)
- [link-workspace.sh](link-workspace.sh): sets up the local workspace (symlinks into the workspace root)
- [bootstrap-dev-env.sh](bootstrap-dev-env.sh): installs the shared developer tools (macOS only for now)
- [.editorconfig](.editorconfig): shared indentation, line-ending and column settings for Markdown and shell scripts
- [.vscode/extensions.json](.vscode/extensions.json): recommended (optional) VS Code extensions, shared by the whole workspace

## Developer setup

Do these steps once, in order, then follow the README / `CONTRIBUTING.md` of the repo you want to work on.

### 1. Install tools

**Required**

- [Git](https://git-scm.com/downloads)
- [GitHub CLI (`gh`)](https://cli.github.com/)

**Recommended**

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

```
<workspace>/
├── .github/                          # this repo
├── .editorconfig -> .github/.editorconfig
├── .vscode/extensions.json -> ../.github/.vscode/extensions.json
├── winmetta.code-workspace -> .github/winmetta.code-workspace
├── AGENTS.md -> .github/AGENTS.md
├── CLAUDE.md -> AGENTS.md
└── <repo-name>/                      # other winmetta repos, cloned as needed
```

The script is safe to run more than once. Open `winmetta.code-workspace` in VS Code to accept the recommended extensions.

### 3. Clone the repos you need

```bash
gh repo list winmetta --limit 100
gh repo clone winmetta/<repo-name>    # run from the workspace root
```

### 4. Install the shared dev tools

Run once per machine, from the workspace root:

```bash
./.github/bootstrap-dev-env.sh
```

`bootstrap-dev-env.sh` is safe to re-run and logs each step. On **macOS** it:

1. checks the platform
2. installs Xcode Command Line Tools (if it asks you to finish the installer, do that and re-run)
3. installs [Homebrew](https://brew.sh/)
4. installs CLI tools: `git`, `curl`, `gh`, `shellcheck`, `shfmt`
5. installs apps: [VS Code](https://code.visualstudio.com/), [Claude Code](https://claude.com/product/claude-code) and [Codex CLI](https://github.com/openai/codex)
6. installs the required VS Code extensions (ESLint, Prettier, Astro, ShellCheck, shfmt, EditorConfig, markdownlint, Playwright, Claude Code), hard-coded in the script. The wider optional set stays in [.vscode/extensions.json](.vscode/extensions.json) as recommendations
7. installs [nvm](https://github.com/nvm-sh/nvm)

It does **not** set up any individual repo. **Other operating systems are not supported yet.** Install the tools in the table below by hand.

If a tool fails to install, the script keeps going and lists every failure with a manual fix at the end (exit code 1). Only Command Line Tools and Homebrew stop it, because everything else depends on them. Fix the listed items by hand or fix the script, then re-run.

Tools already on your `PATH` are skipped, so existing installs are left alone. After it finishes, sign in once with `gh auth login`, `claude` and `codex`.

### Manual install (if you don't use the script)

| Tool | Why | Install |
| --- | --- | --- |
| Homebrew | package manager | see [brew.sh](https://brew.sh/) |
| `git`, `curl` | version control, downloads | `brew install git curl` |
| `gh` | clone and manage org repos | `brew install gh` |
| `shellcheck`, `shfmt` | lint and format shell scripts (VS Code extensions `timonwong.shellcheck`, `mkhl.shfmt` call them) | `brew install shellcheck shfmt` |
| nvm | Node version manager used by Node repos | [nvm install script](https://github.com/nvm-sh/nvm#installing-and-updating) |
| VS Code | editor | `brew install --cask visual-studio-code` |
| Claude Code | AI coding agent | `brew install --cask claude-code` |
| Codex CLI | AI coding agent | `brew install --cask codex` |
| VS Code extensions | required set | `code --install-extension <id>` for each ID in `VSCODE_EXTENSIONS` in `bootstrap-dev-env.sh` |

### Example: `winmetta-platform`

`winmetta-platform` is an [Astro](https://astro.build/) static site with React islands, Tailwind CSS and shadcn/ui, in an npm-workspaces monorepo run with Turborepo. Its own `./scripts/setup-local-dev.sh` installs Node 24 and npm 11 (from `.nvmrc` and `packageManager`), locked dependencies and the Playwright browser. Tooling: ESLint, Prettier, TypeScript, Vitest for unit tests and Playwright for browser smoke tests. No Docker, database or env file is needed for local work. Terraform and Azure tooling arrive with Phase 2 deployment and are not installed yet.

### 5. Set up the repo

Each repo owns its own setup (language runtime, dependencies, browsers), documented in its `README.md` / `CONTRIBUTING.md` / `AGENTS.md`. These override this file. For example, `winmetta-platform` provides `./scripts/setup-local-dev.sh`.

| Repo | Start here |
| --- | --- |
| `winmetta-platform` | [CONTRIBUTING.md](https://github.com/winmetta/winmetta-platform/blob/main/CONTRIBUTING.md), [developer guide](https://github.com/winmetta/winmetta-platform/blob/main/docs/developer-guide.md), [implementation plan](https://github.com/winmetta/winmetta-platform/blob/main/docs/implementation-plan.md) |

## Editing AGENTS.md

Edit `.github/AGENTS.md` (the workspace-root `AGENTS.md` is just a symlink to it), then commit and push from inside `.github/`. Other developers get the update with `git -C .github pull`.
