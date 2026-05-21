# wire-cell-toolkit release workflow

Reference for using `waft/release` and managing master + release branches in
the `wire-cell-toolkit` repo.

## Branch / tag model

- `master` — active development.
- `A.BB.x` — release branches (e.g. `0.36.x`). Created from master when a minor
  series is cut. Stay on the branch for bug-fix tags only.
- `A.BB.C` — tags. `C=0` is the minor cut, `C>0` is a bug-fix release.

## `waft/release` script

Located at `waft/release` in the toolkit. Bash, `set -euo pipefail`.

### Subcommands

| Command | What it does |
|---|---|
| `waft/release guess` | Print next tag based on current branch (master → next minor; A.BB.x → next bugfix). |
| `waft/release fixpast A.BB.x` | Create or fast-forward a release branch to its highest existing tag. |
| `waft/release <tag>` | Full workflow: `check` → `version` → `tarball`. |
| `waft/release <tag> check` | Validate tag, switch to (or create) the matching release branch. |
| `waft/release <tag> version` | Write `version.txt`, commit "Set version to <tag>", create annotated tag. |
| `waft/release <tag> tarball` | `git archive` the tag into `wire-cell-toolkit-<tag>.tar.gz`. |

### Validation rules in `check`

- New minor (`C=0`): `BB` must equal `latest_bb + 1`.
- Bug-fix (`C>0`): `A.BB.0` must already exist; `C` must equal `latest_c + 1`.
- Switches to `A.BB.x`: uses local branch if present, else `origin/A.BB.x`, else
  creates it from current HEAD.

### What the script does NOT do

- Does **not** cherry-pick or merge fixes between branches — bring the fix to
  the release branch yourself before running.
- Does **not** push anything. After it finishes, push the branch and the tag
  manually.

## Recommended workflow for a bug-fix release

Assume the fix is already merged to `master` as commit `<SHA>`, and the release
branch is `A.BB.x`.

```bash
git checkout A.BB.x
git pull --ff-only                      # if it exists on origin
git cherry-pick -x <SHA>                # -x adds "(cherry picked from ...)" trailer
waft/release A.BB.C                     # e.g. 0.36.1
git push origin A.BB.x
git push origin tag A.BB.C              # explicit tag push — safer than --tags
```

## master ↔ release branch — merge vs. cherry-pick

**Use cherry-pick. Do not merge master into a release branch.**

A release branch's whole purpose is to carry only stabilized fixes. `git merge
master` would pull in every unrelated change on master and defeat that.

Two valid patterns:

1. **Fix on master, cherry-pick to release** — what we do here. Simple,
   intuitive. Downside: two commits, two SHAs.
2. **Fix on release, forward-merge release → master** — one commit, cleaner
   history, but you have to know up front the fix is release-worthy and the
   surrounding code on master can't have drifted.

Cherry-pick creates a **new commit with a new SHA** (same diff, same message).
`git cherry`, `git log --cherry-pick`, and merge de-duplication use patch-id to
recognize the pair as "the same fix." Always prefer `cherry-pick -x` so the
release-branch commit message references the master original.

## Pushing tags safely

`git push origin <name>` resolves locally: branch wins if both exist; otherwise
the tag is pushed. If only a tag exists, it pushes the tag. To be explicit and
immune to future branch-name collisions:

```bash
git push origin tag 0.36.1            # or: refs/tags/0.36.1
```

Prefer this over `git push --tags`, which sends every local tag including
strays.

## Quick sanity checks before tagging

```bash
git rev-parse --abbrev-ref HEAD       # should be A.BB.x
git log --oneline -5                  # confirm the cherry-pick is on top
git tag | grep -E '^A\.BB\.' | sort -V # confirm A.BB.0 exists and A.BB.C does not
```
