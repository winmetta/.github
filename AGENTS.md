# AGENTS.md: Win Metta Organization Workspace

The **workspace root** (the directory containing this file, usually `~/winmetta/` but it may be anywhere, e.g. `~/Projects/winmetta/`) is **not a git repository**. It is a local workspace that holds clones of repositories from the [`winmetta` GitHub organization](https://github.com/winmetta). Each subdirectory is its own independent git repo with its own history, tooling, and conventions.

The workspace-root `AGENTS.md` is a symlink to `.github/AGENTS.md` in the [winmetta/.github](https://github.com/winmetta/.github) repo, and `CLAUDE.md` is a symlink to `AGENTS.md`. Developer setup instructions are in `.github/README.md`.

**Before working inside a repo, read that repo's own `AGENTS.md` / `CLAUDE.md` / `README.md`.** Repo-level instructions override this file. This file only covers the organization and conventions shared by every repo.

## 1. About Win Metta

Win Metta is a California 501(c)(3) nonprofit that preserves and shares **Theravāda Buddhist teachings**, in the Burmese **Pa-Auk forest tradition**. It serves both Myanmar-based and diaspora learners, in Burmese and English. Details: <https://winmetta.org/about/>.

**Mission (the reason every repo here exists):**

1. **Dhamma teaching & meditation.** Authentic meditation instruction in Burmese and English, plus guided retreats (online and in-person, usually 3–10 days).
2. **Scripture & language study.** Pāḷi scripture and Burmese language classes, so more people can read the classical texts.
3. **Support for monastic communities.** Technology and admin help for monasteries and teachers.

**Current programs:** Dhamma classes and retreats (many run over Zoom), the free **Dhamma Library** (audio, video, books, study materials), Burmese language classes (e.g. _Let's Learn Burmese_), and Pāḷi / Tipiṭaka study classes. Teachers are Sayadaws and Venerable monks based in California, Arizona, Myanmar, and elsewhere.

**Web presence:** `winmetta.org` (main WordPress site, not managed from this workspace), `retreat.winmetta.org` (retreat meditation bell), `winmetta.org/dhamma-library`. Contact: <contact@winmetta.org>.

## 2. Discovering Repositories

This file intentionally does **not** list repositories. Repos get created, archived, cloned, and deleted over time, so any list here would go stale. Discover the current state instead:

- **Local clones:** each subdirectory of the workspace root that contains a `.git/` is a clone of an org repo. Which repos are cloned locally varies by machine and over time. Don't treat it as the full set.
- **All org repos (source of truth):** use the `gh` CLI, e.g.

  ```bash
  gh repo list winmetta --limit 100 --json name,description,visibility,isArchived,primaryLanguage,homepageUrl
  gh repo view winmetta/<repo-name>
  ```

- **Getting a repo that isn't cloned yet:** run `gh repo clone winmetta/<repo-name>` from the workspace root
- **What a repo does:** read its `AGENTS.md` / `README.md` (locally or via `gh repo view`), not this file.

## 3. Conventions for New Repos

- **Location:** clone or create every `winmetta` org repo directly under the workspace root as `<workspace>/<repo-name>/`, using the GitHub repo name as the directory name.
- **Naming:** use the `winmetta-` prefix for anything user-facing. Internal or ops tooling can use a plain descriptive name.
- **Agent docs:** every repo should have its own `AGENTS.md`, with `CLAUDE.md` as a symlink to it (`ln -s AGENTS.md CLAUDE.md`). Cover what the repo is, commands, architecture, and conventions specific to that repo.
- **Visibility:** assume **public** unless the repo handles credentials, member data, or internal operations. Those repos are private. Never commit secrets. Use env vars or local config files listed in `.gitignore`.

## 4. Guiding Principles Across All Win Metta Projects

These come from the mission and apply to every repo unless the repo's own docs say otherwise:

- **Free and open access to the Dhamma.** Teaching content must never sit behind a paywall or a required login.
- **Respect and authenticity.** Treat teachings, teachers, and scripture with care. Use correct names, titles (Sayadaw, Ven., U), and Pāḷi diacritics (e.g. Theravāda, Pāḷi, Tipiṭaka). Don't paraphrase or "improve" doctrinal content. Content comes from the teachers.
- **Calm, distraction-free design.** No vanity metrics (streaks, leaderboards, badges), no engagement-optimized patterns, no ads.
- **Bilingual: Burmese and English.** Burmese text is always **Unicode** (Myanmar block U+1000–U+109F), never Zawgyi. Don't hardcode a single UI language where users are meant to choose.
- **Low cost, low maintenance.** This is a volunteer-run nonprofit. Prefer simple, portable, cheap-to-host solutions over complex infrastructure or vendor lock-in.
- **Serve the monastic community.** Tools should reduce admin work for teachers and organizers, not add to it.

## 5. Working in This Workspace (for AI agents)

- Work inside the specific repo a task is about. Don't create files at the workspace root. It should contain only repo clones plus the symlinks that `.github/link-workspace.sh` creates (`AGENTS.md`, `CLAUDE.md`, `.editorconfig`, `.markdownlint.json`, `winmetta.code-workspace` and `.vscode/extensions.json`).
- To change this file, edit `.github/AGENTS.md` and commit it in the `.github` repo. Don't replace the root symlinks with regular files.
- **File paths in replies:** write every file path relative to the workspace root (the directory containing this file, usually `~/winmetta`), starting with the repo directory name, e.g. `winmetta-platform/apps/web/src/i18n/messages/my.json`, not `apps/web/src/i18n/messages/my.json`. The desktop app resolves clickable links and its file pane from the session's working directory, so a path without the repo name shows "Couldn't find this file". This applies to links, inline code paths and `path:line` references, in every repo.
- **Shared dev environment files live in `.github/`.** The workspace root (`~/winmetta`) is not a repo, so anything meant for the whole workspace and every repo under it (e.g. `winmetta-platform`) is stored in the `.github` repo and symlinked into the root by `.github/link-workspace.sh`: `AGENTS.md` / `CLAUDE.md`, `.editorconfig`, `.markdownlint.json`, `winmetta.code-workspace` and `.vscode/extensions.json`. Machine setup is `.github/bootstrap-dev-env.sh`, documented in `.github/README.md`: tools installed with mise, the git author, the shared git settings and aliases (`.github/git/`), the starship prompt config (`.github/starship/`), the `explain-*` and fzf shell helpers (`.github/shell/`), the vim config and plugins (`.github/vim/`), the `winmetta` iTerm2 profile (`.github/iterm/`), the Nerd Font, iTerm2 and Zed (the apps go in `~/Applications`, no Homebrew or admin rights). The bootstrap does not run `link-workspace.sh`; run that separately. To add or change a shared dev-env file, edit it in `.github/` (and add a `link` line to `link-workspace.sh` if it must appear at the root); never create it directly at the root or copy it into individual repos. A repo's own config overrides these for that repo.
- Each repo has its own git history. Run git commands from inside the repo, and never assume changes span repos.
- If a task touches more than one repo, make and commit the changes in each repo separately.
- If a task needs a repo that isn't cloned, find it with `gh` (see §2) and clone it into the workspace root. Don't assume what the org contains.
- **Commit messages:** use [Conventional Commits](https://www.conventionalcommits.org/) format (`<type>(<optional scope>): <description>`, e.g. `fix(retreat-bell): correct timezone offset`, `docs: clarify setup steps`). Common types: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`. Applies to every repo in this workspace unless a repo's own docs say otherwise.
- **Never run `git commit` (in any repo in this workspace) unless the user has explicitly asked for a commit in the current request.** Staging, diffing, and preparing a commit message are fine; making the commit is not, until asked.
- **Never perform destructive operations without confirming with the user first.** This includes (but isn't limited to) `git push --force`, `git reset --hard`, `git clean`, deleting branches or files, and dropping/overwriting data. Explain what you're about to do and wait for explicit confirmation before proceeding.
- **Always confirm with the user before write operations on cloud resources (Azure, Google Cloud, AWS) or before running commands over SSH.** This covers anything that creates, modifies, or deletes cloud resources (VMs, storage, databases, IAM, DNS, etc.) and any command run on a remote host via SSH. Read-only operations (viewing, listing, describing, `git pull`/`fetch`-equivalent reads) don't require confirmation.
- **Use mise for tools and runtimes; don't use nvm.** [mise](https://mise.jdx.dev/) is the tool and version manager for the whole org. Install and pin Node, other language runtimes and CLI tools with mise (`mise use -g <tool>` for a machine-wide default, `mise use <tool>` to pin a version in a repo's `mise.toml`), not with nvm, and prefer mise over Homebrew whenever the tool is available in mise (check with `mise registry | grep <tool>`). Use Homebrew only for what mise doesn't provide, such as macOS GUI apps and system libraries. Don't add nvm, `.nvmrc`-only setups or `brew install` steps for something mise can install, in scripts or docs. A repo's own docs can override this where they say why.
- **Use the tools the bootstrap installs when they help.** `.github/bootstrap-dev-env.sh` installs them with mise (list every tool with `explain-tools`). They include `rg` (ripgrep), `fd`, `sd`, `bat`, `fzf`, `zoxide`, `gh`, `shellcheck`, `shfmt`, `markdownlint-cli2`, `prettier`, `lefthook`, `gitleaks`, `python3`, `node`, `vim`, `starship`, a modern `bash` (5.x) and `wget`, plus the `claude` and `codex` agents. Prefer `rg` over `grep -r` and `fd` over `find` when searching a repo, and `bat` to read files with highlighting. Rules for using them:
  - Check with `command -v <tool>` first and fall back to `grep`/`find`/`sed` if it is missing. Never assume a bootstrap tool exists on someone else's machine or in CI.
  - **Committed scripts and docs must stay portable.** Don't depend on `rg`, `fd`, `sd`, GNU-only flags (`sed -i` without a suffix, `xargs -r`, `readlink -f`, `date -d`, `grep -P`) or bash 4+ features unless the repo's own docs say it requires them. Scripts that must run on a fresh Mac work with macOS's bash 3.2 (see the header of `.github/bootstrap-dev-env.sh`) and are checked with `shellcheck` and `shfmt`. Markdown in `.github` is checked and formatted the same way: run `markdownlint-cli2 --fix <files>` then `prettier --write <files>` (rules in `.markdownlint.json` and `.prettierrc.json`), or the "Check Markdown" and "Fix and format Markdown" tasks in `winmetta.code-workspace`, and leave no issues before committing.
  - **Git hooks:** `.github/lefthook.yml` runs those checks, a `gitleaks` secret scan and a Conventional Commits check on every commit in `.github` (installed by the bootstrap or `lefthook install`). If a hook fails, fix the cause. Never bypass hooks with `--no-verify` or disable them (`LEFTHOOK=0`) unless the user explicitly asks, and never commit a secret to get past `gitleaks`.
  - Don't use personal git aliases (`git st`, `git ls`, `git fp`, ...) or shell helpers and aliases (`explain-*`, `z`, `ll`, `tree2`) in committed scripts, docs, commit instructions or commands you tell others to run. Write the full command (`git status -sb`, `git push --force-with-lease`). Aliases are fine in your own interactive work only after checking they exist.
  - If a tool you need is missing, say so and point to `.github/bootstrap-dev-env.sh` or `mise use -g <tool>`. Don't `brew install` something mise provides (see the mise rule above).
  - Git editor: the bootstrap sets `core.editor` to Zed (`zed --wait`) or vim. For non-interactive git commands, pass the message with `-m`/`-F` and set `GIT_EDITOR=true` for rebases, so nothing waits on an editor.
- **Never trust model memory for versions.** Before adding or upgrading a dependency, runtime or tool (npm packages, Node, npm, Python and PyPI packages, GitHub Actions, Docker images, CLIs, Terraform/Pulumi providers), look up the **latest stable** version from the source of truth instead of relying on what the model remembers, which is often stale:
  - npm packages: `npm view <package> version` (and `npm view <package> dist-tags`); Node and npm: the official release schedule at <https://nodejs.org/en/about/previous-releases> (prefer the current Active LTS).
  - Python and PyPI packages: `pip index versions <package>` or `https://pypi.org/pypi/<package>/json`; Python itself: <https://devguide.python.org/versions/>.
  - GitHub Actions: `gh api repos/<owner>/<action>/releases/latest --jq .tag_name` (pin to the latest major tag, or a commit SHA for third-party actions).
  - Other software and containers: the project's official releases page or registry.
  - Read the release notes before a major-version upgrade, run the repo's checks after, and say so when a version could not be verified (for example offline). Record the date for any "latest version" claim written into docs, and re-verify it rather than copying an older number from the docs.
- **Pull requests (repos that squash and merge):** the PR title and description become the single commit on the default branch, so write them with care:
  - **Title:** Conventional Commits format (`<type>(<optional scope>): <description>`), imperative and under about 70 characters, describing the whole PR, not its last commit.
  - **Description:** follow the repo's `.github/pull_request_template.md` (Summary, What changed, Testing, Not included / follow-ups, Checklist). Explain what changed and why in plain language for a reader who will only see `git log` on the default branch; do not paste the list of intermediate commits.
  - **Keep it current:** update the title and description (`gh pr edit`) whenever the PR's scope changes, and before merging.
  - **Public repos:** never put secrets, personal data or private links in a title or description.
  - Opening or editing a PR is an outward-facing action: do it only when the user has asked.
