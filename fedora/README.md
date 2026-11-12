# disk-cleanup (Fedora)

Same script as [`../macos/disk-cleanup`](../macos/disk-cleanup); CI fails if the two differ. It reports
reclaimable space by default and, with flags, removes regenerable caches, worktrees whose PR is finished,
idle dependency directories and stale tool caches. The full list of targets and the safety rules are in
the [macOS README](../macos/README.md). On Linux:

- `--apply` removes the Go, npm, pnpm, uv, Bun and pip caches, Cargo, Corepack, kubectl and pre-commit caches,
  tool caches under `~/.cache` (trivy, gopls, lima, Playwright and similar) and unused Podman images
  (Docker if Podman is absent).
- `--expanded` also removes worktrees with a merged or closed PR (looked up with `gh`), idle `node_modules`,
  `.venv`, `venv` and `dist`, stale `__pycache__` and linter caches, and the Go module cache. With `--apply`
  it requires typing a confirmation phrase unless `--yes` is given.
- `--volumes` also prunes unused container volumes (**data loss**).
- `/var/cache/dnf` and `~/.lima` are only reported. Clean the DNF cache yourself with `sudo dnf clean all`.
- User files in `/tmp` are no longer swept.

Every deletion is checked (no symlinks, nothing outside `$HOME` or the dev root) and appended to
`~/.local/state/disk-cleanup/audit.log`. Scans `$DISK_CLEANUP_DEV_ROOT` (default `~/dev`).
Requires `git`, an authenticated `gh` and GNU `find`; `podman` for container cleanup.

## Use

```sh
install -m 755 disk-cleanup ~/.local/bin/disk-cleanup
disk-cleanup --expanded     # report only
disk-cleanup --apply        # caches only
```

## Weekly (systemd user timer)

The timer runs `--apply` only (caches, no prompt). Run the report once before enabling it.

```sh
mkdir -p ~/.config/systemd/user
cp disk-cleanup.service disk-cleanup.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now disk-cleanup.timer
systemctl --user list-timers disk-cleanup.timer
```

To also remove finished worktrees weekly, change `ExecStart` in the service to
`disk-cleanup --apply --expanded --yes`.
