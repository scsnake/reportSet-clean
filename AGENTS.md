# ReportSet agent instructions

Read [CLAUDE.md](CLAUDE.md) for project conventions and AHK checks.
Follow [docs/BRANCHES.md](docs/BRANCHES.md) for the branch workflow and legacy branch audit.

## Git workflow

1. Run `git status --short --branch` before editing and before committing.
2. Use `dev/ch` as the integration branch. GitLab's default `main` branch is legacy.
3. Start new features or fixes on `feat/<topic>` or `fix/<topic>`, based on `dev/ch`.
4. Use a separate worktree when the current worktree contains unrelated changes.
5. Stage only files for the current task. Preserve unrelated changes and local runtime files.
6. Target `dev/ch` for merge requests. Push topic branches to their matching upstream branches.
7. Change `main` or `release/0.0.x` only when the task explicitly requests it.
8. Complete the required runtime checks before advancing `release/0.0.x`.
9. Preserve unique work before deleting older branches. Avoid rebasing or force-pushing shared branches.

Keep credentials, report exports, generated logs, and `showLungCAD.ini` outside commits.
Track `showLungCAD.ini.example` as the configuration reference.
