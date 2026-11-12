# disk-cleanup

Two scripts that report, and optionally remove, the disk space a developer machine accumulates. Both are dry-run by default.

| Directory | Platform | Worktree rule |
|---|---|---|
| [`macos/`](macos) | macOS (bash 3.2) | removes worktrees whose PR is merged or closed (via `gh`), skips anything modified recently |
| [`fedora/`](fedora) | Fedora / Linux with systemd | lists clean worktrees whose last commit is older than 7 days |

Read the dry-run output before scheduling either one. Use at your own risk.
