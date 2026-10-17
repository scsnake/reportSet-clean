# Git branches

`dev/ch` is the active development branch.
It replaces the broad use of `feat/simpleris-report-recovery`.
`release/0.0.x` holds tested versions.
`main` preserves legacy history while its future role remains undecided.

GitLab still uses `main` as its default branch.
Select `dev/ch` when opening current development work.

## Development workflow

1. Fetch remote updates before starting work:

```powershell
git fetch origin
```

2. Create one feature or fix branch from `dev/ch`.
3. Use a separate worktree when another task has uncommitted changes:

```powershell
git worktree add -b fix/lungcad-navigation ../reportSet-lungcad dev/ch
```

4. Commit related changes together and run the relevant checks.
   Verify the current branch and staged files before each commit.
5. Merge reviewed work into `dev/ch` and push it to `origin/dev/ch`.
6. Advance `release/0.0.x` only after the required runtime checks pass.
7. Preserve a branch's unique work before deleting or archiving it.

Avoid rebasing or force-pushing shared branches.
Change `main` or `release/0.0.x` only when the task explicitly requests it.
Keep generated logs, report exports, credentials, and runtime calibration files outside commits.
See [local configuration](LOCAL_CONFIGURATION.md) for the LungCAD sample.

## Branch audit: 2026-10-07

The audit used development baseline `e9fc785` after fetching `origin`.
Counts below exclude commits already reachable from that baseline.
`git cherry` found no equivalent patches for the listed unique commits.
Later commits may supersede their behavior, so counts alone do not justify merging them.

| Branch | Tip at audit | Unique commits | Disposition |
|---|---|---:|---|
| `main` | `da20c33` | 1 | Preserve the legacy hotstring/counter additions pending comparison. |
| `ai-feature-ych-refactor` | `ea1e76e` | 34 | Preserve the older reporting/refactor work pending a focused review. |
| `ch_minipacs_win11patch` | `e3d3819` | 19 | Preserve the earlier Windows/refactor work pending a focused review. |
| `CH-ris-ipc-review` | `ffdbb57` | 1 | Preserve the IPC prototype; it changes multiple workflow owners. |
| `fix-win11-detection` | `5ea0df5` | 1 | Preserve the hotstring analysis and restructuring tools. |
| `ch_minipacs` | `06e0694` | 0 | Fully included; eligible for archival after checking external references. |

The local release tip `3fb5897` was an ancestor of the development baseline, 49 commits behind it.
It was 53 commits ahead of `origin/release/0.0.x`.
No release pointer, legacy branch, GitLab default, or stash was changed during this cleanup.
