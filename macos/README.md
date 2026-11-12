# disk-cleanup (macOS)

Reports, and optionally removes, the disk space that piles up on a developer Mac:
regenerable caches, git worktrees whose PR is finished, and idle dependency
directories. Dry run by default.

## What it removes

| Tier | Flag | Targets |
|---|---|---|
| Caches | `--apply` | Go build/test cache, npm, uv, Bun, pip, Homebrew, trivy, gopls, lima, playwright and similar, unused container images and build cache |
| Expanded | `--apply --expanded` | worktrees with a merged or closed PR, idle git-ignored `node_modules` / `.venv` / `venv` / `dist`, Go module cache |
| Volumes | `--volumes` | unused container volumes (**data loss**) |

## Safety rules

A worktree is removed only when all of these hold; otherwise it is listed under "kept" with the reason:

- no uncommitted or untracked changes
- no file modified within the keep window (default 7 days, `--keep-days N` or `--since YYYY-MM-DD`)
- its PR (looked up with `gh`) is MERGED or CLOSED. Open, missing or unknown PRs are kept
- its HEAD is on a remote, in the PR's history, or has the PR head's exact tree (covers rebased branches)

Dependency directories are only removed when git ignores them and nothing inside changed within the keep window. Directories under `.worktrees/` are left to the worktree rule.

Requires `git`, `gh` (authenticated) and `find` with `-newermt`. Written for macOS (bash 3.2) and Linux. Scans `$DISK_CLEANUP_DEV_ROOT` (default `~/dev`).

## Use

```sh
install -m 755 disk-cleanup ~/.local/bin/disk-cleanup
disk-cleanup --expanded                 # report only
disk-cleanup --apply                    # caches only
disk-cleanup --apply --expanded         # asks for typed confirmation
```

Extra directories to delete: `DISK_CLEANUP_EXTRA_DIRS="$HOME/Library/Caches/com.spotify.client:..."`.

## Weekly on macOS

Read the dry-run output once before scheduling the job.

```sh
cp com.example.disk-cleanup.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.disk-cleanup.plist
# remove: launchctl bootout gui/$(id -u)/com.example.disk-cleanup
```

Output goes to `~/Library/Logs/disk-cleanup.log`.
