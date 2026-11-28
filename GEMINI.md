# GEMINI.md: Gemini-Specific Workspace Instructions

This file supplements `AGENTS.md` with mandatory skill triggers for Gemini / Antigravity across the Win Metta workspace. Do not skip reading a skill's `SKILL.md` when any trigger below applies.

## Mandatory Skill Triggers

- **After making changes:** Automatically load and run the `local-change-review` skill to review your changes before committing.
- **When creating or updating a PR:** Always load and follow the `pr-description` skill to write the PR title and description.
- **After a PR is open and a new commit is pushed:** Automatically load and run the `local-pr-review` skill (including on the initial push that opens the PR).
- **When the user says "commit and auto merge PR":** Execute the full sequence automatically:
  1. Run the `local-change-review` skill on the changes and fix any findings.
  2. Commit the changes using Conventional Commits format.
  3. Push the branch and open the PR using the `pr-description` skill.
  4. Run the `local-pr-review` skill on the PR, fix any findings until approved, and proceed with the merge once CI and review requirements in `AGENTS.md` are met.

## Command Execution & Approval Policy

- In **Auto** permission preset mode, do not ask the user for approval on operations within the project/workspace folder (prefer sandboxed execution and standard workspace tools), unless an explicit rule elsewhere requires confirmation (such as destructive operations, cloud/production writes, or repository settings changes).
- If a sandboxed command fails with a sandbox configuration or path permission error (forcing `BypassSandbox: true` and triggering an Antigravity IDE approval prompt), report the exact sandbox error and the affected path or setting to the user so they can fix it.
- Keep `gh` and `local-pr-review` commands (`gh pr ...`, `node ~/.gemini/config/skills/local-pr-review/scripts/...`) as standalone commands rather than chaining them with `&&`, `cd ... && ...`, or `cat <<'EOF'` (use `write_file` for temp files, `--repo` for `gh`, and `git -C` for `git`) so `command(...)` allow rules match cleanly.
