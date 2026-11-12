#!/usr/bin/env bash
# Runs macos/disk-cleanup against a throwaway $HOME with a stub gh and a PATH that holds only
# basic tools, so no real cache, package manager or container runtime is touched.

set -euo pipefail

script=$(cd "$(dirname "$0")/.." && pwd -P)/macos/disk-cleanup
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/disk-cleanup-test.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT
sandbox=$(cd "$sandbox" && pwd -P)

failures=0
check() {
    local description=$1
    shift
    if "$@"; then
        printf 'ok   %s\n' "$description"
    else
        printf 'FAIL %s\n' "$description"
        failures=$((failures + 1))
    fi
}
exists() { [[ -e $1 ]]; }
missing() { [[ ! -e $1 ]]; }
branch_gone() { ! git -C "$1" rev-parse --verify -q "$2" >/dev/null; }

export HOME=$sandbox/home
export DISK_CLEANUP_DEV_ROOT=$HOME/dev
export DISK_CLEANUP_AUDIT_LOG=$sandbox/audit.log
export TMPDIR=$sandbox/tmp
mkdir -p "$HOME/dev" "$TMPDIR" "$sandbox/bin"

for tool in awk basename bash cat cut date df dirname du find git grep head ln mkdir mktemp printf pwd readlink rm sed sort touch tr uname wc; do
    ln -s "$(command -v "$tool")" "$sandbox/bin/$tool"
done
# Reports MERGED for branches named merged-*, OPEN otherwise.
cat >"$sandbox/bin/gh" <<'EOF'
#!/bin/sh
branch=
while [ $# -gt 0 ]; do
    [ "$1" = --head ] && branch=$2
    shift
done
case $branch in
merged-*) echo "MERGED $(git rev-parse HEAD) 1" ;;
*) echo "OPEN $(git rev-parse HEAD) 2" ;;
esac
EOF
chmod +x "$sandbox/bin/gh"
export PATH=$sandbox/bin

old_stamp=202001010000
age() { find "$1" -exec touch -t "$old_stamp" {} +; }

# Repository with a merged worktree, an open-PR worktree and an ignored idle node_modules.
repo=$HOME/dev/project
mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name test
printf 'node_modules/\n__pycache__/\n.worktrees/\n' >"$repo/.gitignore"
printf 'x\n' >"$repo/file"
git -C "$repo" add -A
git -C "$repo" commit -q -m init
git -C "$repo" worktree add -q -b merged-feature "$repo/.worktrees/merged-feature"
git -C "$repo" worktree add -q -b open-feature "$repo/.worktrees/open-feature"
git -C "$repo" worktree add -q -b recent-feature "$repo/.worktrees/recent-feature"
mkdir -p "$repo/node_modules/pkg" "$repo/pkg/__pycache__" "$repo/.worktrees/merged-feature/node_modules"
printf 'x\n' >"$repo/node_modules/pkg/index.js"
printf 'x\n' >"$repo/pkg/__pycache__/a.pyc"
age "$repo/node_modules"
age "$repo/pkg/__pycache__"
age "$repo/.worktrees/merged-feature"
age "$repo/.worktrees/open-feature"

# Project outside any repository: node_modules with a manifest goes, dist and manifest-less ones stay.
loose=$HOME/dev/loose/deck
mkdir -p "$loose/node_modules" "$loose/dist" "$HOME/dev/loose/nomanifest/node_modules"
printf '{}\n' >"$loose/package.json"
printf 'x\n' >"$loose/node_modules/a"
printf 'x\n' >"$loose/dist/a"
printf 'x\n' >"$HOME/dev/loose/nomanifest/node_modules/a"
age "$loose"
age "$HOME/dev/loose/nomanifest"

# Recently touched project: nothing may go.
fresh=$HOME/dev/fresh
mkdir -p "$fresh/node_modules" "$fresh/__pycache__"
printf '{}\n' >"$fresh/package.json"
printf 'x\n' >"$fresh/node_modules/a"
printf 'x\n' >"$fresh/__pycache__/a.pyc"

cache=$HOME/.cache/pre-commit
mkdir -p "$cache"
printf 'x\n' >"$cache/a"

outside=$sandbox/outside
mkdir -p "$outside"
printf 'precious\n' >"$outside/data"
ln -s "$outside" "$HOME/.cache/corepack-link"

# ---- dry run changes nothing ----
"$script" --expanded --keep-days 7 >"$sandbox/dry.out" 2>&1 || true
check 'dry run keeps caches' exists "$cache"
check 'dry run keeps merged worktree' exists "$repo/.worktrees/merged-feature"
check 'dry run lists the merged worktree' grep -q 'merged-feature.*PR MERGED' "$sandbox/dry.out"
check 'dry run lists the open worktree as kept' grep -q 'open-feature.*open PR' "$sandbox/dry.out"
check 'dry run lists the loose node_modules' grep -q 'loose/deck/node_modules' "$sandbox/dry.out"
check 'dry run writes no audit log' missing "$DISK_CLEANUP_AUDIT_LOG"

# ---- apply ----
"$script" --apply --expanded --yes --keep-days 7 >"$sandbox/apply.out" 2>&1 || true
check 'apply removes the cache dir' missing "$cache"
check 'apply removes merged worktree' missing "$repo/.worktrees/merged-feature"
check 'apply keeps open-PR worktree' exists "$repo/.worktrees/open-feature"
check 'apply keeps worktree branch for open PR' git -C "$repo" rev-parse --verify -q --end-of-options open-feature
check 'apply removes the merged branch' branch_gone "$repo" merged-feature
check 'apply removes idle ignored node_modules' missing "$repo/node_modules"
check 'apply removes stale __pycache__' missing "$repo/pkg/__pycache__"
check 'apply removes loose node_modules with manifest' missing "$loose/node_modules"
check 'apply keeps loose dist' exists "$loose/dist"
check 'apply keeps node_modules without manifest' exists "$HOME/dev/loose/nomanifest/node_modules"
check 'apply keeps recent node_modules' exists "$fresh/node_modules"
check 'apply keeps recent __pycache__' exists "$fresh/__pycache__"
check 'audit log names the cache dir' grep -q "removed.*$cache" "$DISK_CLEANUP_AUDIT_LOG"

# ---- safe_remove guards (sourced function, main flow skipped) ----
guard() {
    (
        eval "$(sed -n '/^safe_remove() {/,/^}/p;/^warn() /p' "$script")"
        # shellcheck disable=SC2034 # read by the evaluated safe_remove
        DEV_ROOT=$DISK_CLEANUP_DEV_ROOT
        # shellcheck disable=SC2034
        AUDIT_LOG=$DISK_CLEANUP_AUDIT_LOG
        safe_remove "$@"
    ) >/dev/null 2>&1
}
refused() { ! guard "$@"; }
check 'guard refuses a symlink' refused "$HOME/.cache/corepack-link"
check 'symlink target untouched' exists "$outside/data"
check 'guard refuses a path outside HOME and dev root' refused "$outside"
check 'guard refuses HOME itself' refused "$HOME"
check 'guard refuses a direct child of HOME' refused "$HOME/dev"
check 'guard refuses a relative path' refused "relative/path"
check 'guard refuses an empty path' refused ""

if ((failures)); then
    printf '\n%d check(s) failed. Apply output:\n' "$failures"
    cat "$sandbox/apply.out"
    exit 1
fi
printf '\nall checks passed\n'
