# Security Policy

## Supported versions

There are no releases. Only the latest commit on `main` is maintained.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Use a
[private GitHub security advisory](https://github.com/tuxerrante/disk-cleanup/security/advisories/new).

## Scope

The scripts delete files under the invoking user's account. Report anything
that makes them remove data they should have kept, for example a worktree
with unpushed work or a directory outside the documented cache list.
