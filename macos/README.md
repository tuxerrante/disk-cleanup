# disk-cleanup (macOS)

Reports, and optionally removes, the disk space that piles up on a developer Mac:
regenerable caches, git worktrees whose PR is finished, and idle dependency
directories. Dry run by default.

## What it removes

| Tier | Flag | Targets |
|---|---|---|
| Caches | `--apply` | Go build/test cache, npm, pnpm (unreferenced packages only), uv, Bun, pip, Homebrew, Cargo registry, Corepack, kubectl, gh, pre-commit, Composer, trivy, gopls, lima, playwright, Chrome and Brave service-worker caches (skipped while the browser runs), the GoogleUpdater cache, unused container images and build cache |
| Expanded | `--apply --expanded` | worktrees with a merged or closed PR, idle `node_modules` / `.venv` / `venv` / `dist`, stale `__pycache__` / `.pytest_cache` / `.ruff_cache` / `.mypy_cache` / `.rumdl_cache`, Go module cache |
| Volumes | `--volumes` | unused container volumes (**data loss**) |

## Safety rules

A worktree is removed only when all of these hold; otherwise it is listed under "kept" with the reason:

- no uncommitted or untracked changes
- no file modified within the keep window (default 7 days, `--keep-days N` or `--since YYYY-MM-DD`)
- its PR (looked up with `gh`) is MERGED or CLOSED. Open, missing or unknown PRs are kept
- its HEAD is on a remote, in the PR's history, or has the PR head's exact tree (covers rebased branches)

Dependency directories are only removed when nothing inside changed within the keep window and either git ignores them or they belong to a project outside any repository that has a `package.json`,
`pyproject.toml`, `requirements.txt` or `Pipfile` to rebuild from (never `dist` in that case). Tool caches are removed only when no file in them is tracked by git. Directories under `.worktrees/` are
left to the worktree rule.

Every deletion goes through one guard: symlinks, relative paths and anything not at least two levels below `$HOME` or the dev root are refused, and each removal is appended to an audit log
(`~/.local/state/disk-cleanup/audit.log`, override with `DISK_CLEANUP_AUDIT_LOG`).

OrbStack and Lima data are only reported, never removed.

PR lookups for worktrees run in batches of 8, which shortens the expanded report on machines with many worktrees.

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
