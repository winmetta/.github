# winmetta/.github

Org-wide defaults, shared AI-agent context, and the **starting point for developer setup** for every repo in the [Win Metta](https://winmetta.org/about/) GitHub organization.

- [AGENTS.md](AGENTS.md): context for AI coding agents about Win Metta and the local workspace (`CLAUDE.md` is a symlink to it)
- [link-workspace.sh](link-workspace.sh): sets up the local workspace (symlinks into the workspace root)
- [bootstrap-dev-env.sh](bootstrap-dev-env.sh): installs the shared developer tools (macOS only for now)
- [.editorconfig](.editorconfig): shared indentation, line-ending and column settings for Markdown and shell scripts
- [.markdownlint.json](.markdownlint.json): shared markdownlint rules (long lines allowed)
- [.prettierrc.json](.prettierrc.json): Prettier settings for the Markdown in this repo (long lines are not re-wrapped)
- [lefthook.yml](lefthook.yml): git hooks for this repo: pre-commit checks (shellcheck, shfmt, markdownlint, prettier, JSON validity, gitleaks secret scan) and a Conventional Commits check on the commit message
- [.github/workflows/ci.yml](.github/workflows/ci.yml): the CI job `checks` that runs the same checks on every pull request
- [scripts/conventional-commit.sh](scripts/conventional-commit.sh): the Conventional Commits check shared by the git hook and CI
- [rulesets/default.json](rulesets/default.json): the branch ruleset for the default branch, the same as `winmetta-platform`'s
- [.vscode/extensions.json](.vscode/extensions.json): recommended (optional) VS Code extensions, shared by the whole workspace
- [winmetta.code-workspace](winmetta.code-workspace): the VS Code workspace file (settings and tasks for the whole workspace)
- [git/](git/): shared git settings and aliases, installed by the bootstrap script
- [starship/](starship/): shared starship prompt config
- [shell/](shell/): shell helpers (`explain-*`, shell aliases, fzf options and shell history)
- [vim/](vim/): shared vim config
- [iterm/](iterm/): the `winmetta` iTerm2 profile

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
4. installs CLI tools with mise, as global defaults (a repo can pin another version, and its own setup script installs that): `gh`, `shellcheck`, `shfmt`, the Markdown checker `markdownlint-cli2` and formatter `prettier`, the git hook runner `lefthook` and secret scanner `gitleaks`, the AWS CLI (`aws`), the Pulumi CLI (`pulumi`), `uv` (with `uvx`, which many MCP servers use; `npx` comes with Node), the AI coding agents `claude` ([Claude Code](https://claude.com/product/claude-code)) and `codex` ([Codex CLI](https://github.com/openai/codex)), the [starship](https://starship.rs/) prompt, the latest [Node.js LTS](https://nodejs.org/en/about/previous-releases), the latest stable [Python 3](https://www.python.org/downloads/), [vim](https://www.vim.org/), a modern `bash` (macOS ships 3.2) and `wget`, and the search and navigation tools `rg` ([ripgrep](https://github.com/BurntSushi/ripgrep)), `fd`, `sd`, `bat`, `fzf`, `zoxide`, `tree` and `jq`. A copy of a tool from elsewhere (for example Homebrew) does not count as installed: the script installs the mise one and tells you at the end which other copy to remove. Run `explain-tools` afterwards for what each tool does
5. checks that git has a `user.name` and `user.email` and asks for any that are missing, suggesting your GitHub name and `<id>+<login>@users.noreply.github.com` address (it offers to run `gh auth login` first if `gh` is not signed in). They are saved globally, so commits use your GitHub identity instead of a guess from your OS user and hostname
6. installs shared git settings and aliases from [.github/git/winmetta.gitconfig](git/winmetta.gitconfig): settings (`core.autocrlf = input`, `pull.rebase`, `push.autoSetupRemote`, `fetch.prune`, `rebase.autoStash`, `rerere.enabled`, `merge.conflictStyle = zdiff3`, `diff.algorithm = histogram`, `branch.sort`) and aliases such as `st`, `lg`, `amend`, `undo`, `fp` (`push --force-with-lease`), `sync` and `gone`. The file is copied to `~/.config/git/winmetta.gitconfig` and included at the top of `~/.gitconfig`, so anything you set below the include overrides it, and re-running the script updates it. If `~/.config/git/config` exists, the include goes at the top of that file instead (git reads it before `~/.gitconfig`, so your own settings in either file still win), and no `~/.gitconfig` is created for it. The checks for an existing name, email, editor and global ignore file look at your machine-wide settings, not this clone's `.git/config`. It also makes git ignore `.DS_Store` in every repo: the lines in [git/ignore](git/ignore) are added to your global ignore file (the one `core.excludesFile` points to, else git's default `~/.config/git/ignore`), and lines you already have are left alone.
7. sets up the starship prompt in `~/.zshrc` and `~/.bashrc` and keeps `~/.config/starship.toml` in step with [.github/starship/starship.toml](starship/starship.toml): the config is copied if you have none, and if yours differs the script shows the diff and asks before replacing it, backing yours up first. The shared config shows the full path, ahead/behind commit counts and a green check when the repo is clean and synced with its upstream, hides the stash indicator, uses `$` as the prompt character, and has an optional time segment you can uncomment
8. hooks `zoxide` and `fzf` into `~/.zshrc` and `~/.bashrc`: `z <folder>` jumps to folders you use, and Ctrl-R / Ctrl-T / Alt-C search history, files and folders. Options and a long, shared shell history come from [.github/shell/fzf.sh](shell/fzf.sh), where Ctrl-/ previews a long command in Ctrl-R
9. installs `explain-*` shell helpers from [.github/shell/explain.sh](shell/explain.sh), sourced from `~/.zshrc` and `~/.bashrc`: run `explain` to list them (`explain-tools` explains every tool the script installs with an example for each, `explain-git-aliases` (each alias with a description and its command), `explain-git-config` (each setting with its current value and what it does), `explain-aliases`, `explain-mise` (what mise is and how to check or switch versions), an `explain-<tool>` cheat sheet for each common tool (`explain-rg`, `explain-git`, `explain-jq`, ...), `explain-command <cmd>`, `explain-path`, `explain-starship`)
10. adds shared shell aliases from [shell/aliases.sh](shell/aliases.sh), sourced from `~/.zshrc` and `~/.bashrc`: `ll` (long list), `la` (all files including hidden ones, but not `.` and `..`), `lla` (long list including hidden files), `lt` (long list, newest last), `tree2`, `tree3`, `treea`, `treed` and `treeg` (folder trees, using the `tree` command the script installs), `..` / `...` to go up folders, and on macOS `showdotfiles` / `hidedotfiles` to show or hide dot files in Finder (they restart Finder; Cmd+Shift+. toggles without a restart). Run `explain-aliases` for the full list with descriptions
11. configures vim: copies the shared [.github/vim/.vimrc](vim/.vimrc) to `~/.config/winmetta/.vimrc` and adds a `source` line for it at the top of `~/.vimrc` (so your own settings below it win), and installs the plugins [vim-endwise](https://github.com/tpope/vim-endwise), [vim-repeat](https://github.com/tpope/vim-repeat), [vim-surround](https://github.com/tpope/vim-surround), [vim-unimpaired](https://github.com/tpope/vim-unimpaired), [vim-commentary](https://github.com/tpope/vim-commentary) and [GitHub Copilot](https://github.com/github/copilot.vim) as vim packages in `~/.vim/pack/winmetta/start/` (re-running updates them). Copilot needs a subscription and a one-time `:Copilot setup` sign-in in vim; delete `~/.vim/pack/winmetta/start/copilot.vim` to opt out
12. downloads and installs the [JetBrains Mono Nerd Font](https://github.com/ryanoasis/nerd-fonts) (for starship's icons) into `~/Library/Fonts` (per user, no Homebrew or admin rights needed)
13. installs [iTerm2](https://iterm2.com/) into `~/Applications` if it isn't already installed (no admin rights needed), adds the `winmetta` profile from [.github/iterm/winmetta.json](iterm/winmetta.json) (it uses that font) as an iTerm2 Dynamic Profile and sets it as the default. Quit iTerm2 before running the script, or restart it afterwards, because iTerm2 can overwrite its preferences on quit. Other terminals: set the font to `JetBrainsMono Nerd Font` yourself
14. installs the [Zed](https://zed.dev/) editor into `~/Applications` if it isn't already installed (no admin rights needed) and links its `zed` command into `~/.local/bin`.
15. asks whether git should open Zed (`core.editor = zed --wait`, the default when Zed is installed) or vim for commit messages and saves the choice in `~/.gitconfig`; an editor you already set is kept, and you can switch later with `git config --global core.editor vim`
16. installs the git hooks for this repo with `lefthook install` (config in [lefthook.yml](lefthook.yml)): before each commit it runs `shellcheck`, `shfmt`, `markdownlint-cli2` and `prettier --check` on the staged files, checks `iterm/*.json` is valid JSON and scans the staged changes with `gitleaks`; after you write the message it checks it follows [Conventional Commits](https://www.conventionalcommits.org/) (merge, revert, `fixup!` and `squash!` messages are allowed). Hooks are per clone, so re-run the script (or `lefthook install` in `.github`) in each new clone. Skip them once with `git commit --no-verify`, but fix the problem rather than skipping
17. **only with `--containers`** (`./.github/bootstrap-dev-env.sh --containers`; no repo needs containers yet, so it is off by default): installs containers without Docker Desktop with mise (`docker`, `docker-compose`, `colima`, which runs the Docker engine in a Linux VM as your user, and `lima`) and links mise's `docker-compose` into `~/.docker/cli-plugins`, so both `docker compose` and `docker-compose` work. No Docker engine runs by default: start one with `colima start`, and `docker` talks to it through the `colima` context (see `explain colima`). Run the script again with the flag any time to add them later
18. stops macOS from writing `.DS_Store` files on network shares and USB drives (`defaults write com.apple.desktopservices DSDontWriteNetworkStores` and `DSDontWriteUSBStores`, both `-bool true`; it only writes a value that is not already on). Existing `.DS_Store` files are not removed, and the setting applies after you log out and back in; the global git ignore from step 6 hides them in git on your own disk
19. installs the required VS Code extensions (ESLint, Prettier, Astro, ShellCheck, shfmt, EditorConfig, markdownlint, Playwright, Claude Code), hard-coded in the script. The wider optional set stays in [.vscode/extensions.json](.vscode/extensions.json) as recommendations

The script does **not** install [VS Code](https://code.visualstudio.com/) or [Antigravity CLI](https://antigravity.google/docs/cli/), which have no mise package. Install them by hand, then re-run the script so it can install the VS Code extensions. A fresh machine therefore finishes the first run with a note that the VS Code CLI was not found. That is expected.

The script runs on the bash 3.2 that ships with macOS, so keep it free of bash 4+ features (see the comment at the top of the script).

It does **not** set up any individual repo. **Other operating systems are not supported yet.** Install the tools in the table below by hand.

If a tool fails to install, the script keeps going and lists every failure with a manual fix at the end (exit code 1). Only the platform check, Command Line Tools and mise stop it, because everything else depends on them. Fix the listed items by hand or fix the script, then re-run.

Tools that mise already has are skipped, so re-running is cheap. The script asks a few questions when it has a terminal (your git name and email, whether git should use Zed or vim, and whether to replace a `~/.config/starship.toml` that differs from the shared one). Without a terminal it skips them and prints a note instead. Your own settings are never overwritten without asking. After it finishes, sign in once with `gh auth login`, `claude`, `codex` and `agy`.

### Learn the tools you just installed

The bootstrap adds shell commands that explain what is on your machine. Open a **new terminal** after it finishes, then:

```text
explain                  list every explain-* command with a one-line description
explain <name>           the same as explain-<name>: explain ssh, explain rg, explain git aliases
explain <tool> -x        only the lines about one option: explain rg -w, explain tar -C
explain-tools            each tool the script installs: what it is and an example
explain-mise             what mise is, plus the everyday commands (versions, switching, the registry)
explain-aliases          shell aliases such as ll, la and tree2, with what they run
explain-git-aliases      git aliases such as st, lg and fp, with what they do
explain-git-config       the shared git settings, with their current values
explain-command <cmd>    where a command comes from, and every copy on your PATH
explain-path             your PATH, one folder per line, in lookup order
explain-starship         what each part of the prompt means right now
explain-<tool>            a cheat sheet for one tool with common commands and options
```

Each tool also has a **cheat sheet** with common commands, different options and a comment saying when to use each one. They are one text file per tool in [shell/cheatsheets/](shell/cheatsheets/):

```text
explain-rg   explain-fd   explain-sd   explain-bat   explain-fzf   explain-z   explain-jq
explain-git  explain-gh   explain-vim  explain-tree  explain-python explain-node explain-wget
explain-shellcheck  explain-shfmt  explain-lefthook  explain-gitleaks  explain-markdownlint  explain-prettier
explain-df  explain-du  explain-top  explain-free  explain-ps  explain-kill  explain-lsof
explain-ssh  explain-scp  explain-rsync  explain-ssh-keygen  explain-ssh-copy-id  explain-ssh-add  explain-security (also explain-keychain)
explain-aws  explain-pulumi  explain-npm  explain-npx  explain-uv  explain-uvx
explain-docker  explain-docker-compose (also explain-compose)  explain-colima
explain-curl  explain-gzip  explain-tar  explain-chmod  explain-find  explain-grep  explain-sed  explain-awk  explain-xargs  explain-tail  explain-diff
```

For example, `explain-rg` shows `rg -l TODO` ("only list the names of files that match") next to `rg -C 2 error` ("2 lines of context around each hit"), so you can pick the option you need without reading the manual. The system-command sheets are written for macOS and say where Linux differs (for example `explain-free`, because macOS has no `free` command). `explain-zoxide`, `explain-python3`, `explain-npm`, `explain-ripgrep`, `explain-dh`, `explain-pkill`, `explain-scp` and a few more are alternative names for the same sheets. To add a sheet, drop a `<tool>.txt` file in `shell/cheatsheets/` and re-run the bootstrap: it becomes `explain-<tool>`.

`explain ssh` and `explain-ssh` are the same command, so use whichever you remember. `explain <tool> <option>` prints just the lines about that option (for example `explain rg -w`), and `explain <command>` for a command without a cheat sheet shows where it comes from. Type `explain-` and press Tab to see them all. If one is missing, the new terminal has not loaded `~/.config/winmetta/explain.sh` yet: open another tab, or run `source ~/.zshrc`. The commands live in [shell/explain.sh](shell/explain.sh), so adding a tool or alias to the bootstrap should come with a description there.

### 5. Set up the repo

Each repo owns its own setup (language runtime, dependencies, browsers), documented in its `README.md` / `CONTRIBUTING.md` / `AGENTS.md`. These override this file. For example, `winmetta-platform` provides `./scripts/setup-local-dev.sh`.

| Repo                | Start here                                                                                                                                                                                                                                                                                                 |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `winmetta-platform` | [CONTRIBUTING.md](https://github.com/winmetta/winmetta-platform/blob/main/CONTRIBUTING.md), [developer guide](https://github.com/winmetta/winmetta-platform/blob/main/docs/developer-guide.md), [implementation plan](https://github.com/winmetta/winmetta-platform/blob/main/docs/implementation-plan.md) |

## Reference

### Manual install (if you don't use the script)

| Tool                                         | Why                                                                                                       | Install                                                                                                                                                                                                                                |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Xcode Command Line Tools                     | `git`, `curl`, compiler                                                                                   | `xcode-select --install`                                                                                                                                                                                                               |
| mise                                         | tool and version manager                                                                                  | `curl -fsSL https://mise.run \| sh`, then add `eval "$(~/.local/bin/mise activate zsh)"` to `~/.zshrc`                                                                                                                                 |
| `gh`                                         | clone and manage org repos                                                                                | `mise use -g gh`                                                                                                                                                                                                                       |
| Node.js                                      | JavaScript runtime (global default; repos pin their own)                                                  | `mise use -g node@lts`                                                                                                                                                                                                                 |
| Python 3                                     | Python runtime (global default; repos pin their own)                                                      | `mise use -g python@latest`                                                                                                                                                                                                            |
| vim                                          | terminal editor, newer than the one macOS ships                                                           | `mise use -g vim`                                                                                                                                                                                                                      |
| `bash`, `wget`                               | modern bash 5 (macOS ships 3.2) for testing scripts, and wget                                             | `mise use -g conda:bash conda:wget`                                                                                                                                                                                                    |
| `rg`, `fd`, `sd`, `bat`, `fzf`, `zoxide`     | faster grep, find, sed, cat, fuzzy finder and smarter cd                                                  | `mise use -g ripgrep fd sd bat fzf zoxide`, then add `eval "$(zoxide init zsh)"` and `eval "$(fzf --zsh)"` to `~/.zshrc` (see the fzf options row below)                                                                               |
| `tree`                                       | draw a folder as a tree                                                                                   | `mise use -g conda:tree`                                                                                                                                                                                                               |
| `jq`                                         | read and filter JSON                                                                                      | `mise use -g jq`                                                                                                                                                                                                                       |
| shell aliases                                | `ll`, `la`, `tree2`, ...                                                                                  | copy `shell/aliases.sh` to `~/.config/winmetta/aliases.sh` and add `. ~/.config/winmetta/aliases.sh` to `~/.zshrc`                                                                                                                     |
| vim config and plugins                       | shared vimrc, tpope plugins and Copilot                                                                   | copy `.github/vim/.vimrc` to `~/.config/winmetta/.vimrc`, put `source ~/.config/winmetta/.vimrc` at the top of `~/.vimrc`, and `git clone` each plugin in `VIM_PLUGINS` (in `bootstrap-dev-env.sh`) into `~/.vim/pack/winmetta/start/` |
| `shellcheck`, `shfmt`                        | lint and format shell scripts (VS Code extensions `timonwong.shellcheck`, `mkhl.shfmt` call them)         | `mise use -g shellcheck shfmt`                                                                                                                                                                                                         |
| `markdownlint-cli2`, `prettier`              | check and format Markdown (VS Code extensions `davidanson.vscode-markdownlint`, `esbenp.prettier-vscode`) | `mise use -g npm:markdownlint-cli2 npm:prettier`                                                                                                                                                                                       |
| `lefthook`, `gitleaks`                       | git hooks and secret scanning                                                                             | `mise use -g lefthook gitleaks`, then run `lefthook install` inside `.github`                                                                                                                                                          |
| `aws`                                        | AWS command line                                                                                          | `mise use -g aws-cli`                                                                                                                                                                                                                  |
| `pulumi`                                     | infrastructure as code                                                                                    | `mise use -g pulumi`                                                                                                                                                                                                                   |
| `uv`, `uvx`                                  | Python packages, projects and one-off tools                                                               | `mise use -g uv`                                                                                                                                                                                                                       |
| `docker`, `docker-compose`, `colima`, `lima` | containers without Docker Desktop (optional; the script installs them only with `--containers`)           | `mise use -g docker-cli docker-compose colima lima`, link `docker-compose` into `~/.docker/cli-plugins/`, then `colima start`                                                                                                          |
| VS Code                                      | editor                                                                                                    | download from [code.visualstudio.com](https://code.visualstudio.com/)                                                                                                                                                                  |
| starship                                     | shell prompt (shows the git branch and status)                                                            | `mise use -g starship`, add `eval "$(starship init zsh)"` to `~/.zshrc`, and copy `.github/starship/starship.toml` to `~/.config/starship.toml`                                                                                        |
| Claude Code                                  | AI coding agent                                                                                           | `mise use -g claude`                                                                                                                                                                                                                   |
| Codex CLI                                    | AI coding agent                                                                                           | `mise use -g codex`                                                                                                                                                                                                                    |
| Antigravity CLI                              | AI coding agent                                                                                           | download from [antigravity.google](https://antigravity.google/docs/cli/)                                                                                                                                                               |
| JetBrains Mono Nerd Font                     | font for starship icons and coding                                                                        | download `JetBrainsMono.zip` from the [Nerd Fonts releases](https://github.com/ryanoasis/nerd-fonts/releases/latest), unzip, and copy the `.ttf` files into `~/Library/Fonts`                                                          |
| iTerm2 and its `winmetta` profile            | terminal and a profile that uses the Nerd Font                                                            | download iTerm2 from [iterm2.com](https://iterm2.com/downloads.html), then copy `.github/iterm/winmetta.json` to `~/Library/Application Support/iTerm2/DynamicProfiles/`, then set it as default in iTerm2 > Settings > Profiles       |
| Zed                                          | editor                                                                                                    | download from [zed.dev/download](https://zed.dev/download), move `Zed.app` to `~/Applications`, then `ln -sf ~/Applications/Zed.app/Contents/MacOS/cli ~/.local/bin/zed`                                                               |
| git author                                   | commits use your GitHub identity                                                                          | `git config --global user.name "<name>"`, `git config --global user.email "<id>+<login>@users.noreply.github.com"` (the id is `gh api user --jq .id`)                                                                                  |
| git settings and aliases                     | shared git config with described aliases                                                                  | copy `.github/git/winmetta.gitconfig` to `~/.config/git/winmetta.gitconfig` and add an `[include]` with `path = ~/.config/git/winmetta.gitconfig` at the top of `~/.gitconfig`                                                         |
| global git ignore                            | ignore `.DS_Store` in every repo                                                                          | add `.DS_Store` to `~/.config/git/ignore` (or the file `git config --global core.excludesFile` shows)                                                                                                                                  |
| no `.DS_Store` on network and USB drives     | macOS preference                                                                                          | `defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true`, same for `DSDontWriteUSBStores`, then log out and in                                                                                                   |
| git editor                                   | what git opens for commit messages                                                                        | `git config --global core.editor "zed --wait"` (or `vim`)                                                                                                                                                                              |
| `explain-*` helpers                          | list the tools, aliases and settings                                                                      | copy `.github/shell/explain.sh` to `~/.config/winmetta/explain.sh` and add `. ~/.config/winmetta/explain.sh` to `~/.zshrc`                                                                                                             |
| fzf options and shell history                | Ctrl-R preview and a long shared history                                                                  | copy `.github/shell/fzf.sh` to `~/.config/winmetta/fzf.sh` and add `. ~/.config/winmetta/fzf.sh` to `~/.zshrc`                                                                                                                         |
| VS Code extensions                           | required set                                                                                              | `code --install-extension <id>` for each ID in `VSCODE_EXTENSIONS` in `bootstrap-dev-env.sh`                                                                                                                                           |

### Checks, CI and branch rules

The same checks run in two places, so a skipped hook cannot get past them:

- **Locally**, as git hooks ([lefthook.yml](lefthook.yml)), installed by the bootstrap script.
- **In GitHub Actions** ([.github/workflows/ci.yml](.github/workflows/ci.yml)), as one job called `checks` on every pull request and push to `main`. It installs the same tools with mise at pinned versions, runs `lefthook run pre-commit --all-files` (shellcheck, shfmt, markdownlint, prettier, actionlint, a JSON check and gitleaks), scans the whole git history with gitleaks, and checks that the PR title and every commit subject follow [Conventional Commits](https://www.conventionalcommits.org/) with [scripts/conventional-commit.sh](scripts/conventional-commit.sh). The PR title is checked because a squash merge turns it into the commit subject. To update a pinned tool, look up the latest version (`mise latest <tool>`) and change it in the workflow.

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
