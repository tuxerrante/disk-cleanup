# disk-cleanup (Fedora)

Reports reclaimable space by default.

- `--apply` removes only regenerable caches: unused Podman images, Go build cache, npm cache, and user files in `/tmp` older than 7 days.
- `--expanded` also lists clean `node_modules` directories and Git worktrees whose last commit is older than 7 days, plus the Go module cache. With `--apply` it requires typing a confirmation phrase.
- The DNF cache is only reported; clean it yourself with `sudo dnf clean all`.

Scans `$DISK_CLEANUP_DEV_ROOT` (default `~/dev`). Requires GNU `find`, `git` and, for container cleanup, `podman`.

## Use

```sh
install -m 755 disk-cleanup ~/.local/bin/disk-cleanup
disk-cleanup --expanded     # report only
disk-cleanup --apply        # caches only
```

## Weekly (systemd user timer)

The timer runs `--apply` only (safe caches, no prompt). Run the report once before enabling it.

```sh
mkdir -p ~/.config/systemd/user
cp disk-cleanup.service disk-cleanup.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now disk-cleanup.timer
systemctl --user list-timers disk-cleanup.timer
```

The macOS version in `../macos` is PR-aware (it asks `gh` whether a worktree's PR is merged) and is a separate script.
