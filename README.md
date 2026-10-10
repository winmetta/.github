# winmetta/.github

Org-wide defaults, shared AI-agent context, and the **starting point for developer setup** for every repo in the [Win Metta](https://winmetta.org/about/) GitHub organization.

- [AGENTS.md](AGENTS.md): context for AI coding agents about Win Metta and the local workspace (`CLAUDE.md` is a symlink to it)
- [link-workspace.sh](link-workspace.sh): sets up the local workspace (symlinks into the workspace root)
- [bootstrap-dev-env.sh](bootstrap-dev-env.sh): installs the shared developer tools (macOS only for now)
- [.editorconfig](.editorconfig): shared indentation, line-ending and column settings for Markdown and shell scripts
- [.markdownlint.json](.markdownlint.json): shared markdownlint rules (long lines allowed)
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

Or, in VS Code, use **File → Open Workspace from File…** and choose `winmetta.code-workspace` in the workspace root (e.g. `~/winmetta`). The workspace's folder and its tasks are relative to the workspace root. Opening `.github/winmetta.code-workspace` directly makes `.github` the root instead, so you won't see the other repos and the tasks fail. Opening the workspace gives you the shared editor settings, a prompt for the recommended extensions, and **Tasks: Run Task** entries for the setup scripts.

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

Run once per machine, from the workspace root:

```bash
./.github/bootstrap-dev-env.sh
```

`bootstrap-dev-env.sh` is safe to re-run and logs each step. On **macOS** it:

1. checks the platform
2. installs Xcode Command Line Tools (provides `git`, `curl` and the compiler; if it asks you to finish the installer, do that and re-run)
3. installs [mise](https://mise.jdx.dev/), the tool and version manager, and activates it in `~/.zshrc` (the macOS default shell) and `~/.bashrc`. It also makes `~/.bash_profile` load `~/.bashrc`, because Terminal.app starts bash as a login shell
4. installs CLI tools with mise: `gh`, `shellcheck`, `shfmt`, the [starship](https://starship.rs/) prompt (set up in `~/.zshrc` and `~/.bashrc`, with the config from [.github/starship/starship.toml](.github/starship/starship.toml) kept in step with `~/.config/starship.toml`: copied if you have none, and if yours differs the script shows the diff and asks before replacing it, backing yours up first: shows ahead/behind commit counts and a green check when the repo is clean and synced with its upstream, and hides the stash indicator), the AI coding agents `claude` ([Claude Code](https://claude.com/product/claude-code)) and `codex` ([Codex CLI](https://github.com/openai/codex)), and the latest [Node.js LTS](https://nodejs.org/en/about/previous-releases) as the global default (a repo can pin another version, and its own setup script installs that)
5. checks that git has a `user.name` and `user.email` and asks for any that are missing, suggesting your GitHub name and `<id>+<login>@users.noreply.github.com` address (it offers to run `gh auth login` first if `gh` is not signed in). They are saved globally, so commits use your GitHub identity instead of a guess from your OS user and hostname
6. installs shared git settings and aliases from [.github/git/winmetta.gitconfig](.github/git/winmetta.gitconfig): `pull.rebase`, `push.autoSetupRemote`, `fetch.prune`, `rebase.autoStash` and aliases such as `st`, `lg`, `amend`, `undo`, `fp` (`push --force-with-lease`), `sync` and `gone`. The file is copied to `~/.config/git/winmetta.gitconfig` and included at the top of `~/.gitconfig`, so anything you set below the include overrides it, and re-running the script updates it. The script also installs `explain-*` shell helpers from [.github/shell/explain.sh](.github/shell/explain.sh), sourced from `~/.zshrc` and `~/.bashrc`: run `explain` to list them (`explain-git-aliases` (each alias with a description and its command), `explain-git-config`, `explain-aliases`, `explain-command <cmd>`, `explain-path`, `explain-starship`)
7. downloads and installs the [JetBrains Mono Nerd Font](https://github.com/ryanoasis/nerd-fonts) (for starship's icons) into `~/Library/Fonts` (per user, no Homebrew or admin rights needed)
8. installs [iTerm2](https://iterm2.com/) into `~/Applications` if it isn't already installed (no admin rights needed), adds the `winmetta` profile from [.github/iterm/winmetta.json](.github/iterm/winmetta.json) (it uses that font) as an iTerm2 Dynamic Profile and sets it as the default. Quit iTerm2 before running the script, or restart it afterwards, because iTerm2 can overwrite its preferences on quit. Other terminals: set the font to `JetBrainsMono Nerd Font` yourself
9. installs the required VS Code extensions (ESLint, Prettier, Astro, ShellCheck, shfmt, EditorConfig, markdownlint, Playwright, Claude Code), hard-coded in the script. The wider optional set stays in [.vscode/extensions.json](.vscode/extensions.json) as recommendations

The script does **not** install [VS Code](https://code.visualstudio.com/) or [Antigravity CLI](https://antigravity.google/docs/cli/), which have no mise package. Install them by hand, then re-run the script so it can install the VS Code extensions. A fresh machine therefore finishes the first run with a note that the VS Code CLI was not found. That is expected.

The script runs on the bash 3.2 that ships with macOS, so keep it free of bash 4+ features (see the comment at the top of the script).

It does **not** set up any individual repo. **Other operating systems are not supported yet.** Install the tools in the table below by hand.

If a tool fails to install, the script keeps going and lists every failure with a manual fix at the end (exit code 1). Only the platform check, Command Line Tools and mise stop it, because everything else depends on them. Fix the listed items by hand or fix the script, then re-run.

Tools already on your `PATH` are skipped, so existing installs are left alone. After it finishes, sign in once with `gh auth login`, `claude`, `codex` and `agy`.

### 5. Set up the repo

Each repo owns its own setup (language runtime, dependencies, browsers), documented in its `README.md` / `CONTRIBUTING.md` / `AGENTS.md`. These override this file. For example, `winmetta-platform` provides `./scripts/setup-local-dev.sh`.

| Repo | Start here |
| --- | --- |
| `winmetta-platform` | [CONTRIBUTING.md](https://github.com/winmetta/winmetta-platform/blob/main/CONTRIBUTING.md), [developer guide](https://github.com/winmetta/winmetta-platform/blob/main/docs/developer-guide.md), [implementation plan](https://github.com/winmetta/winmetta-platform/blob/main/docs/implementation-plan.md) |

## Reference

### Manual install (if you don't use the script)

| Tool | Why | Install |
| --- | --- | --- |
| Xcode Command Line Tools | `git`, `curl`, compiler | `xcode-select --install` |
| mise | tool and version manager | `curl -fsSL https://mise.run \| sh`, then add `eval "$(~/.local/bin/mise activate zsh)"` to `~/.zshrc` |
| `gh` | clone and manage org repos | `mise use -g gh` |
| Node.js | JavaScript runtime (global default; repos pin their own) | `mise use -g node@lts` |
| `shellcheck`, `shfmt` | lint and format shell scripts (VS Code extensions `timonwong.shellcheck`, `mkhl.shfmt` call them) | `mise use -g shellcheck shfmt` |
| VS Code | editor | download from [code.visualstudio.com](https://code.visualstudio.com/) |
| starship | shell prompt (shows the git branch and status) | `mise use -g starship`, then add `eval "$(starship init zsh)"` to `~/.zshrc` |
| Claude Code | AI coding agent | `mise use -g claude` |
| Codex CLI | AI coding agent | `mise use -g codex` |
| Antigravity CLI | AI coding agent | download from [antigravity.google](https://antigravity.google/docs/cli/) |
| JetBrains Mono Nerd Font | font for starship icons and coding | download `JetBrainsMono.zip` from the [Nerd Fonts releases](https://github.com/ryanoasis/nerd-fonts/releases/latest), unzip, and copy the `.ttf` files into `~/Library/Fonts` |
| iTerm2 and its `winmetta` profile | terminal and a profile that uses the Nerd Font | download iTerm2 from [iterm2.com](https://iterm2.com/downloads.html), then copy `.github/iterm/winmetta.json` to `~/Library/Application Support/iTerm2/DynamicProfiles/`, then set it as default in iTerm2 > Settings > Profiles |
| VS Code extensions | required set | `code --install-extension <id>` for each ID in `VSCODE_EXTENSIONS` in `bootstrap-dev-env.sh` |

### Example: `winmetta-platform`

`winmetta-platform` is an [Astro](https://astro.build/) static site with React islands, Tailwind CSS and shadcn/ui, in an npm-workspaces monorepo run with Turborepo. Its own `./scripts/setup-local-dev.sh` installs Node 24 and npm 11 (from `.nvmrc` and `packageManager`), locked dependencies and the Playwright browser. Tooling: ESLint, Prettier, TypeScript, Vitest for unit tests and Playwright for browser smoke tests. No Docker, database or env file is needed for local work. Terraform and Azure tooling arrive with Phase 2 deployment and are not installed yet.

## Editing AGENTS.md

Edit `.github/AGENTS.md` (the workspace-root `AGENTS.md` is just a symlink to it), then commit and push from inside `.github/`. Other developers get the update with `git -C .github pull`.
