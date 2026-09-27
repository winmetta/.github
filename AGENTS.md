# AGENTS.md: Win Metta Organization Workspace

This directory (`~/winmetta/`) is **not a git repository**. It is a local workspace that holds clones of repositories from the [`winmetta` GitHub organization](https://github.com/winmetta). Each subdirectory is its own independent git repo with its own history, tooling, and conventions.

**Before working inside a repo, read that repo's own `AGENTS.md` / `CLAUDE.md` / `README.md`.** Repo-level instructions override this file. This file only covers the organization and conventions shared by every repo.

## 1. About Win Metta

Win Metta is a California 501(c)(3) nonprofit that preserves and shares **Theravāda Buddhist teachings**, in the Burmese **Pa-Auk forest tradition**. It serves both Myanmar-based and diaspora learners, in Burmese and English. Details: <https://winmetta.org/about/>.

**Mission (the reason every repo here exists):**

1. **Dhamma teaching & meditation.** Authentic meditation instruction in Burmese and English, plus guided retreats (online and in-person, usually 3–10 days).
2. **Scripture & language study.** Pāḷi scripture and Burmese language classes, so more people can read the classical texts.
3. **Support for monastic communities.** Technology and admin help for monasteries and teachers.

**Current programs:** Dhamma classes and retreats (many run over Zoom), the free **Dhamma Library** (audio, video, books, study materials), Burmese language classes (e.g. *Let's Learn Burmese*), and Pāḷi / Tipiṭaka study classes. Teachers are Sayadaws and Venerable monks based in California, Arizona, Myanmar, and elsewhere.

**Web presence:** `winmetta.org` (main WordPress site, not managed from this workspace), `retreat.winmetta.org` (retreat meditation bell), `winmetta.org/dhamma-library`. Contact: contact@winmetta.org.

## 2. Discovering Repositories

This file intentionally does **not** list repositories. Repos get created, archived, cloned, and deleted over time, so any list here would go stale. Discover the current state instead:

- **Local clones:** each subdirectory of `~/winmetta/` that contains a `.git/` is a clone of an org repo. Which repos are cloned locally varies by machine and over time. Don't treat it as the full set.
- **All org repos (source of truth):** use the `gh` CLI, e.g.
  ```bash
  gh repo list winmetta --limit 100 --json name,description,visibility,isArchived,primaryLanguage,homepageUrl
  gh repo view winmetta/<repo-name>
  ```
- **Getting a repo that isn't cloned yet:** `gh repo clone winmetta/<repo-name> ~/winmetta/<repo-name>`
- **What a repo does:** read its `AGENTS.md` / `README.md` (locally or via `gh repo view`), not this file.

## 3. Conventions for New Repos

- **Location:** clone or create every `winmetta` org repo directly under `~/winmetta/<repo-name>/`, using the GitHub repo name as the directory name.
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

- Work inside the specific repo a task is about. Don't create files at the workspace root other than this `AGENTS.md` / `CLAUDE.md`.
- Each repo has its own git history. Run git commands from inside the repo, and never assume changes span repos.
- If a task touches more than one repo, make and commit the changes in each repo separately.
- If a task needs a repo that isn't cloned, find it with `gh` (see §2) and clone it into `~/winmetta/`. Don't assume what the org contains.
