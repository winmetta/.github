# winmetta/.github

Org-wide defaults and shared AI-agent context for the [Win Metta](https://winmetta.org/about/) GitHub organization.

- [AGENTS.md](AGENTS.md): context for AI coding agents about Win Metta and the local workspace (`CLAUDE.md` is a symlink to it)
- [setup.sh](setup.sh): sets up the local workspace

## Developer setup

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
./.github/setup.sh
```

`setup.sh` creates these symlinks in the workspace root, so AI agents opened anywhere in the workspace pick up the shared context:

```
<workspace>/
├── .github/                 # this repo
├── AGENTS.md -> .github/AGENTS.md
├── CLAUDE.md -> AGENTS.md
└── <repo-name>/             # other winmetta repos, cloned as needed
```

The script is safe to run more than once.

### 3. Clone the repos you need

```bash
gh repo list winmetta --limit 100
gh repo clone winmetta/<repo-name>    # run from the workspace root
```

Each repo has its own `README.md` / `AGENTS.md` with repo-specific setup.

## Editing AGENTS.md

Edit `.github/AGENTS.md` (the workspace-root `AGENTS.md` is just a symlink to it), then commit and push from inside `.github/`. Other developers get the update with `git -C .github pull`.
